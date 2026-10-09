function dataMat = auction_task(sess, run)
%AUCTION_TASK  Sequential search with a continuous price response.
%
%   dataMat = auction_task(sess, run)
%   A trial is one whole search episode; with no arguments it bootstraps its own session.

if nargin < 1 || isempty(sess)
    sess = utils.startSession();
end
if nargin < 2 || isempty(run)
    run = utils.beginRun(sess, 'auction');
    standalone = true;
else
    standalone = false;
end

if isfield(run, 'domains') && ~isempty(run.domains)
    domainList = run.domains;
else
    domainList = sess.domains;
end

cfg = sess.cfg;
rs  = RandStream('twister', 'Seed', run.seed);
tl  = utils.timeline('start');

dataMat = struct();
dataMat.domains = domainList;
% Theme is saved so a rolled-back session can be stratified in analysis.
dataMat.theme   = cfg.style.themeName;
% [] on a full run, integer on a rehearsal -- the analysis filter for rehearsal runs.
dataMat.trialsPerCell = cfg.rehearsal.trialsPerCell;
window = [];
et = struct('enabled', false, 'obj', [], 'showGaze', false, 'analyzable', false);

utils.progressLog(run, 'TASK ENTER');
try
    % =============================================== display setup
    % Clear PsychImaging's persistent config state left dirty by a prior crashed run.
    clear PsychImaging;
    utils.trace('display setup starting');
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', double(cfg.display.skipSyncTests));
    screenNumber = max(Screen('Screens'));

    if cfg.testing.enabled && cfg.testing.windowed
        [window, winRect] = PsychImaging('OpenWindow', screenNumber, ...
            cfg.style.bg, [50 50 1330 770]);
    else
        [window, winRect] = PsychImaging('OpenWindow', screenNumber, cfg.style.bg);
    end
    utils.trace('window opened, handle=%g rect=[%s]', window, mat2str(winRect));
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

    % Fonts can only be probed here (window open, nothing drawn); sole post-config mutation of cfg.style.
    cfg.style = utils.resolveFonts(window, cfg.style);
    utils.trace('fonts: content=%s chrome=%s', ...
        cfg.style.fontContent, cfg.style.fontChrome);

    Priority(MaxPriority(window));
    ShowCursor('Arrow', window);
    ListenChar(2);

    geom = cfg.geom;
    geom.widthPx  = winRect(3);
    geom.heightPx = winRect(4);

    % =============================================== eye tracker
    utils.trace('setting up eye tracker (enabled=%d)', cfg.et.enabled);
    et = utils.setupEyeTracker(cfg, window, ~cfg.testing.enabled);
    utils.trace('eye tracker setup done (connected=%d)', et.enabled);
    dataMat.eyeTracking = struct('enabled', et.enabled, ...
                                 'analyzable', et.analyzable, ...
                                 'positioned', et.positioned, ...
                                 'mediaMode', et.showGaze, ...
                                 'requestedSampleRateHz', et.requestedSampleRateHz, ...
                                 'actualSampleRateHz', et.actualSampleRateHz, ...
                                 'setupFailureStage', et.setupFailureStage, ...
                                 'setupFailureMessage', et.setupFailureMessage, ...
                                 'operatorChoice', et.operatorChoice);

    % =============================================== per domain
    for d = 1:numel(domainList)
        domain = domainList{d};
        fprintf('\n===== %s =====\n', upper(domain));

        utils.trace('domain %s: loading stimuli', domain);
        A = utils.attributes(domain);
        frozen = utils.runCheckpoint('peek', sess, run, domain);
        if isempty(frozen)
        stimuli = utils.readStimuli(cfg, domain);
        utils.trace('domain %s: %d stimuli loaded', domain, height(stimuli));

        % ---- elicitation ------------------------------------------
        % Same-session elicitations are reused; a new session is a deliberate cache miss.
        tl = utils.timeline('section', tl, sprintf('%s:elicitation', domain));
        cached = utils.elicitationCache('load', sess, domain);
        if ~isempty(cached)
            anchor          = cached.anchor;
            anchorRT        = cached.anchorRT;
            poolRatings     = cached.poolRatings;
            attrRTs         = cached.attrRTs;
            coreRatings     = cached.coreRatings;
            coreRTs         = cached.coreRTs;
            industryRatings = cached.industryRatings;
            if strcmpi(domain, 'jobs') && ~isempty(cached.keepIndustries)
                stimuli = stimuli(ismember(stimuli.industry, cached.keepIndustries), :);
            end
        elseif cfg.testing.enabled && cfg.testing.skipElicitation
            anchor = utils.ternary(strcmpi(domain,'houses'), 400000, 25);
            anchorRT = NaN;
            poolRatings = linspace(0.9, 0.1, A.nPool);
            attrRTs = nan(1, A.nPool);
            coreRatings = repmat(0.9, 1, A.nCore);
            coreRTs = nan(1, A.nCore);
            industryRatings = [];
        else
            utils.trace('domain %s: eliciting anchor', domain);
            [anchor, anchorRT] = utils.elicitAnchor(window, cfg, domain);
            utils.trace('domain %s: anchor = %g', domain, anchor);

            industryRatings = [];
            keepIndustries = {};
            if strcmpi(domain, 'jobs')
                inds = unique(stimuli.industry);
                [industryRatings, ~, ~] = utils.elicitRatings(window, cfg, cellstr(inds), ...
                    'How likely would you be to apply for a job in each of these industries?', ...
                    {'Entirely unlikely', 'Extremely likely'}, rs);
                [~, ord] = sort(industryRatings, 'descend');
                keepIndustries = cellstr(inds(ord(1:min(cfg.sampling.nTopIndustries, numel(ord)))));
                stimuli = stimuli(ismember(stimuli.industry, keepIndustries), :);
                fprintf('Filtered to %d jobs across %d industries.\n', height(stimuli), numel(keepIndustries));
            end

            % Price/wage is rated with the pool but excluded from selection (see utils.elicitAttrRatings).
            attrR       = utils.elicitAttrRatings(window, cfg, A, rs);
            poolRatings = attrR.pool;
            attrRTs     = attrR.poolRTs;
            coreRatings = attrR.core;
            coreRTs     = attrR.coreRTs;

            capture = struct();
            capture.anchor          = anchor;
            capture.anchorRT        = anchorRT;
            capture.poolRatings     = poolRatings;
            capture.attrRTs         = attrRTs;
            capture.coreRatings     = coreRatings;
            capture.coreRTs         = coreRTs;
            capture.industryRatings = industryRatings;
            capture.keepIndustries  = keepIndustries;
            utils.elicitationCache('save', sess, domain, capture);
        end

        % ---- attribute selection ----------------------------------
        % Attribute count is fixed here; the attribute-count manipulation lives in continuous_DC_task.
        sel = utils.selectAttributes(A, cfg.auction.nAttrs, poolRatings, ...
                                  cfg.attrMethod, false);
        fprintf('Showing %d attributes (mean importance rank %.1f).\n', ...
            numel(sel.shown), sel.meanRank);

        % ---- stimulus window --------------------------------------
        [inWindow, win] = utils.applyWindow(stimuli, A, anchor, cfg);
        fprintf('Window %s to %s: %d stimuli (%s, widened %.2fx).\n', ...
            utils.formatCurrency(win.lo, A.priceStyle), ...
            utils.formatCurrency(win.hi, A.priceStyle), win.n, win.mode, win.widenBy);

        % ---- trial plan -------------------------------------------
        nTrials = cfg.auction.nTrials;
        if ~isempty(cfg.rehearsal.trialsPerCell)
            % trialsPerCell is per competition level (2N total); cfg.testing.nTrialsPerType sets the TOTAL.
            nTrials = cfg.rehearsal.trialsPerCell * 2;
        end
        if cfg.testing.enabled
            nTrials = cfg.testing.nTrialsPerType;
        end
        planCfg = cfg; planCfg.auction.nTrials = nTrials;
        planCfg.auction.nOptionsPerTrial = min(cfg.auction.nOptionsPerTrial, win.n);
        % Participant parity picks the first competition level, matching utils.batteryPlan's task-order parity.
        plan = utils.trialPlan(planCfg, win.n, rs, sess.participant);

        if ~isempty(cfg.testing.forceCompetition)
            [plan.competition] = deal(cfg.testing.forceCompetition);
        end

        else
            anchor = frozen.anchor;
            anchorRT = frozen.anchorRT;
            poolRatings = frozen.poolRatings;
            attrRTs = frozen.attrRTs;
            coreRatings = frozen.coreRatings;
            coreRTs = frozen.coreRTs;
            industryRatings = frozen.industryRatings;
            sel = frozen.sel;
            inWindow = frozen.inWindow;
            win = frozen.win;
            plan = frozen.plan;
        end

        % ---- textures ---------------------------------------------
        neededIdx = [];
        for t = 1:numel(plan)
            neededIdx = [neededIdx, plan(t).stimIdx]; %#ok<AGROW>
        end
        utils.trace('domain %s: loading images for %d stimuli (of %d sampled)', ...
            domain, numel(unique(neededIdx)), win.n);
        tex = utils.loadStimulusTextures(window, cfg, inWindow, A, neededIdx, true);

        % ---- instructions -----------------------------------------
        tl = utils.timeline('section', tl, sprintf('%s:instructions', domain));
        if ~isempty(frozen)
            comprehension = frozen.comprehension;
        elseif ~(cfg.testing.enabled && cfg.testing.skipInstructions)
            showInstructions(window, cfg, domain);
            comprehension = runComprehensionChecks(window, cfg, domain);
        else
            comprehension = struct('shown', false, 'passed', true, ...
                'responses', {{}}, 'attempts', []);
        end

        % ---- layout + AOI validation ------------------------------
        L = layoutGrid(winRect, cfg);
        [aoiOK, aoiReport] = utils.checkAOIs(L.aoiRects, L.aoiNames, geom, true);
        if ~aoiOK && strcmp(cfg.aoiEnforcement, 'strict')
            warning('hw:auction:aoiTooClose', ...
                'Some AOIs are below the minimum separation -- see report above.');
        end
        detailAOIs = utils.layoutDetailAOIs(winRect, cfg, sel);
        [detailAoiOK, detailAoiReport] = utils.checkAOIs( ...
            detailAOIs.rects, detailAOIs.names, geom, true);
        if ~detailAoiOK && strcmp(cfg.aoiEnforcement, 'strict')
            warning('hw:auction:detailAoiTooClose', ...
                'Some detail-view AOIs are below the minimum separation -- see report above.');
        end

        % Same layout and AOI functions as contdc's price card, so gaze on the two pricing screens is comparable.
        bidL = utils.layoutCardAndArc(winRect, cfg, geom, numel(sel.shown));
        bidAOIs = utils.cardAOIs(cfg, bidL.cardRect, sel, 'bid');
        [bidAoiOK, bidAoiReport] = utils.checkAOIs( ...
            bidAOIs.rects, bidAOIs.names, geom, true);
        if ~bidAoiOK && strcmp(cfg.aoiEnforcement, 'strict')
            warning('hw:auction:bidAoiTooClose', ...
                'Some bid-screen AOIs are below the minimum separation -- see report above.');
        end

        % ---- run trials -------------------------------------------
        trials = struct([]);
        wonStimIdx = [];
        log = utils.eventLog('init', 20000);
        if isempty(frozen)
        recording = utils.blockRecording('start', et);
        gazeStore = recording.store;
        tl = utils.timeline('section', tl, sprintf('%s:practice', domain));
        if ~(cfg.testing.enabled && cfg.testing.skipInstructions)
            [practiceTrial, log, gazeStore] = runPracticeEpisode( ...
                window, cfg, geom, L, et, log, gazeStore, ...
                inWindow, tex, sel, A, domain, plan(1), rs, win);
            trials = practiceTrial;

            % Parts = runs of one competition level; must match the levelChange computation below.
            nParts = 1 + sum(~strcmp({plan(2:end).competition}, ...
                                     {plan(1:end-1).competition}));
            showClickMessage(window, cfg, sprintf(['The practice round is over.' ...
                '\n\nThe real markets start now. Take a moment to ask any ' ...
                'questions before continuing.\n\nThere are %d real markets, in %d ' ...
                'parts, and your decisions from here on are the ones we ' ...
                'record.\n\nClick when you are ready to begin the real markets.'], ...
                numel(plan), nParts));
        end

        practiceRecording = utils.blockRecording('finish', et, gazeStore, recording.clockSync, run);
        practice = struct('trials', trials, 'events', utils.eventLog('table', log), ...
            'gaze', utils.gazeCodec('pack', practiceRecording.gaze), 'clockSync', practiceRecording.clockSync);
        frozen = struct();
        frozen.anchor = anchor;
        frozen.anchorRT = anchorRT;
        frozen.poolRatings = poolRatings;
        frozen.attrRTs = attrRTs;
        frozen.coreRatings = coreRatings;
        frozen.coreRTs = coreRTs;
        frozen.industryRatings = industryRatings;
        frozen.sel = sel;
        frozen.inWindow = inWindow;
        frozen.win = win;
        frozen.plan = plan;
        frozen.comprehension = comprehension;
        frozen.practiceTrials = trials;
        frozen.practiceRecording = practice;
        frozen.blockCount = max([plan.block]);
        frozen.rsState = rs.State; frozen.globalState = rng; frozen.screenRect = winRect;
        utils.runCheckpoint('freeze', sess, run, domain, frozen);
        clear practiceRecording practice gazeStore recording;
        end
        assert(isequal(winRect, frozen.screenRect), 'hw:auction:displayChanged', 'Display geometry changed on resume.');
        rs.State = frozen.rsState; rng(frozen.globalState);
        recovery = utils.taskBlock('recover', sess, run, domain);
        trials = [frozen.practiceTrials recovery.trials];
        domainEvents = recovery.events;
        parentAttempt = recovery.parentAttemptId;
        if ~isempty(recovery.entryState)
            plan = recovery.entryState.plan; wonStimIdx = recovery.entryState.wonStimIdx;
            rs.State = recovery.entryState.rsState; rng(recovery.entryState.globalState);
        end

        % Breaks go at competition-level changes, not block indices: ABBA makes blocks 2-3 one continuous run.
        tl = utils.timeline('section', tl, sprintf('%s:trials', domain));
        levelChange = [false, ~strcmp({plan(2:end).competition}, ...
                                      {plan(1:end-1).competition})];
        nRuns = 1 + sum(levelChange);
        utils.trace('domain %s: starting %d trials, %d blocks, %d run(s) of a level', ...
            domain, numel(plan), numel(unique([plan.block])), nRuns);
        firstPending = find([plan.block] == recovery.nextBlock, 1);
        if isempty(firstPending), firstPending = numel(plan) + 1; end
        runIdx = 1 + sum(levelChange(1:max(0, firstPending-1)));
        for t = firstPending:numel(plan)
            b = plan(t).block;
            if t == firstPending || plan(t-1).block ~= b
                firstTrial = numel(trials) + 1;
                entryState = struct('plan', plan, 'wonStimIdx', wonStimIdx, ...
                    'rsState', rs.State, 'globalState', rng);
                attempt = utils.taskBlock('begin', sess, run, domain, b, entryState, parentAttempt);
                log = utils.eventLog('init', 20000);
                log = utils.eventLog('context', log, struct('block', b, 'attemptId', attempt.attemptId));
                recording = utils.blockRecording('start', et);
                gazeStore = recording.store; clockSync = recording.clockSync;
            end
            log = utils.eventLog('context', log, struct('trial', t));
            % Break message must not name the direction of the competition change.
            if levelChange(t)
                % This break sits INSIDE the block recording started above, and
                % it waits on a click for as long as the participant wants.
                % showClickMessage never polled, and get_gaze_data() is the only
                % thing that empties the SDK queue, so samples were dropped from
                % a block still reported complete. The marker now carries the
                % real flip time and a phase, making the break an explicit
                % interval in the gaze association instead of an unexplained
                % gap; it previously logged GetSecs with no phase at all.
                [gazeStore, breakOnset] = showBreakMessage(window, cfg, ...
                    sprintf(['End of part %d of %d.' ...
                    '\n\nTake a moment if you would like one.' ...
                    '\n\nWhat follows is a different market: how much ' ...
                    'competition there is for these options has changed.' ...
                    '\n\nClick when you are ready to continue.'], ...
                    runIdx, nRuns), et, gazeStore);
                log = utils.eventLog('add', log, 'block_break', breakOnset, ...
                    struct('trial', t, 'phase', 'break', ...
                           'fromBlock', plan(t-1).block, ...
                           'toBlock', plan(t).block, 'run', runIdx + 1));
                runIdx = runIdx + 1;
            end

            if cfg.et.driftCheck && mod(t, cfg.auction.driftEvery) == 1 && t > 1
                [offset, recal, gazeStore, driftMarkers] = utils.driftCheck(et, window, cfg, ...
                    [winRect(3)/2, winRect(4)/2], gazeStore);
                for markerIdx = 1:numel(driftMarkers)
                    marker = driftMarkers(markerIdx);
                    log = utils.eventLog('add',log,marker.event,marker.flipTime, ...
                        struct('trial',0,'phase',marker.phase));
                end
                log = utils.eventLog('add', log, 'drift_check', GetSecs, ...
                    struct('offsetDeg', offset, 'recalibrated', double(recal)));
            end

            [trial, log, gazeStore] = runSearchEpisode( ...
                window, cfg, geom, L, et, log, gazeStore, ...
                inWindow, tex, sel, A, domain, plan(t), numel(plan), rs, win);

            if isempty(trials), trials = trial; else, trials(end+1) = trial; end %#ok<AGROW>

            utils.progressLog(run, ['TRIAL block=%d trial=%d/%d domain=%s ' ...
                'bid=%.2f bidRT=%.3f endReason=%s'], ...
                trial.block, t, numel(plan), domain, ...
                trial.bid, trial.bidRT, trial.endReason);

            % Only WON items are retired; rejected/expired items may deliberately relist (repIdx tracks repeats).
            if trial.bidAccepted && isfinite(trial.bidStimIdx)
                [plan, nStruck] = retireStimulus(plan, t, trial.bidStimIdx, ...
                    cfg.auction.minOptionsAfterRetire);
                wonStimIdx(end+1) = trial.bidStimIdx; %#ok<AGROW>
                log = utils.eventLog('add', log, 'stimulus_retired', GetSecs, ...
                    struct('stimIdx', trial.bidStimIdx, 'trial', t, ...
                           'struckFromTrials', nStruck));
            end
            if t == numel(plan) || plan(t+1).block ~= b
                log = utils.eventLog('add', log, 'recording_stop', GetSecs, struct('trial', 0));
                blockTrials = trials(firstTrial:end);
                payload = struct('trials', blockTrials, 'trialTable', utils.auctionTrialTable(domain, blockTrials, anchor), ...
                    'events', utils.eventLog('table', log), 'clockSync', clockSync);
                metadataPlan = rmfield(frozen, 'practiceRecording');
                payload.metadata = struct('frozenPlan', metadataPlan, 'gridLayout', L, ...
                    'detailAOIs', detailAOIs, 'bidAOIs', bidAOIs, 'bidLayout', bidL, ...
                    'eyeTracking', dataMat.eyeTracking, 'attributes', A);
                payload.nextState = struct('plan', plan, 'wonStimIdx', wonStimIdx, ...
                    'rsState', rs.State, 'globalState', rng);
                utils.savingScreen(window, cfg, 0.1, 'Saving completed block', utils.didYouKnow(run.seed));
                receipt = utils.taskBlock('finish', sess, run, domain, attempt, payload, et, gazeStore);
                parentAttempt = receipt.attemptId; domainEvents{end+1} = payload.events;
                clear gazeStore recording payload blockTrials;
            end
        end

        utils.progressLog(run, 'TRIALS FINISHED domain=%s; BEGIN result assembly', domain);
        % ---- store ------------------------------------------------
        dataMat.(domain).anchor          = anchor;
        dataMat.(domain).anchorRT        = anchorRT;
        dataMat.(domain).reservationWage = utils.ternary(strcmpi(domain,'jobs'), anchor, NaN);
        dataMat.(domain).budget          = utils.ternary(strcmpi(domain,'houses'), anchor, NaN);
        dataMat.(domain).poolRatings     = poolRatings;
        dataMat.(domain).poolRatingRTs   = attrRTs;
        dataMat.(domain).poolLabels      = {A.pool.label};
        dataMat.(domain).coreRatings     = coreRatings;
        dataMat.(domain).coreRatingRTs   = coreRTs;
        dataMat.(domain).coreLabels      = {A.core.label};
        dataMat.(domain).industryRatings = industryRatings;
        dataMat.(domain).attrSelection   = sel;
        dataMat.(domain).window          = win;
        dataMat.(domain).stimuliShown    = inWindow;
        dataMat.(domain).plan            = plan;
        dataMat.(domain).comprehension   = comprehension;
        dataMat.(domain).wonStimIdx      = wonStimIdx;
        dataMat.(domain).trials          = trials;
        dataMat.(domain).events          = utils.stackTables(domainEvents);
        dataMat.(domain).aoiRects        = L.aoiRects;
        dataMat.(domain).aoiNames        = L.aoiNames;
        dataMat.(domain).aoiReport       = aoiReport;
        dataMat.(domain).detailAoiRects   = detailAOIs.rects;
        dataMat.(domain).detailAoiNames   = detailAOIs.names;
        dataMat.(domain).detailAoiReport  = detailAoiReport;
        dataMat.(domain).bidAoiRects      = bidAOIs.rects;
        dataMat.(domain).bidAoiNames      = bidAOIs.names;
        dataMat.(domain).bidAoiReport     = bidAoiReport;
        dataMat.(domain).bidCardRect      = bidL.cardRect;

        dataMat.(domain).checkpointRun = [run.runId '_' domain];
        savingFact = utils.didYouKnow(run.seed);

        utils.savingScreen(window, cfg, 0.55, 'Releasing images', savingFact);
        utils.progressLog(run, 'BEGIN releasing textures');
        Screen('Close', struct2texlist(tex));
        utils.progressLog(run, 'END releasing textures');
    end

    % =============================================== payout
    tl = utils.timeline('section', tl, 'payout_save');
    utils.progressLog(run, 'BEGIN payout computation');
    payout = utils.incentives('compute', sess, dataMat, cfg.incentives);
    utils.progressLog(run, 'END payout computation');
    dataMat.payout = payout;
    if cfg.incentives.enabled
        utils.progressLog(run, 'BEGIN payout display; waiting for participant');
        showPayout(window, cfg, payout);
        utils.progressLog(run, 'END payout display');
    else
        utils.progressLog(run, 'BEGIN end-of-task message');
        showMessage(window, cfg, 'Thank you. That is the end of this task.', 2.5);
        utils.progressLog(run, 'END end-of-task message');
    end

    % =============================================== save
    savingFact = utils.didYouKnow(run.seed);
    utils.savingScreen(window, cfg, 0.75, 'Writing trial data', savingFact);
    tl = utils.timeline('stop', tl);
    dataMat.timing = utils.timeline('table', tl);
    utils.progressLog(run, 'BEGIN trial table construction');
    trialTable = buildTrialTable(dataMat);
    utils.progressLog(run, 'END trial table construction rows=%d', height(trialTable));
    try
        utils.saveRun(sess, run, dataMat, trialTable);
    catch summaryError
        utils.progressLog(run, 'Optional summary save failed: %s; block receipts remain authoritative', summaryError.message);
    end
    utils.progressLog(run, 'END behavioral saves');
    utils.savingScreen(window, cfg, 1.00, 'Done - thank you', savingFact);
    WaitSecs(1.2);

    utils.progressLog(run, 'BEGIN display cleanup');
    ListenChar(0); ShowCursor; Priority(0); sca; clear PsychImaging;
    utils.progressLog(run, 'END display cleanup; task returning');
    if standalone, utils.endRun(sess, run, 'complete'); end

