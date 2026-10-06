function probe_sdk_types()
%PROBE_SDK_TYPES Print the SDK facts utils.gazeCodec's object path depends on.
%
%   Run on the rig with HW_TOBII_ROOT set. Needs no tracker, no display, no
%   participant and no Psychtoolbox. Prints a report; writes nothing.
%
%   utils.gazeCodec reconstructs GazeData objects, and utils.blockStore asserts
%   that reconstruction is exact on EVERY block commit. Three facts decide
%   whether that assert can pass, and none of them is checkable away from the
%   SDK:
%     1. whether GazeData can be constructed with no arguments,
%     2. whether GazeData is a value class or a handle class,
%     3. what type Validity is, and whether it exposes `.value`.
%   Three files in this repo already disagree about (3), so at most one of them
%   is right. Paste this output back before running a participant.

fprintf('\n==================== SDK type probe ====================\n');

sdk = getenv('HW_TOBII_ROOT');
if isempty(sdk)
    fprintf('HW_TOBII_ROOT is NOT set. Set it and re-run:\n');
    fprintf('  setenv(''HW_TOBII_ROOT'',''\\\\asc-files.asc.ohio-state.edu\\projects\\PSY-kvam.4\\TobiiPro.SDK.Matlab_1.9.0.59'')\n');
else
    fprintf('HW_TOBII_ROOT = %s\n', sdk);
    addpath(genpath(sdk));
end

if exist('GazeData', 'class') ~= 8
    fprintf('\nFAIL: GazeData is not on the path as a class. Nothing else can be probed.\n');
    fprintf('=======================================================\n\n');
    return
end
fprintf('\nGazeData found as a class.\n');

% --- 1. Zero-argument construction (gazeCodec.m:61) -------------------
fprintf('\n--- 1. Zero-arg construction: repmat(GazeData(), ...) at gazeCodec.m:61\n');
zeroArgWorks = false;
try
    GazeData(); %#ok<NASGU>
    zeroArgWorks = true;
    fprintf('    OK: GazeData() constructs with no arguments.\n');
catch ME
    fprintf('    THROWS: %s\n', ME.message);
    fprintf('    -> gazeCodec.m:61 fails on the first block commit with real data.\n');
end

% --- 2. Build a real instance using the documented constructor --------
fprintf('\n--- 2. Full constructor (18 args, as scripts/tests/test_gaze_codec.m:39)\n');
g = [];
try
    t = bitshift(uint64(1), 53) + uint64(1);
    a = {single([.2 .3]), single([1 2 3]), true, single(3.25), false, ...
        single([0 1 2]), single([.1 .2 .3]), true};
    g = GazeData(t, t + uint64(7), a{:}, a{:});
    fprintf('    OK: constructed. class = %s\n', class(g));
