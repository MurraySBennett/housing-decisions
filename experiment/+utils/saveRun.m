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
    fallbackFileStem = fallbackStem(sess, run);
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
save([fileStem '.mat'], 'dataMat', '-v7.3');

% --- Long-format CSV --------------------------------------------------
if nargin >= 5 && ~isempty(trialTable)
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

    writetable([keys trialTable], [fileStem '.csv']);
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
