function out = taskBlock(action, sess, run, domain, varargin)
%UTILS.TASKBLOCK Shared adapter for task-specific block state and artifacts.
switch lower(action)
    case 'recover'
        out = utils.runCheckpoint('resolve', sess, run, domain);
        out.trials = struct([]); out.events = {}; out.blocks = {};
        for k = 1:numel(out.receipts)
            b = load(fullfile(out.receipts(k).artifactDirectory, 'behavior.mat'), 'behavior');
            out.blocks{end+1} = b.behavior;
            if ~strcmp(run.task, 'pref')
                out.trials = [out.trials reshape(b.behavior.trials, 1, [])]; %#ok<AGROW>
            end
            out.events{end+1} = b.behavior.events;
        end
        if isempty(out.entryState), out.entryState = out.nextState; end
        fprintf('Recovery %s [%s]: %d verified block(s), next block %d\n', ...
            run.task, domain, numel(out.receipts), out.nextBlock);
    case 'begin'
        ordinal = varargin{1}; entryState = varargin{2}; parent = varargin{3};
        context = struct('schemaVersion', 1, 'participant', sess.participant, ...
            'session', sess.sessionNum, 'task', run.task, 'domain', domain, ...
            'runKind', sess.runKind, 'logicalRunId', [run.runId '_' domain], ...
            'blockOrdinal', ordinal, 'parentAttemptId', parent);
        out = utils.blockStore('begin', sess.cfg, context, entryState);
        fprintf('Starting %s [%s] block %d, attempt %s\n', run.task, domain, ordinal, out.attemptId);
        utils.progressLog(run, 'BLOCK START %d attempt=%s', ordinal, out.attemptId);
    case 'finish'
        attempt = varargin{1}; payload = varargin{2}; et = varargin{3}; store = varargin{4};
        % Which MATLAB ran this block. Stamped before responses.mat so all
        % three artifacts carry it. It rides in metadata, never in the attempt
        % identity: identity is compared with isequaln across entry/behavior/
        % gaze/receipt (blockStore.m:73,150) and drives recovery, so adding a
        % field there would change what counts as the same attempt.
        payload.metadata.matlabRelease = version('-release');
        payload.metadata.matlabVersion = version;
        % Preserve responses before even asking the tracker for its final buffer.
        responses = payload; responses.identity = attempt;
        utils.checkpointIO('write', fullfile(attempt.directory, 'responses.mat'), struct('responses', responses));
        recording = utils.blockRecording('finish', et, store, payload.clockSync, run);
        payload.gaze = recording.gaze; payload.clockSync = recording.clockSync;
        utils.progressLog(run, 'BEGIN block commit block=%d samples=%d', attempt.blockOrdinal, numel(payload.gaze));
        out = utils.blockStore('commit', sess.cfg, attempt, payload);
        utils.gazeBuffer('release');
        utils.progressLog(run, 'END block commit block=%d attempt=%s', attempt.blockOrdinal, attempt.attemptId);
    otherwise
        error('hw:taskBlock:action', 'Unknown task-block action %s.', action);
end
end