catch ME
    utils.preserveGazeFailure(sess, run, et);
    utils.progressLog(run, 'TASK ERROR before cleanup\n%s', getReport(ME, 'extended', 'hyperlinks', 'off'));
    ListenChar(0); ShowCursor; Priority(0);
    % sca resets Screen state but not PsychImaging's persistent config; both must run or the next OpenWindow in this MATLAB session fails.
    sca;
    clear PsychImaging;
    % Best-effort and separately guarded, matching preference_task. These were
    % bare, so a failure writing the dump or updating the manifest propagated
    % INSTEAD of ME: the battery above then caught the bookkeeping error and the
    % real reason the session died was gone. rethrow(ME) must always be what
    % leaves this block.
    try
        crashFile = fullfile(cfg.paths.crashed, [run.runId '_' utils.checkpointIO('id') '_crash.mat']);
        save(crashFile, 'ME', 'dataMat', 'sess', 'run');
        fprintf(2, '\nCrashed. Partial data saved to:\n  %s\n', crashFile);
    catch dumpME
        fprintf(2, '\nCrashed, and the crash dump could not be written (%s).\n', dumpME.message);
    end
    if standalone
        try
            utils.endRun(sess, run, 'crashed');
        catch manifestME
            fprintf(2, 'Could not mark the run crashed in the manifest: %s\n', manifestME.message);
        end
    end
    rethrow(ME);
