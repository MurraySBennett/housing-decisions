function saveRun(sess, run, dataMat, trialTable)
%UTILS.SAVERUN  Write one task run to disk in a linkable form.
%
%   Writes <fileStem>.mat (dataMat + provenance) and, if a trial table is
%   supplied, <fileStem>.csv keyed by participant/session/run_id/task.

% --- Provenance stamped onto the struct -------------------------------
dataMat.participant   = sess.participant;
dataMat.sessionNum    = sess.sessionNum;
dataMat.runId         = run.runId;
dataMat.task          = run.task;
dataMat.domainOrder   = sess.domains;
dataMat.runKind       = sess.runKind;
dataMat.seed          = run.seed;
dataMat.codeVersion   = sess.codeVersion;
% Which MATLAB actually ran this. Deliberately NOT in runCheckpoint's
% signature: the fingerprint stops a run continuing across a change, and a
% release upgrade mid-participant is the operator's call, not a hard stop.
dataMat.matlabRelease = version('-release');
dataMat.matlabVersion = version;
if isfield(sess, 'assignment')
    dataMat.assignment = sess.assignment;
end
dataMat.startedAt     = run.startedAt;
dataMat.savedAt       = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));

if nargin < 4
    trialTable = [];
end

try
    writeRunFiles(run.fileStem, sess, run, dataMat, trialTable);
catch primaryME
    utils.progressLog(run, 'PRIMARY SAVE ERROR\n%s', getReport(primaryME, 'extended', 'hyperlinks', 'off'));
    utils.progressLog(run, 'BEGIN fallback preparation');
    fallbackFileStem = fallbackStem(sess, run);
    utils.progressLog(run, 'END fallback preparation: %s', fallbackFileStem);
    dataMat.primarySaveError = struct( ...
        'identifier', primaryME.identifier, ...
        'message', primaryME.message, ...
        'primaryFileStem', run.fileStem, ...
        'fallbackFileStem', fallbackFileStem, ...
        'recordedAt', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
    writeRunFiles(fallbackFileStem, sess, run, dataMat, trialTable);
    warning('hw:saveRun:fallback', ...
        ['Primary data save failed:\n    %s\n' ...
         'Emergency backup written locally:\n    %s'], ...
        run.fileStem, fallbackFileStem);
end

end

function writeRunFiles(fileStem, sess, run, dataMat, trialTable)
utils.progressLog(run, 'BEGIN behavioral MAT save: %s.mat', fileStem);
% Temp-then-rename with read-back, the same way checkpointIO writes block
% artifacts. A direct in-place -v7.3 save leaves a truncated file with no
% valid HDF signature if anything interrupts it, and that file can never
% be loaded again.
% Field assigned, not struct('dataMat', dataMat): struct() expands a
% non-scalar value into a struct ARRAY, which would silently change what
% gets written.
variables = struct();
variables.dataMat = dataMat;
utils.checkpointIO('write', [fileStem '.mat'], variables, true);
utils.progressLog(run, 'END behavioral MAT save');

% --- Long-format CSV --------------------------------------------------
% Guard on content only. This used to read `nargin >= 5`, which is the
% nargin of THIS function (always 5), not saveRun's -- so it never gated
% anything, and adding a parameter would have silently disabled the CSV.
if ~isempty(trialTable)
    utils.progressLog(run, 'BEGIN CSV preparation');
    n = height(trialTable);
    keys = table( ...
        repmat(sess.participant, n, 1), ...
        repmat(sess.sessionNum,  n, 1), ...
        repmat(string(run.runId), n, 1), ...
        repmat(string(run.task),  n, 1), ...
        repmat(string(sess.runKind), n, 1), ...
        'VariableNames', {'participant','session','run_id','task','run_kind'});

    dupes = intersect(keys.Properties.VariableNames, ...
                      trialTable.Properties.VariableNames);
    if ~isempty(dupes)
        trialTable = removevars(trialTable, dupes);
    end

    utils.progressLog(run, 'BEGIN behavioral CSV save rows=%d: %s.csv', n, fileStem);
    % Same reason as the MAT above: never leave a half-written CSV at the
    % final path. FileType is explicit because the temp name is not *.csv.
    csvFile = [fileStem '.csv'];
    csvTmp = [csvFile '.' utils.checkpointIO('id') '.partial'];
    writetable([keys trialTable], csvTmp, 'FileType', 'text', 'Delimiter', ',');
    [ok, msg] = movefile(csvTmp, csvFile, 'f');
    assert(ok, 'hw:saveRun:rename', 'Could not finalize %s: %s', csvFile, msg);
    utils.progressLog(run, 'END behavioral CSV save');
end
end

function fileStem = fallbackStem(sess, run)
if isfield(sess.cfg.paths, 'fallbackTaskData') && ...
        isfield(sess.cfg.paths.fallbackTaskData, run.task)
    fallbackDir = sess.cfg.paths.fallbackTaskData.(run.task);
else
    fallbackDir = fullfile(sess.cfg.paths.fallbackData, run.task);
end
if ~exist(fallbackDir, 'dir')
    mkdir(fallbackDir);
end
fileStem = fullfile(fallbackDir, run.runId);
end
