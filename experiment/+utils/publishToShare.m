function report = publishToShare(cfg)
%UTILS.PUBLISHTOSHARE  Replicate this rig's local capture to the share.
%
%   report = utils.publishToShare(cfg)
%
% Capture stays local for the whole session -- config.m:96's rule, and the
% reason the rig writes to %LOCALAPPDATA% rather than a UNC path. This is the
% other half of that design: once the session is over, the local tree is
% published to the share so it is reachable from anywhere without visiting the
% rig. It is the automatic caller of scripts/sync_blocks, which until now had
% to be run by hand and therefore was not run at all.
%
% WHERE THIS MAY BE CALLED FROM: only after the last task has torn down its
% window. Never between a stimulus and a response, never inside a flip loop,
% and never while a tracker is streaming. SMB latency is unbounded and would
% land directly in trial timing.
%
% NEVER THROWS, by the same contract as progressLog and mirrorDiagnostics: a
% replication failure must not turn a completed session into a failed one. The
% local tree remains authoritative and complete either way, and because
% sync_blocks walks the whole tree and checkpointIO('copy') is idempotent --
% it hashes both sides and returns early when they match -- the next session's
% publish sweeps up anything this one could not send.
%
% Returns sync_blocks' report (id/status/message rows), or an empty struct if
% publishing was skipped or failed before it could start.

report = struct('id', {}, 'status', {}, 'message', {});

try
    if ~isfield(cfg, 'share') || ~cfg.share.publishOnCompletion
        return;  % switched off deliberately; say nothing
    end

    localRoot = cfg.paths.data;
    shareRoot = cfg.paths.shareData;

    if isempty(shareRoot)
        fprintf(2, 'Not publishing to the share: no share root configured.\n');
        return;
    end
    if ~isfolder(localRoot)
        fprintf(2, 'Not publishing to the share: local root is missing (%s).\n', localRoot);
        return;
    end
    % isfolder on an unreachable UNC path fails fast. Checking it first is what
    % stops a dead share or a dropped VPN from stalling the end of a session
    % while the RA is trying to walk a participant out.
    if ~isfolder(shareRoot)
        fprintf(2, ['\n*** NOT PUBLISHED: the share is not reachable.\n' ...
                    '    %s\n' ...
                    '    The data is complete and safe on this machine. Re-run\n' ...
                    '    utils.publishToShare(sess.cfg) once the share is back, or\n' ...
                    '    just run the next session -- publishing sweeps the whole\n' ...
                    '    tree and will catch this one up.\n\n'], shareRoot);
        return;
    end

    % sync_blocks lives in scripts/, which is not on the path during a session.
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    scriptsDir = fullfile(repoRoot, 'scripts');
    if isfolder(scriptsDir) && ~contains([path pathsep], [scriptsDir pathsep])
        addpath(scriptsDir);
    end

    fprintf('\nPublishing to the share (%s) ...\n', shareRoot);
    t0 = tic;
    report = sync_blocks(localRoot, shareRoot);
    elapsed = toc(t0);

    % Summarise rather than dump: the RA needs to know whether to act, and a
    % 'conflict' row is the only one that needs a human.
    if isempty(report)
        fprintf('Published in %.1f s. Nothing new to send.\n\n', elapsed);
        return;
    end
    statuses = {report.status};
    nComplete = sum(strcmp(statuses, 'complete'));
    nPending  = sum(strcmp(statuses, 'pending'));
    nConflict = sum(strcmp(statuses, 'conflict'));
    fprintf('Published in %.1f s: %d complete, %d pending, %d conflict.\n', ...
        elapsed, nComplete, nPending, nConflict);
    for k = 1:numel(report)
        if ~strcmp(report(k).status, 'complete')
            fprintf(2, '  %-10s %-44s %s\n', report(k).status, report(k).id, report(k).message);
        end
    end
    if nConflict > 0
        % A conflict means the share already holds a DIFFERENT completed
        % attempt for that block. Nothing was overwritten -- sync_blocks
        % refuses -- but it needs resolving before the data is trustworthy.
        fprintf(2, ['\n*** %d CONFLICT(S) on the share. Nothing was overwritten.\n' ...
                    '    The share holds a different completed attempt for that\n' ...
                    '    block, which usually means two rigs ran the same\n' ...
                    '    participant. Resolve before analysing.\n\n'], nConflict);
    end
    fprintf('\n');

catch ME
    % Includes anything sync_blocks itself threw before producing rows.
    fprintf(2, ['\n*** NOT PUBLISHED: %s (%s)\n' ...
                '    The data is complete and safe on this machine. The next\n' ...
                '    session''s publish will sweep it up.\n\n'], ME.message, ME.identifier);
end
end