end

end


%% ======================================================================
function [trial, log, gazeStore] = runSearchEpisode(window, cfg, geom, L, et, ...
    log, gazeStore, stimTbl, tex, sel, A, domain, planRow, nTrials, rs, win)
%RUNSEARCHEPISODE  One complete search-and-bid trial.

s = cfg.style;
nBoxes = size(L.boxRects, 2);

trial = struct();
trial.trial       = planRow.trial;
trial.domain      = domain;
trial.competition = planRow.competition;
% Not utils.ternary: both branches evaluate, and planRow.block may not exist.
if isfield(planRow, 'block'), trial.block = planRow.block; else, trial.block = NaN; end
if isfield(planRow, 'blockPos'), trial.blockPos = planRow.blockPos; else, trial.blockPos = NaN; end
trial.stimIdx     = planRow.stimIdx;
trial.repIdx      = planRow.repIdx;
trial.nAttrs      = numel(sel.shown);
trial.practice    = isfield(planRow, 'practice') && planRow.practice;

% Arrival schedule: higher competition means faster turnover.
onMarket = cfg.auction.onMarketMean.(lower(planRow.competition));
nInit = min(nBoxes, numel(planRow.stimIdx));
nLater = max(0, numel(planRow.stimIdx) - nBoxes);
arrivals = cumsum([zeros(1, nInit), ...
    utils.gammaSample(cfg.auction.arrivalShape, ...
                   onMarket/cfg.auction.arrivalShape, nLater, rs)]);
