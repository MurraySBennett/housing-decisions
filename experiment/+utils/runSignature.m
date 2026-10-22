function signature = runSignature(sess)
%UTILS.RUNSIGNATURE What must not change under a resumable run.
%
% utils.openRun stores this signature beside the run identity and refuses to
% resume a run whose signature differs -- so a code edit, a config change, or
% a stimulus-file change between sessions invalidates resumption on purpose.
% utils.sessionContext freezes the same signature for the whole battery.
c = sess.cfg;
% Paths can move across rigs. Values and source/stimulus contents cannot change.
for field = {'paths', 'stimFiles', 'codeVersion'}
    if isfield(c, field{1}), c = rmfield(c, field{1}); end
end
signature = struct('schemaVersion', 1, 'assignment', sess.assignment, ...
    'config', plain(c), 'codeVersion', sess.codeVersion, 'sources', [], 'stimuli', struct());
root = fileparts(fileparts(mfilename('fullpath')));
files = [dir(fullfile(root, '*.m')); dir(fullfile(root, '+utils', '*.m'))];
[~, order] = sort({files.name}); files = files(order);
signature.sources = cell(numel(files), 2);
for k = 1:numel(files)
    signature.sources(k,:) = {files(k).name, utils.checkpointIO('hash', fullfile(files(k).folder, files(k).name))};
end
stimFiles = sess.cfg.stimFiles;
% Preference jobs always use this ecological definition regardless of auction arm.
stimFiles.preferenceJobs = fullfile(sess.cfg.paths.prepared, 'job_stimuli_ecological.csv');
names = fieldnames(stimFiles);
for k = 1:numel(names)
    path = stimFiles.(names{k});
    if isfile(path)
        signature.stimuli.(names{k}) = utils.checkpointIO('hash', path);
    else
        signature.stimuli.(names{k}) = 'missing';
    end
end
end

function v = plain(v)
if isa(v, 'function_handle')
    v = func2str(v);
elseif isstruct(v)
    names = fieldnames(v);
    for i = 1:numel(v)
        for j = 1:numel(names), v(i).(names{j}) = plain(v(i).(names{j})); end
    end
elseif iscell(v)
    for i = 1:numel(v), v{i} = plain(v{i}); end
end
end
