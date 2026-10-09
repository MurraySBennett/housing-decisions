function out = gazeCodec(action, value, varargin)
%UTILS.GAZECODEC Lossless column storage for repeated numeric SDK structures.
% Leaves retain MATLAB class, shape, field order, NaNs and raw integer clocks.
%
% Actions:
%   'pack'        -- struct/GazeData array  -> packed columns
%   'verify'      -- gazeCodec('verify', packed, source) -> logical. Fidelity
%                    check for the save path. No SDK reconstruction.
%   'unpackplain' -- packed -> plain structs, field names as the source SDK
%                    spelt them. Readable with no SDK installed.
%   'unpack'      -- packed -> original type, reconstructing GazeData objects.
%                    Needs the SDK AND a constructor signature this file
%                    hardcodes; keep it off any session-critical path.
%   'plain'       -- struct/GazeData array -> plain structs. Costs a property
%                    walk per sample; do not use per block.
%   'validate'    -- packed -> logical, schema and column shape only.
switch lower(action)
    case 'pack'
        out = struct('schemaVersion', 1, 'sampleCount', numel(value), ...
            'originalShape', size(value), 'sourceClass', class(value), 'emptyValue', [], ...
            'prototype', [], 'leafSchema', [], 'columns', {{}});
        if isempty(value), out.emptyValue = value; return; end
        assert(isstruct(value) || isa(value, 'GazeData'), 'hw:gazeCodec:type', ...
            'Expected SDK GazeData or sample structs; unsupported data was not discarded.');
        % Schema from sample 1 only. This used to run a full recursive
        % describe() on EVERY sample purely to compare schemas -- order 10^5
        % interpreted property walks per block -- while the leaf loop below
        % already asserts class and shape per sample per leaf, and getLeaf
        % throws outright on a field that is missing. Samples in one block
        % come from one SDK class, so the field set cannot vary between them.
        [prototype, leaves] = describe(value(1), {});
        out.prototype = prototype;
        out.leafSchema = leaves;
        out.columns = cell(1, numel(leaves));
        for k = 1:numel(leaves)
            leaf = leaves(k);
            if strcmp(leaf.class, 'char')
                columns = repmat(char(0), numel(value), prod(leaf.shape));
            elseif strcmp(leaf.class, 'logical')
                columns = false(numel(value), prod(leaf.shape));
            else
                columns = zeros(numel(value), prod(leaf.shape), leaf.class);
            end
            for i = 1:numel(value)
                v = getLeaf(value(i), leaf.path);
                assert(strcmp(class(v), leaf.class) && isequal(size(v), leaf.shape), ...
                    'hw:gazeCodec:shape', 'Gaze leaf class/shape changed at sample %d.', i);
                columns(i,:) = reshape(v, 1, []);
            end
            out.columns{k} = columns;
        end
    case 'verify'
        % Fidelity check for the save path: every leaf of every sample, read
        % back out of the ORIGINAL and compared to the stored column.
        %
        % Three things this deliberately does not do. It does not reconstruct
        % SDK objects, so it cannot depend on how a given Tobii build spells a
        % nested field -- the 2026-10-09 all-blocks crash was exactly that
        % dependency. It does not call describe() per sample, which would
        % reintroduce the order-10^5 property walks 'pack' above removed.
        % And it reads field paths from the pack's own leafSchema, so there is
        % no hardcoded name here to drift.
        source = varargin{1};
        out = false;
        if value.sampleCount ~= numel(source), return; end
        if value.sampleCount == 0, out = isequaln(value.emptyValue, source); return; end
        if ~isequal(value.originalShape, size(source)), return; end
        % One describe, on sample 1 only, to catch pack having silently dropped
        % a field entirely -- the leaf loop below can only check leaves it knows.
        [~, srcLeaves] = describe(source(1), {});
        if numel(srcLeaves) ~= numel(value.leafSchema), return; end
        for k = 1:numel(value.leafSchema)
            leaf = value.leafSchema(k); col = value.columns{k};
            for i = 1:value.sampleCount
                if ~isequaln(getLeaf(source(i), leaf.path), reshape(col(i,:), leaf.shape))
                    return;
                end
            end
        end
        out = true;
    case 'plain'
        % Canonical plain form, built straight from the source. Costs a
        % property walk per sample, so it is a tool for analysis and tests,
        % never for a block commit -- use 'verify' there.
        out = toPlain(value);
    case {'unpack', 'unpackplain', 'validate'}
        assert(value.schemaVersion == 1, 'hw:gazeCodec:version', 'Unknown gaze schema.');
        if value.sampleCount == 0
            if strcmpi(action, 'validate'), out = true; else, out = value.emptyValue; end
            return;
        end
        assert(prod(value.originalShape) == value.sampleCount, ...
            'hw:gazeCodec:column', 'Sample count and shape disagree.');
        % Both unpacking actions need the preallocation; only 'validate' skips
        % it, because it never materialises samples.
        if ~strcmpi(action, 'validate'), out = repmat(value.prototype, value.originalShape); end
        assert(numel(value.columns) == numel(value.leafSchema), ...
            'hw:gazeCodec:column', 'Column/schema count mismatch.');
        for k = 1:numel(value.leafSchema)
            leaf = value.leafSchema(k); col = value.columns{k};
            assert(strcmp(class(col), leaf.class) && ...
                isequal(size(col), [value.sampleCount prod(leaf.shape)]), ...
                'hw:gazeCodec:column', 'Gaze column class or dimensions changed.');
            if strcmpi(action, 'validate'), continue; end
            for i = 1:value.sampleCount
                out(i) = putLeaf(out(i), leaf.path, reshape(col(i,:), leaf.shape));
            end
        end
        if strcmpi(action, 'validate'), out = true; return; end
        % Stop before SDK reconstruction. This is what blockStore's fidelity
        % check uses: the stored artifact is the packed columns, so the thing
        % that must be proved lossless is the plain representation, and proving
        % it must not depend on how this SDK build spells its nested fields.
        if strcmpi(action, 'unpackplain'), return; end
        if strcmp(value.sourceClass, 'GazeData')
            plain = out;
            % Preallocate from a real reconstruction. GazeData's constructor
            % takes all 18 properties and the SDK does not offer a zero-argument
            % form, so repmat(GazeData(), ...) threw here. Every element is
            % overwritten below -- prod(originalShape) == sampleCount is
            % asserted above -- so the seed element is never read.
            out = repmat(makeGazeData(plain(1)), value.originalShape);
            for i = 1:value.sampleCount
                out(i) = makeGazeData(plain(i));
            end
            % Verify the reconstruction on sample 1 only, as a fast local
            % failure for a constructor that cannot round-trip its own
            % properties. Note this is NOT the save path's guarantee any more:
            % blockStore commits with 'verify', which never comes through here.
            [check, ~] = describe(out(1), {});
            assert(isequaln(check, plain(1)), 'hw:gazeCodec:type', ...
                'SDK reconstruction changed properties; retain the original data.');
        end
    otherwise
        error('hw:gazeCodec:action', 'Unknown codec action %s.', action);