expiry = arrivals + utils.gammaSample(cfg.auction.arrivalShape, ...
    onMarket/cfg.auction.arrivalShape, numel(arrivals), rs) * cfg.auction.dwellFactor;

boxStim   = nan(1, nBoxes);      % which stimulus is in each box
boxSince  = nan(1, nBoxes);
boxVacantUntil = zeros(1, nBoxes); % earliest time a box may refill
nextIdx   = 1;
presented = [];
rejected  = [];
inspections = struct('stimIdx', {}, 'enterTime', {}, 'exitTime', {}, 'action', {});

trial.bidAccepted = false;
trial.bid         = NaN;
trial.pricePaid   = NaN;
trial.threshold   = NaN;
trial.trueValue   = NaN;
trial.bidStimIdx  = NaN;
trial.bidRT       = NaN;
% Must default here or buildTrialTable hits a missing field on trials with no bid.
trial.bidStartFrac = NaN;
trial.endReason   = 'exhausted';

% Fixation gate runs BEFORE t0: the arrival/expiry clock starts at the ready click.
[t0, log] = utils.awaitFixationStart(window, cfg, log, struct( ...
    'trial', planRow.trial, 'nTrials', nTrials, ...
    'label', sprintf('%s - %s competition', domain, planRow.competition)));
lastFlip = t0;
gridVisible = false;
pending = {};

