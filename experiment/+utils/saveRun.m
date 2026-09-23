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
dataMat.seed          = run.seed;
dataMat.codeVersion   = sess.codeVersion;
dataMat.startedAt     = run.startedAt;
dataMat.savedAt       = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));

save([run.fileStem '.mat'], 'dataMat', '-v7.3');

% --- Long-format CSV --------------------------------------------------
if nargin >= 4 && ~isempty(trialTable)
    n = height(trialTable);
    keys = table( ...
        repmat(sess.participant, n, 1), ...
        repmat(sess.sessionNum,  n, 1), ...
        repmat(string(run.runId), n, 1), ...
        repmat(string(run.task),  n, 1), ...
        'VariableNames', {'participant','session','run_id','task'});

    dupes = intersect(keys.Properties.VariableNames, ...
                      trialTable.Properties.VariableNames);
    if ~isempty(dupes)
        trialTable = removevars(trialTable, dupes);
    end

    writetable([keys trialTable], [run.fileStem '.csv']);
end

end
