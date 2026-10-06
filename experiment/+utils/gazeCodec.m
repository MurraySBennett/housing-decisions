function out = gazeCodec(action, value)
%UTILS.GAZECODEC Lossless column storage for repeated numeric SDK structures.
% Leaves retain MATLAB class, shape, field order, NaNs and raw integer clocks.
switch lower(action)
    case 'pack'
        out = struct('schemaVersion', 1, 'sampleCount', numel(value), ...
            'originalShape', size(value), 'sourceClass', class(value), 'emptyValue', [], ...
            'prototype', [], 'leafSchema', [], 'columns', {{}});
        if isempty(value), out.emptyValue = value; return; end
        assert(isstruct(value) || isa(value, 'GazeData'), 'hw:gazeCodec:type', ...
            'Expected SDK GazeData or sample structs; unsupported data was not discarded.');
        [prototype, leaves] = describe(value(1), {});
        for i = 2:numel(value)
            [~, sampleLeaves] = describe(value(i), {});
            assert(isequaln(sampleLeaves, leaves), 'hw:gazeCodec:shape', ...
                'SDK fields/classes/shapes changed at sample %d.', i);
        end
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
    case {'unpack', 'validate'}
        assert(value.schemaVersion == 1, 'hw:gazeCodec:version', 'Unknown gaze schema.');
        if value.sampleCount == 0
            if strcmpi(action, 'validate'), out = true; else, out = value.emptyValue; end
            return;
        end
        assert(prod(value.originalShape) == value.sampleCount, ...
            'hw:gazeCodec:column', 'Sample count and shape disagree.');
        if strcmpi(action, 'unpack'), out = repmat(value.prototype, value.originalShape); end
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
        if strcmp(value.sourceClass, 'GazeData')
            plain = out;
            % Preallocate from a real reconstruction. GazeData's constructor
            % takes all 18 properties and the SDK does not offer a zero-argument
            % form, so repmat(GazeData(), ...) threw here. Every element is
            % overwritten below -- prod(originalShape) == sampleCount is
            % asserted above -- so the seed element is never read.
            out = repmat(makeGazeData(plain(1)), value.originalShape);
            for i = 1:value.sampleCount
                v = plain(i);
                out(i) = makeGazeData(v);
                [check, ~] = describe(out(i), {});
                assert(isequaln(check, v), 'hw:gazeCodec:type', ...
                    'SDK reconstruction changed properties; retain the original data.');
            end
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

function g = makeGazeData(v)
args = [eyeArgs(v.LeftEye) eyeArgs(v.RightEye)];
g = GazeData(v.DeviceTimeStamp, v.SystemTimeStamp, args{:});
end

function args = eyeArgs(e)
args = {e.GazePoint.OnDisplayArea, e.GazePoint.InUserCoordinateSystem, ...
    e.GazePoint.Validity.value, e.Pupil.Diameter, e.Pupil.Validity.value, ...
    e.GazeOrigin.InUserCoordinateSystem, e.GazeOrigin.InTrackBoxCoordinateSystem, ...
    e.GazeOrigin.Validity.value};
end