while true
    now = GetSecs - t0;

    % ---- retire expired options ------------------------------------
    for b = 1:nBoxes
        if ~isnan(boxStim(b))
            k = find(planRow.stimIdx == boxStim(b), 1);
            if ~isempty(k) && now > expiry(k)
                pending{end+1} = struct('event', 'option_remove', 'info', ...
                    struct('box', b, 'stimIdx', boxStim(b), ...
                           'trial', planRow.trial, 'reason', 'expired'));
                boxStim(b) = NaN;
                boxVacantUntil(b) = now + vacancyGap(cfg, rs);
            end
        end
    end

    % ---- fill empty boxes -------------------------------------------
    % A box must also have cleared its vacancy timer, or a backlog gives instant replacements.
    for b = 1:nBoxes
        if isnan(boxStim(b)) && nextIdx <= numel(planRow.stimIdx) ...
                && now >= arrivals(nextIdx) && now >= boxVacantUntil(b)
            boxStim(b)  = planRow.stimIdx(nextIdx);
            boxSince(b) = now;
            presented(end+1) = planRow.stimIdx(nextIdx); %#ok<AGROW>
            pending{end+1} = struct('event', 'option_appear', 'info', ...
                struct('box', b, 'stimIdx', boxStim(b), ...
                       'trial', planRow.trial, ...
                       'repIdx', planRow.repIdx(nextIdx)));
            nextIdx = nextIdx + 1;
        end
    end

    % ---- draw --------------------------------------------------------
    drawGrid(window, cfg, L, stimTbl, tex, sel, A, boxStim, domain, ...
             struct('trial', planRow.trial, 'nTrials', nTrials, ...
                    'label', [domain ' - ' planRow.competition]));

    gazeStore = utils.gazeBuffer('poll', et, gazeStore);
    if et.showGaze && ~isempty(gazeStore.latest)
        drawGazeDot(window, cfg, gazeStore.latest);
    end

    lastFlip = Screen('Flip', window);
    if ~gridVisible
        log = utils.eventLog('add', log, 'search_onset', lastFlip, struct('trial', planRow.trial));
        gridVisible = true;
    end
    for eventIdx = 1:numel(pending)
        log = utils.eventLog('add', log, pending{eventIdx}.event, lastFlip, pending{eventIdx}.info);
    end
    pending = {};
    % ---- end conditions ---------------------------------------------
    if all(isnan(boxStim)) && nextIdx > numel(planRow.stimIdx)
        trial.endReason = 'exhausted';
        break
    end
    if now > cfg.auction.trialTimeoutSec
        trial.endReason = 'timeout';
        break
    end

    utils.checkForQuit;

    % ---- respond ------------------------------------------------------
    [mx, my, buttons] = utils.getMouse(window);
    if ~any(buttons), continue; end
    b = boxAtPoint(L.boxRects, mx, my);
    if isnan(b) || isnan(boxStim(b))
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        continue
    end

    isLeft = buttons(1);
    while any(buttons), [~,~,buttons] = utils.getMouse(window); end
    stimIdx = boxStim(b);

    if ~isLeft
        % Right click = reject. This is the rejection-threshold data.
        rejected(end+1) = stimIdx; %#ok<AGROW>
        log = utils.eventLog('add', log, 'option_reject', GetSecs, ...
            struct('box', b, 'stimIdx', stimIdx, 'trial', planRow.trial, ...
                   'dwellSec', now - boxSince(b)));
        pending{end+1} = struct('event', 'option_remove', 'info', ...
            struct('box', b, 'stimIdx', stimIdx, 'trial', planRow.trial, 'reason', 'rejected'));
        boxStim(b) = NaN;
        boxVacantUntil(b) = now + vacancyGap(cfg, rs);
        continue
    end

    % ---- detail view ---------------------------------------------------
    gridVisible = false;
    [action, gazeStore, log, enterT] = showDetail(window, cfg, geom, et, log, ...
        gazeStore, stimTbl, tex, sel, A, stimIdx, domain, ...
        struct('trial', planRow.trial, 'nTrials', nTrials, ...
               'label', [domain ' - ' planRow.competition]));

    inspections(end+1) = struct('stimIdx', stimIdx, 'enterTime', enterT - t0, ...
        'exitTime', GetSecs - t0, 'action', action); %#ok<AGROW>

    if strcmp(action, 'back')
        log = utils.eventLog('add', log, 'detail_exit', GetSecs, ...
            struct('stimIdx', stimIdx, 'trial', planRow.trial, 'action', 0));
        continue
    end

    % ---- bid -----------------------------------------------------------
    itemValue = stimTbl.(A.valueVar)(stimIdx);
    [threshold, trueValue] = utils.marketThreshold(itemValue, planRow.competition, ...
                                                domain, cfg, rs);

    [bid, bidRT, bidStartFrac, gazeStore, log] = getBid(window, cfg, geom, et, log, ...
        gazeStore, stimTbl, tex, sel, A, stimIdx, domain, planRow, nTrials, win, rs);

    if isnan(bid)
        continue
    end

    % BDM: the bid decides WHETHER you transact, never what you pay -- keeps truthful bidding optimal.
    isHouse  = strcmpi(domain, 'houses');
    accepted = utils.ternary(isHouse, bid >= threshold, bid <= threshold);

    trial.bid          = bid;
    trial.bidRT        = bidRT;
    trial.bidStartFrac = bidStartFrac;
    trial.threshold  = threshold;
    trial.trueValue  = trueValue;
    trial.bidStimIdx = stimIdx;

    log = utils.eventLog('add', log, 'bid_outcome', GetSecs, ...
        struct('stimIdx', stimIdx, 'trial', planRow.trial, 'bid', bid, ...
               'threshold', threshold, 'accepted', double(accepted)));

    if accepted
        trial.bidAccepted = true;
        trial.pricePaid   = threshold;      % <- threshold, not bid
        trial.endReason   = 'accepted';
        feedbackFlip = showOutcome(window, cfg, true, domain, threshold, bid);
        log = utils.eventLog('add', log, 'feedback_onset', feedbackFlip, struct('phase', 'feedback'));
        break
    else
        boxStim(b) = NaN;
        now = GetSecs - t0;
        boxVacantUntil(b) = now + vacancyGap(cfg, rs);
        feedbackFlip = showOutcome(window, cfg, false, domain, threshold, bid);
        log = utils.eventLog('add', log, 'feedback_onset', feedbackFlip, struct('phase', 'feedback'));
    end
end

if ~strcmp(trial.endReason, 'accepted')
    closedFlip = showMarketClosed(window, cfg, trial.endReason);
    log = utils.eventLog('add',log,'market_closed',closedFlip,struct('phase','feedback'));
end

log = utils.eventLog('add',log,'trial_end',GetSecs,struct('trial',0));
trial.duration    = GetSecs - t0;
trial.presented   = presented;
trial.rejected    = rejected;
trial.nPresented  = numel(presented);
trial.nRejected   = numel(rejected);
trial.inspections = inspections;

end


%% ======================================================================
function [trial, log, gazeStore] = runPracticeEpisode(window, cfg, geom, L, et, ...
    log, gazeStore, stimTbl, tex, sel, A, domain, planRow, rs, win)
%RUNPRACTICEEPISODE  One saved, flagged practice market before real data.

practiceRow = planRow;
practiceRow.trial = 0;
practiceRow.practice = true;
% Practice borrows block 1's schedule but must not carry its block index.
practiceRow.block = NaN;
practiceRow.blockPos = NaN;
practiceRow.stimIdx = planRow.stimIdx(1:min(numel(planRow.stimIdx), size(L.boxRects, 2)));
practiceRow.repIdx = planRow.repIdx(1:numel(practiceRow.stimIdx));

showClickMessage(window, cfg, ['Practice round\n\nTry inspecting, rejecting, and making ' ...
    'or cancelling an offer. Nothing here counts.\n\nClick to begin.']);