catch ME
    fprintf('    THROWS: %s\n', ME.message);
    fprintf('    -> the constructor signature assumed by gazeCodec.m:65 is wrong.\n');
    fprintf('    Reporting the real signature instead:\n');
    try
        mc = meta.class.fromName('GazeData');
        ctor = mc.MethodList(strcmp({mc.MethodList.Name}, 'GazeData'));
        if ~isempty(ctor)
            fprintf('      GazeData(%s)\n', strjoin(ctor(1).InputNames', ', '));
        end
    catch
        fprintf('      (constructor metadata unavailable)\n');
    end
    fprintf('=======================================================\n\n');
    return
end

% --- 3. Value or handle class (blockStore.m:26) -----------------------
fprintf('\n--- 3. Value vs handle semantics: isequaln assert at blockStore.m:26\n');
if isa(g, 'handle')
    fprintf('    HANDLE class. isequaln compares identity, not content.\n');
    fprintf('    -> blockStore.m:26 can never pass. Every block commit fails.\n');
else
    fprintf('    Value class (not a handle). isequaln compares content: OK.\n');
end

% --- 4. The Validity type (gazeCodec.m:105-107) -----------------------
fprintf('\n--- 4. Validity type: eyeArgs reads .Validity.value at gazeCodec.m:105\n');
try
    v = g.LeftEye.GazePoint.Validity;
    fprintf('    class(LeftEye.GazePoint.Validity) = %s\n', class(v));
    fprintf('    isobject = %d, isnumeric = %d, islogical = %d, isenum = %d\n', ...
        isobject(v), isnumeric(v), islogical(v), isenum(v));
    props = properties(v);
    if isempty(props)
        fprintf('    properties() returns NOTHING.\n');
        fprintf('    -> gazeCodec''s describe() emits ZERO leaves for Validity, so it\n');
        fprintf('       is silently dropped from storage and .Validity.value then\n');
        fprintf('       throws on unpack. Both bugs, same cause.\n');
    else
        fprintf('    properties() = %s\n', strjoin(props', ', '));
        fprintf('    has a ''value'' property: %d  (gazeCodec.m:105 requires this)\n', ...
            any(strcmp(props, 'value')));
    end
    fprintf('    display: %s\n', strtrim(evalc('disp(v)')));
catch ME
    fprintf('    THROWS walking to .LeftEye.GazePoint.Validity: %s\n', ME.message);
    fprintf('    -> the property path assumed by gazeCodec.m:104-107 is wrong.\n');
end

fprintf('\n    Other files reading the same type, which disagree with each other:\n');
fprintf('      gazeCodec.m:105      .Validity.value      (expects a wrapper object)\n');
fprintf('      gazeToPixels.m:15    .Validity == 1       (expects a bare number)\n');
fprintf('      positionGuide.m:236  ~= Validity.Valid    (expects an enumeration)\n');

% --- 5. The property tree gazeCodec will actually walk ----------------
fprintf('\n--- 5. Property tree as gazeCodec''s describe() will walk it\n');
try
    dumpTree(g, '    ', 0);
catch ME
    fprintf('    THROWS while walking: %s\n', ME.message);
end

% --- 6. The decisive test: the real round-trip ------------------------
fprintf('\n--- 6. DECISIVE: the round-trip blockStore.m:26 asserts on every commit\n');
try
    g(2) = g(1);
    packed = utils.gazeCodec('pack', g);
    fprintf('    pack OK: sampleCount = %d, leaves = %d, sourceClass = %s\n', ...
        packed.sampleCount, numel(packed.leafSchema), packed.sourceClass);
    back = utils.gazeCodec('unpack', packed);
    if isequaln(back, g)
        fprintf('    PASS: round-trip is exact. Block commits will not fail here.\n');
    else
        fprintf('    FAIL: round-trip is LOSSY but did not throw.\n');
        fprintf('    -> blockStore.m:26 throws hw:blockStore:roundtrip on every commit.\n');
        fprintf('    class(back) = %s, class(g) = %s\n', class(back), class(g));
    end
catch ME
    fprintf('    THROWS: %s\n', ME.identifier);
    fprintf('    %s\n', ME.message);
    fprintf('    -> this is the end-of-block crash, reproduced without a participant.\n');
end

fprintf('\n=======================================================\n');
fprintf('Paste this whole block back. Items 1, 3, 4 and 6 are the ones that matter.\n');
fprintf('=======================================================\n\n');
end

function dumpTree(v, indent, depth)
if depth > 4, fprintf('%s(deeper levels not shown)\n', indent); return; end
if (isstruct(v) || isobject(v)) && isscalar(v)
    if isobject(v), names = properties(v); else, names = fieldnames(v); end
    if isempty(names)
        fprintf('%s<%s> NO PUBLIC PROPERTIES -- describe() emits no leaf here\n', ...
            indent, class(v));
        return
    end
    for i = 1:numel(names)
        fprintf('%s%s: <%s>\n', indent, names{i}, class(v.(names{i})));
        dumpTree(v.(names{i}), [indent '  '], depth + 1);
    end
else
    fprintf('%s= %s %s\n', indent, class(v), mat2str(size(v)));
end
end