end
end

function [prototype, leaves] = describe(v, path)
leaves = struct('path', {}, 'class', {}, 'shape', {});
if (isstruct(v) || isobject(v)) && isscalar(v)
    prototype = struct();
    if isobject(v), names = properties(v); else, names = fieldnames(v); end
    for i = 1:numel(names)
        name = names{i};
        [prototype.(name), child] = describe(v.(name), [path {name}]);
        leaves = [leaves child]; %#ok<AGROW>
    end
else
    assert((isnumeric(v) || islogical(v) || ischar(v)) && ~issparse(v), ...
        'hw:gazeCodec:type', 'Unsupported SDK leaf type %s; raw data must be retained.', class(v));
    prototype = v;
    leaves = struct('path', {path}, 'class', class(v), 'shape', {size(v)});
end
end
function v = getLeaf(s, path)
v = s;
for j = 1:numel(path), v = v.(path{j}); end
end
function s = putLeaf(s, path, v)
if isempty(path), s = v; return; end
name = path{1};
s.(name) = putLeaf(s.(name), path(2:end), v);
end

function p = toPlain(value)
%TOPLAIN Plain-struct copy of an SDK object array, field names exactly as this
% SDK build spells them. describe() already does the work; this only maps it
% over every sample and keeps the original shape.
if isempty(value), p = value; return; end
p = repmat(describe(value(1), {}), size(value));
for i = 1:numel(value)
    p(i) = describe(value(i), {});
end
end

function g = makeGazeData(v)
args = [eyeArgs(v.LeftEye) eyeArgs(v.RightEye)];
g = GazeData(pick(v, {'DeviceTimeStamp', 'device_time_stamp'}), ...
    pick(v, {'SystemTimeStamp', 'system_time_stamp'}), args{:});
end

function args = eyeArgs(e)
% Spelling-tolerant for the same reason positionGuide.m:262 and
% diagnoseTrackBox.m:127 are: the lab's rigs carry different Tobii SDK builds
% and they do not agree on these names. A hardcoded list here is what crashed
% every block commit on 2026-10-09 -- it read
% GazeOrigin.InTrackBoxCoordinateSystem, which that rig's build does not have.
%
% NOTE: nothing in the save path calls this any more. blockStore verifies with
% 'unpackplain' against 'plain', so a spelling this list still does not know
% can no longer kill a session -- it can only fail an explicit reconstruction.
gp = pick(e, {'GazePoint', 'gaze_point'});
pu = pick(e, {'Pupil', 'pupil'});
go = pick(e, {'GazeOrigin', 'gaze_origin'});
args = {pick(gp, {'OnDisplayArea', 'on_display_area'}), ...
    pick(gp, {'InUserCoordinateSystem', 'in_user_coordinate_system'}), ...
    validityValue(pick(gp, {'Validity', 'validity'})), ...
    pick(pu, {'Diameter', 'diameter'}), ...
    validityValue(pick(pu, {'Validity', 'validity'})), ...
    pick(go, {'InUserCoordinateSystem', 'in_user_coordinate_system'}), ...
    pick(go, {'InTrackBoxCoordinateSystem', 'in_track_box_coordinate_system', ...
              'position_in_track_box_coordinate_system'}), ...
    validityValue(pick(go, {'Validity', 'validity'}))};
end

function v = pick(s, names)
for i = 1:numel(names)
    if isfield(s, names{i}), v = s.(names{i}); return; end
end
% Name what WAS there. The original failure said only 'Unrecognized field
% name', which cost a session to interpret.
error('hw:gazeCodec:sdkField', ...
    'No SDK field matched %s. Fields present: %s.', ...
    strjoin(names, ' / '), strjoin(fieldnames(s)', ', '));
end

function v = validityValue(x)
% Real builds wrap validity in an object with a .value; the fake uses a plain
% numeric. d1cd402 fixed the same split in gazeToPixels.
if isstruct(x) && isfield(x, 'value'), v = x.value; else, v = x; end
end