[trial, log, gazeStore] = runSearchEpisode(window, cfg, geom, L, et, log, ...
    gazeStore, stimTbl, tex, sel, A, domain, practiceRow, 1, rs, win);
trial.practice = true;

end


%% ======================================================================
function L = layoutGrid(winRect, cfg)
%LAYOUTGRID  Six option tiles below the HUD, with AOI rects.
%   One preview image per tile: thumbnails ~1 deg apart are inseparable to a remote tracker.

s = cfg.style;
W = winRect(3); H = winRect(4);
hudH = s.hud.enabled * s.hud.heightPx;

nCols = 3; nRows = 2;
pad = 48;
cellW = floor(W / nCols);
cellH = floor((H - hudH) / nRows);

L.boxRects = zeros(4, nCols*nRows);
k = 0;
for r = 1:nRows
    for c = 1:nCols
        k = k + 1;
        L.boxRects(:,k) = [ (c-1)*cellW + pad; ...
                            hudH + (r-1)*cellH + pad; ...
                            c*cellW - pad; ...
                            hudH + r*cellH - pad ];
    end
end

% AOIs inside a tile: image block and text block, kept far apart.
L.aoiRects = zeros(4, 2*size(L.boxRects,2));
L.aoiNames = cell(1, 2*size(L.boxRects,2));
for k = 1:size(L.boxRects,2)
    bx = L.boxRects(:,k);
    bw = bx(3)-bx(1); bh = bx(4)-bx(2);
    L.imgRects(:,k) = [bx(1)+16; bx(2)+16; bx(3)-16; bx(2)+round(bh*0.48)];
    L.txtRects(:,k) = [bx(1)+16; bx(2)+round(bh*0.68); bx(3)-16; bx(4)-16];
    L.aoiRects(:, 2*k-1) = L.imgRects(:,k);
    L.aoiRects(:, 2*k)   = L.txtRects(:,k);
    L.aoiNames{2*k-1} = sprintf('box%d_img', k);
    L.aoiNames{2*k}   = sprintf('box%d_txt', k);
end

end


%% ======================================================================
function drawGrid(window, cfg, L, stimTbl, tex, sel, A, boxStim, domain, hud) %#ok<INUSD>
% hud is unused: no progress chrome during the response; it is shown on the fixation-start screen.
s = cfg.style;
Screen('FillRect', window, s.bg);

for b = 1:size(L.boxRects, 2)
    r = L.boxRects(:,b)';
    if isnan(boxStim(b))
        utils.roundRect(window, r, s.radiusPanel, s.bg, s.bgPanel, s.hairlinePx);
        continue
    end
    idx = boxStim(b);

    utils.roundRect(window, r, s.radiusPanel, s.bgPanel, ...
        s.interactive, s.borderWidthPx);

    % Preview image (houses only)
    if strcmpi(domain, 'houses') && isfield(tex, 'extPic') && ~isnan(tex.extPic(idx))
        Screen('DrawTexture', window, tex.extPic(idx), [], L.imgRects(:,b)');
    end

    % Preview text
    Screen('TextFont', window, s.fontContent);
    tr = L.txtRects(:,b)';
    y = tr(2) + 8;

    Screen('TextSize', window, s.sizeLabel);
    idText = utils.identityString(stimTbl, sel, idx);
    DrawFormattedText(window, idText, tr(1)+8, y+20, s.textDim, 34, 0, 0, 1.2);
    y = y + 46;

    Screen('TextSize', window, s.sizeContent);
    valText = utils.formatCurrency(stimTbl.(A.valueVar)(idx), A.priceStyle);
    DrawFormattedText(window, valText, tr(1)+8, y+22, s.money);
end

end


%% ======================================================================
function [action, gazeStore, log, onset] = showDetail(window, cfg, geom, et, log, ...
    gazeStore, stimTbl, tex, sel, A, idx, domain, hud) %#ok<INUSD>
%SHOWDETAIL  Full-width attribute panel for one option.
%   Photo grid and attribute-slot layout shared with continuous_DC_task's card.

winRect = Screen('Rect', window);
s = cfg.style;
H = winRect(4);
n = numel(sel.shown);
detailAOIs = utils.layoutDetailAOIs(winRect, cfg, sel);

action = ''; onset = NaN;
while true
    Screen('FillRect', window, s.bg);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    contentRect = utils.drawIdentityStrip(window, cfg, tex, sel, idx, detailAOIs.idRect);

    idText = utils.identityString(stimTbl, sel, idx);
    textTop = contentRect(2) + 8;
    if ~isempty(idText)
        DrawFormattedText(window, idText, 'center', textTop + 20, s.text);
        textTop = textTop + s.detailTextHeightPx;
    end

    for k = 1:n
        pr = detailAOIs.rects(:, k)';
        % pr is an AOI rect, mirrored in preflight.m; painting it rounded leaves the rect untouched.
        utils.roundRect(window, pr, s.radiusCell, s.bgPanel, ...
            s.border, s.hairlinePx);

        attr = sel.shown(k);
        Screen('TextSize', window, s.sizeLabel);
        DrawFormattedText(window, attr.label, pr(1)+12, pr(2)+24, s.textDim, ...
            floor((pr(3)-pr(1))/8), 0, 0, 1.15);

        valueY = pr(2) + 50;
        if strcmp(attr.kind, 'image')
            if isfield(tex, attr.var) && idx <= numel(tex.(attr.var)) && isfinite(tex.(attr.var)(idx))
                Screen('DrawTexture', window, tex.(attr.var)(idx), [], ...
                    [pr(1)+12, valueY, pr(3)-12, pr(4)-8]);
            end
        else
            Screen('TextSize', window, s.sizeContent);
            % Plain s.text here (matching note in continuous_DC_task.m); drawGrid's preview keeps s.money.
            col = s.text;
            DrawFormattedText(window, utils.valueString(stimTbl, attr, idx), ...
                pr(1)+12, valueY, col);
        end
    end

    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, ...
        'LEFT CLICK to make an offer     RIGHT CLICK to go back', ...
        'center', H - 60, s.textDim);

    gazeStore = utils.gazeBuffer('poll', et, gazeStore);
    if et.showGaze && ~isempty(gazeStore.latest)
        drawGazeDot(window, cfg, gazeStore.latest);
    end
    flip = Screen('Flip', window);
    if isnan(onset)
        onset = flip;
        log = utils.eventLog('add', log, 'detail_onset', onset, struct('stimIdx', idx, 'trial', hud.trial));
    end
    utils.checkForQuit;

    [~, ~, buttons] = utils.getMouse(window);
    if any(buttons)
        action = utils.ternary(buttons(1), 'bid', 'back');
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        return
    end
end

end


%% ======================================================================
function [bid, rt, startFrac, gazeStore, log] = getBid(window, cfg, geom, et, log, gazeStore, ...
    stimTbl, tex, sel, A, idx, domain, planRow, nTrials, win, rs)
%GETBID  Option card on the left, semicircular price scale on the right.
%   The option must stay on screen during the bid -- that is the measurement.
%   Layout shared with contdc's price trial; scale range comes from the sampled window, not the item.

s = cfg.style;
winRect = Screen('Rect', window);
H = winRect(4);

scaleMin = win.scaleMin;
scaleMax = win.scaleMax;

% NOTE the parameter here is `idx`, not the caller's `stimIdx`.
itemValue = stimTbl.(A.valueVar)(idx);

