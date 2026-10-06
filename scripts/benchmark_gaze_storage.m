function report = benchmark_gaze_storage(sourceFile, outputRoot, varargin)
%BENCHMARK_GAZE_STORAGE Compare copies; never modifies the input gaze file.
% report = benchmark_gaze_storage(sourceFile, outputRoot, 'shareRoot', path)
p = inputParser; p.addParameter('shareRoot', ''); p.parse(varargin{:});
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'experiment'));
sdk = getenv('HW_TOBII_ROOT');
if ~isempty(sdk), addpath(genpath(sdk)); end
assert(isfile(sourceFile), 'hw:benchmark:source', 'Source gaze file is missing.');
assert(~isfile(outputRoot), 'hw:benchmark:output', 'Output root must be a directory.');
runDir = fullfile(outputRoot, ['gaze-benchmark-' char(java.util.UUID.randomUUID)]);
[ok,msg] = mkdir(runDir); assert(ok, 'hw:benchmark:mkdir', '%s', msg);
sourceInfo = dir(sourceFile);
report = struct('source',sourceFile,'sourceBytes',sourceInfo.bytes, ...
    'sourceHash',utils.checkpointIO('hash',sourceFile),'sourceLoadSeconds',NaN, ...
    'packSeconds',NaN,'sampleCount',NaN,'outputs',[], ...
    'complete',false,'stage','load','error','');
reportFile = fullfile(runDir,'report.mat');
save(reportFile,'report');
fprintf('Benchmark report: %s\n',reportFile);
try
t = tic; source = load(sourceFile); report.sourceLoadSeconds = toc(t);
assert(isfield(source, 'gaze'), 'hw:benchmark:source', 'Source must contain gaze.');
report.stage = 'pack';
t = tic; packed = utils.gazeCodec('pack', source.gaze); report.packSeconds = toc(t);
report.sampleCount = numel(source.gaze);
assert(isequaln(utils.gazeCodec('unpack', packed), source.gaze), ...
    'hw:benchmark:roundtrip', 'Packing changed the source values.');
roots = {runDir};
if ~isempty(p.Results.shareRoot)
    remote = fullfile(p.Results.shareRoot, ['gaze-benchmark-' char(java.util.UUID.randomUUID)]);
    [ok,msg] = mkdir(remote); assert(ok, 'hw:benchmark:mkdir', '%s', msg);
    roots{end+1} = remote;
end
for r = 1:numel(roots)
    for kind = {'baseline', 'packed'}
        f = fullfile(roots{r}, [kind{1} '.mat']);
        data = source;
        if strcmp(kind{1}, 'packed'), data.gaze = packed; end
        report.stage = ['save ' f]; save(reportFile,'report');
        t = tic; save(f, '-struct', 'data', '-v7.3'); saveSeconds = toc(t);
        report.stage = ['reload ' f]; save(reportFile,'report');
        t = tic; check = load(f); reloadSeconds = toc(t);
        if strcmp(kind{1}, 'packed'), check.gaze = utils.gazeCodec('unpack', check.gaze); end
        assert(isequaln(check, source), 'hw:benchmark:roundtrip', 'Saved copy differs from source.');
        info = dir(f);
        row = struct('file', f, 'kind', kind{1}, 'bytes', info.bytes, ...
            'saveSeconds', saveSeconds, 'loadSeconds', reloadSeconds, 'equivalent', true);
        if isempty(report.outputs), report.outputs = row; else, report.outputs(end+1) = row; end
        save(reportFile, 'report');
        fprintf('%s: %d bytes, save %.3fs, load %.3fs, exact roundtrip\n', ...
            f, info.bytes, saveSeconds, reloadSeconds);
    end
end
assert(strcmp(report.sourceHash,utils.checkpointIO('hash',sourceFile)), ...
    'hw:benchmark:sourceChanged','Source changed during benchmark.');
report.complete = true; report.stage = 'complete'; save(reportFile,'report');
catch ME
    report.error = getReport(ME,'extended','hyperlinks','off');
    save(reportFile,'report');
    rethrow(ME);
end

end
