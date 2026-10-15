function report = exportSession(cfg)
%UTILS.EXPORTSESSION  Derive the analysis exports and send them to the share.
%
%   report = utils.exportSession(cfg)
%
% utils.publishToShare sends the recovery layer: sessions, runs and verified
% block checkpoints. It does not send the per-run CSVs that analysis/R reads,
% because those are not captured -- they are derived from the blocks by
% scripts/combine_blocks. Until this existed that derivation was a manual
% command, so the share held no analysable data for any session after
% 2026-10-06 even though every block had been published correctly.
%
% WHERE THIS MAY BE CALLED FROM: only after the last task has torn down its
% window, immediately after utils.publishToShare. Never during capture.
%
% NEVER THROWS, by the same contract as publishToShare and mirrorDiagnostics.
% A derivation failure must not turn a completed session into a failed one:
% the local tree and the published blocks stay authoritative, and because
% combine_blocks rebuilds from the whole tree, the next session's export
% sweeps up anything this one could not produce.

report = struct('runId', {}, 'complete', {}, 'trialCount', {}, 'sampleCount', {}, 'output', {});

try
    if ~isfield(cfg, 'share') || ~cfg.share.exportOnCompletion
        return;
    end

    localRoot = cfg.paths.data;
    derivedRoot = cfg.paths.derived;
    shareDerived = cfg.paths.shareDerived;

    if ~isfolder(localRoot)
        fprintf(2, 'Not deriving exports: local root is missing (%s).\n', localRoot);
        return;
    end

    % combine_blocks and export_gaze_csv live in scripts/, three levels up
    % from here, and are not on the path unless the operator ran rig_checks.
    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    scriptsDir = fullfile(repoRoot, 'scripts');
    if isfolder(scriptsDir) && ~contains([path pathsep], [scriptsDir pathsep])
        addpath(scriptsDir);
    end

    fprintf('\nDeriving analysis exports ...\n');
    t0 = tic;

    % allowPartial so a crashed session still exports the blocks it verified.
    % Those land under <derived>/partial/, which the R globs skip.
    report = combine_blocks(localRoot, derivedRoot, 'allowPartial', true);
    export_gaze_csv(derivedRoot, 'rawRoot', localRoot);

    nComplete = 0;
    if ~isempty(report), nComplete = sum([report.complete]); end
    fprintf('Derived in %.1f s: %d run(s), %d complete.\n', ...
        toc(t0), numel(report), nComplete);

    % Same fast-fail as publishToShare: isfolder on a dead UNC path returns
    % rather than stalling the end of a session.
    if isempty(shareDerived) || ~isfolder(fileparts(shareDerived))
        fprintf(2, ['\n*** EXPORTS NOT SENT: the share is not reachable.\n' ...
                    '    They are complete on this machine at\n' ...
                    '    %s\n' ...
                    '    The next session''s export will send them.\n\n'], derivedRoot);
        return;
    end

    files = dir(fullfile(derivedRoot, '**', '*'));
    nSent = 0;
    for k = 1:numel(files)
        if files(k).isdir || contains(files(k).name, '.partial')
            continue;
        end
        source = fullfile(files(k).folder, files(k).name);
        relative = source(numel(derivedRoot)+2:end);
        utils.checkpointIO('copy', source, fullfile(shareDerived, relative));
        nSent = nSent + 1;
    end
    fprintf('Sent %d export file(s) to %s\n\n', nSent, shareDerived);

catch ME
    fprintf(2, ['\n*** EXPORTS NOT DERIVED: %s (%s)\n' ...
                '    Nothing is lost. The session is complete locally and\n' ...
                '    publishing has already sent the blocks it is built from.\n' ...
                '    The next session''s export will sweep this up.\n\n'], ...
        ME.message, ME.identifier);
end
end