% Identical arithmetic to contdc's price trial.
BL = utils.layoutCardAndArc(winRect, cfg, geom, numel(sel.shown));
cx = (BL.arcLeft + BL.arcRight) / 2;
cy = BL.arcBot - 60;
outerR = min((BL.arcRight - BL.arcLeft)/2 - 30, (BL.arcBot - BL.arcTop) * 0.55);
scaleR = outerR - s.priceScale.majorTickPx;

nTicks = 5;
tickVals = linspace(scaleMin, scaleMax, nTicks);

bid = NaN; rt = NaN;

% Pointer is not forced; NaN marks "not forced" in the saved data.
startFrac = NaN;
t0 = NaN;

while true
    Screen('FillRect', window, s.bg);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    if strcmpi(domain, 'houses')
        q = 'How much would you offer for this house?';
    else
        q = 'What hourly wage would you accept for this job?';
    end
    DrawFormattedText(window, q, 'center', BL.promptY, s.text);

    % Same draw function as the contdc cards; its AOIs are computed per domain via utils.cardAOIs('bid').
    utils.drawOptionCard(window, cfg, BL.cardRect, stimTbl, tex, sel, idx);

    % Arc and ticks.
    utils.drawPriceArc(window, cx, cy, scaleR, s.track, 4);

    % Ticks and labels
    Screen('TextSize', window, s.priceScale.labelSizePx);
    for k = 1:nTicks
        ang = pi + (k-1)/(nTicks-1) * pi;
        tx1 = cx + scaleR*cos(ang);
        ty1 = cy + scaleR*sin(ang);
        tx2 = cx + outerR*cos(ang); ty2 = cy + outerR*sin(ang);
        Screen('DrawLine', window, s.textDim, tx1, ty1, tx2, ty2, s.borderWidthPx);

        lbl = utils.formatCurrency(tickVals(k), 'compact');
        lx = cx + (outerR+38)*cos(ang); ly = cy + (outerR+38)*sin(ang);
        bnd = Screen('TextBounds', window, lbl);
        DrawFormattedText(window, lbl, lx - bnd(3)/2, ly, s.textDim);
    end

    % Listed-price marker anchors bids toward it -- a real DV effect; cfg.display.showValueMarker toggles it off.
    if cfg.display.showValueMarker
        mFrac = (itemValue - scaleMin) / max(scaleMax - scaleMin, eps);
        if isfinite(mFrac) && mFrac >= 0 && mFrac <= 1
            mAng = pi + mFrac*pi;
            Screen('DrawLine', window, s.marker, ...
                cx + (scaleR-10)*cos(mAng), cy + (scaleR-10)*sin(mAng), ...
                cx + (outerR+10)*cos(mAng), cy + (outerR+10)*sin(mAng), 4);
            mLbl = utils.ternary(strcmpi(domain,'houses'), 'listed', 'offered');
            Screen('TextSize', window, s.sizeLabel);
            bnd = Screen('TextBounds', window, mLbl);
            DrawFormattedText(window, mLbl, ...
                cx + (scaleR-34)*cos(mAng) - bnd(3)/2, ...
                cy + (scaleR-34)*sin(mAng), s.marker);
        end
    end

    % Response
    [mx, my, buttons] = utils.getMouse(window);
    dx = mx - cx; dy = cy - my;
    ang = atan2(max(dy, 0), dx);
    frac = 1 - ang/pi;
    frac = min(max(frac, 0), 1);
    if ~isfinite(frac), frac = 0.5; end   % GetMouse can return NaN; never reach Screen()
    curVal = scaleMin + frac * (scaleMax - scaleMin);

    px = cx + scaleR*cos(pi + frac*pi);
    py = cy + scaleR*sin(pi + frac*pi);
    Screen('DrawDots', window, [px; py], 20, s.interactive, [], 2);

    % Snap to display resolution so the recorded bid equals what was seen.
    curVal = utils.snapValue(curVal, A.priceStyle);

    % Readout above the arc, clamped into the arc zone -- same expression as contdc.
    Screen('TextSize', window, s.sizeTitle);
    txt = utils.formatCurrency(curVal, A.priceStyle);
    bnd = Screen('TextBounds', window, txt);
    DrawFormattedText(window, txt, cx - bnd(3)/2, ...
        max(BL.arcTop - 6, cy - outerR - s.priceScale.readoutLiftPx), s.money);
    Screen('TextSize', window, s.sizeLabel);
    DrawFormattedText(window, 'LEFT CLICK to submit     RIGHT CLICK to go back', ...
        'center', H - 48, s.textDim);

    gazeStore = utils.gazeBuffer('poll', et, gazeStore);
    if et.showGaze && ~isempty(gazeStore.latest)
        drawGazeDot(window, cfg, gazeStore.latest);
    end
    flip = Screen('Flip', window);
    if isnan(t0)
        t0 = flip;
        log = utils.eventLog('add', log, 'bid_onset', t0, struct('stimIdx', idx, 'trial', planRow.trial));
    end
    utils.checkForQuit;

    if buttons(1)
        bid = curVal;
        rt = GetSecs - t0;
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        log = utils.eventLog('add', log, 'bid_response', GetSecs, ...
            struct('stimIdx', idx, 'trial', planRow.trial, 'bid', bid, 'rt', rt));
        return
    elseif buttons(3)
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        return
    end
end

end


%% ======================================================================
function onset = showOutcome(window, cfg, accepted, domain, pricePaid, bid)
s = cfg.style;
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);

isHouse = strcmpi(domain, 'houses');
style = utils.ternary(isHouse, 'total', 'hourly');

if accepted
    if isHouse
        % Second-price wording is deliberate (truthful bidding); verify_static.sh guards the old phrasing out.
        msg = sprintf(['You won the house.\n\n' ...
            'You offered %s.\nThe next best offer was %s, so that is what you pay.'], ...
            utils.formatCurrency(bid, style), utils.formatCurrency(pricePaid, style));
    else
        msg = sprintf(['Your offer was accepted.\n\n' ...
            'You asked for %s.\nYou are paid the market rate of %s.'], ...
            utils.formatCurrency(bid, style), utils.formatCurrency(pricePaid, style));
    end
    col = s.accepted;
    tag = 'ACCEPTED';
else
    if isHouse
        msg = 'Your offer was too low. The house sold to someone else.';
    else
        msg = 'Your salary requirement was too high. The offer was withdrawn.';
    end
    col = s.rejected;
    tag = 'REJECTED';
end

% Colour is never the only carrier -- there is always a word too.
Screen('TextFont', window, s.fontChrome);
Screen('TextSize', window, s.sizeTitle);
DrawFormattedText(window, tag, 'center', 260, col);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);
DrawFormattedText(window, msg, 'center', 'center', s.text, 55, 0, 0, 1.6);
onset = Screen('Flip', window);
WaitSecs(cfg.auction.feedbackSec);

end


%% ======================================================================
function showInstructions(window, cfg, domain)
s = cfg.style;
txt = utils.incentives('instructions', domain, cfg.incentives);
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeContent);
DrawFormattedText(window, [txt quitNotice()], ...
    'center', 'center', s.text, 62, 0, 0, 1.6);
Screen('Flip', window);
utils.waitForClick(window);
end


%% ======================================================================
function result = runComprehensionChecks(window, cfg, domain)
%RUNCOMPREHENSIONCHECKS  Confirm the auction mouse controls before practice.

isHouse = strcmpi(domain, 'houses');
item = utils.ternary(isHouse, 'option', 'opening');

checks(1).question = sprintf('How do you reject an %s from the market?', item);
checks(1).choices = {'Left-click it', 'Right-click it'};
checks(1).correct = 2;

checks(2).question = 'How do you leave the offer screen without submitting?';
checks(2).choices = {'Right-click to go back', 'Wait for the next listing'};
checks(2).correct = 1;

responses = cell(1, numel(checks));
attempts = zeros(1, numel(checks));
for k = 1:numel(checks)
    while true
        attempts(k) = attempts(k) + 1;
        choice = askComprehension(window, cfg, checks(k).question, checks(k).choices);
        responses{k} = checks(k).choices{choice};
        if choice == checks(k).correct
            break
        end
        showMessage(window, cfg, 'Not quite. Please try that one again.', 1.2);
    end
end

result = struct('shown', true, 'passed', true, ...
    'responses', {responses}, 'attempts', attempts);
showMessage(window, cfg, 'Good. Next is one practice round.', 1.2);

end


%% ======================================================================
function choice = askComprehension(window, cfg, question, choices)
% Owns its cursor: elicitation may leave it hidden.
ShowCursor('Arrow', window);
s = cfg.style;
scr = Screen('Rect', window);
W = scr(3); H = scr(4);
boxW = min(520, W * 0.34);
boxH = 110;
gap = 60;
top = H * 0.56;
left1 = W/2 - boxW - gap/2;
left2 = W/2 + gap/2;
rects = [left1 left2; top top; left1+boxW left2+boxW; top+boxH top+boxH];

choice = NaN;
while isnan(choice)
    Screen('FillRect', window, s.bg);
    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    DrawFormattedText(window, question, 'center', H * 0.32, s.text, 60, 0, 0, 1.5);

    for k = 1:2
        r = rects(:, k)';
        utils.roundRect(window, r, s.radiusPanel, s.bgPanel, ...
            s.interactive, s.borderWidthPx);
        Screen('TextSize', window, s.sizeContent);
        DrawFormattedText(window, choices{k}, 'center', r(2) + 62, s.text, 45, 0, 0, 1.2, [], r);
    end

    Screen('Flip', window);
    utils.checkForQuit;

    [mx, my, buttons] = utils.getMouse(window);
    if any(buttons)
        for k = 1:2
            r = rects(:, k);
            if mx >= r(1) && mx <= r(3) && my >= r(2) && my <= r(4)
                choice = k;
            end
        end
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
    end
end

end


%% ======================================================================
function showPayout(window, cfg, payout)
s = cfg.style;
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);
DrawFormattedText(window, payout.explanation, 'center', 'center', s.text, 55, 0, 0, 1.7);
Screen('Flip', window);
utils.waitForClick(window);
end


%% ======================================================================
function onset = showMessage(window, cfg, msg, secs)
s = cfg.style;
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);
DrawFormattedText(window, msg, 'center', 'center', s.text, 55, 0, 0, 1.6);
onset = Screen('Flip', window);
WaitSecs(secs);
end


%% ======================================================================
function showClickMessage(window, cfg, msg)
s = cfg.style;
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);
DrawFormattedText(window, msg, 'center', 'center', s.text, 55, 0, 0, 1.6);
Screen('Flip', window);
utils.waitForClick(window);
end


%% ======================================================================
function [store, onset] = showBreakMessage(window, cfg, msg, et, store)
%SHOWBREAKMESSAGE showClickMessage that keeps draining the tracker.
% Same wait as utils.waitForClick, with a gazeBuffer poll in the loop. Used
% for waits that happen while a block recording is live and may last minutes.
s = cfg.style;
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);
DrawFormattedText(window, msg, 'center', 'center', s.text, 55, 0, 0, 1.6);
onset = Screen('Flip', window);

buttons = false(1,3);
while ~any(buttons)
    [~, ~, buttons] = utils.getMouse(window);
    store = utils.gazeBuffer('poll', et, store);
    utils.checkForQuit;
    WaitSecs(0.01);
end
while any(buttons)
    [~, ~, buttons] = utils.getMouse(window);
end
store = utils.gazeBuffer('poll', et, store);
end


%% ======================================================================
function onset = showMarketClosed(window, cfg, reason)
if strcmp(reason, 'timeout')
    msg = 'The market has closed.';
else
    msg = 'There are no more options in this market.';
end
onset = showMessage(window, cfg, msg, 1.4);
end


%% ======================================================================
function drawGazeDot(window, cfg, sample)
%DRAWGAZEDOT  Media-mode only. Never during data collection.
[x, y] = utils.gazeToPixels(sample, window);
if ~isnan(x) && ~isnan(y)
    Screen('DrawDots', window, [x; y], 26, [255 80 80 180]/255, [], 2);
end
end


%% ======================================================================
function b = boxAtPoint(rects, x, y)
b = NaN;
for k = 1:size(rects, 2)
    r = rects(:,k);
    if x >= r(1) && x <= r(3) && y >= r(2) && y <= r(4)
        b = k; return
    end
end
end


%% ======================================================================
function [plan, nStruck] = retireStimulus(plan, afterTrial, stimIdx, minOptions)
%RETIRESTIMULUS  Remove a won item from every trial that has not run yet.
%   Trials that would drop below minOptions keep the item; repIdx is never renumbered (records exposures to date).

nStruck = 0;
for k = (afterTrial + 1):numel(plan)
    keep = plan(k).stimIdx ~= stimIdx;
    if all(keep), continue; end
    if sum(keep) < minOptions, continue; end
    plan(k).stimIdx = plan(k).stimIdx(keep);
    plan(k).repIdx  = plan(k).repIdx(keep);
    nStruck = nStruck + 1;
end

end


%% ======================================================================
function gap = vacancyGap(cfg, rs)
%VACANCYGAP  Seconds a freed box stays empty before it may refill.
%   Gamma with a hard cap so a slot never sits empty long enough to read as a stall.
gap = utils.gammaSample(cfg.auction.vacancyShape, ...
    cfg.auction.vacancyGapMean/cfg.auction.vacancyShape, 1, rs);
gap = min(gap, cfg.auction.vacancyGapMax);
end


%% ======================================================================
function list = struct2texlist(tex)
list = [];
if isempty(fieldnames(tex)), return; end
f = fieldnames(tex);
for k = 1:numel(f)
    v = tex.(f{k});
    list = [list; v(~isnan(v))]; %#ok<AGROW>
end
end


%% ======================================================================
function T = buildTrialTable(dataMat)
tables = {};
for d = 1:numel(dataMat.domains)
    dom = dataMat.domains{d};
    if ~isfield(dataMat,dom) || ~isfield(dataMat.(dom),'trials'), continue; end
    tables{end+1} = utils.auctionTrialTable(dom,dataMat.(dom).trials,dataMat.(dom).anchor); %#ok<AGROW>
end
T = utils.stackTables(tables);
end


%% ======================================================================
function s = quitNotice()
%QUITNOTICE  Footer for every instruction screen.
s = ['\n\n\nYou can stop at any time: press the Q key and the session ' ...
     'will end.\n\n\nClick to continue.'];
end
