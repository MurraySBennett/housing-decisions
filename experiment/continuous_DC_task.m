function dataMat = continuous_DC_task(sess, run)
%CONTINUOUS_DC_TASK  Pricing versus discrete choice, crossed with attribute count.
%
%   dataMat = continuous_DC_task(sess, run)

if nargin < 1 || isempty(sess)
    sess = utils.startSession();
end
if nargin < 2 || isempty(run)
    run = utils.beginRun(sess, 'contdc');
    standalone = true;
else
    standalone = false;
end

% Domains belong to the run, not the session (see utils.beginRun).
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
% Theme recorded so a rolled-back session can be stratified later.
dataMat.theme   = cfg.style.themeName;
% [] on a full run; integer on a rehearsal, filterable in analysis.
dataMat.trialsPerCell = cfg.rehearsal.trialsPerCell;
window = [];
et = struct('enabled', false, 'obj', [], 'showGaze', false, 'analyzable', false);

utils.progressLog(run, 'TASK ENTER');
try
    % =============================================== display
    % Defensive: a prior crashed run can leave PsychImaging config state dirty.
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

    % Fonts can only be probed here; sole mutation of cfg.style after utils.config.
    cfg.style = utils.resolveFonts(window, cfg.style);
    utils.trace('fonts: content=%s chrome=%s', ...
        cfg.style.fontContent, cfg.style.fontChrome);

    Priority(MaxPriority(window));
    ShowCursor('Arrow', window);
    ListenChar(2);

    geom = cfg.geom;
    geom.widthPx = winRect(3); geom.heightPx = winRect(4);

    utils.trace('setting up eye tracker (enabled=%d)', cfg.et.enabled);
    et = utils.setupEyeTracker(cfg, window, ~cfg.testing.enabled);
    utils.trace('eye tracker setup done (connected=%d)', et.enabled);
    dataMat.eyeTracking = struct('enabled', et.enabled, ...
        'analyzable', et.analyzable, 'positioned', et.positioned, ...
        'mediaMode', et.showGaze, ...
        'requestedSampleRateHz', et.requestedSampleRateHz, ...
        'actualSampleRateHz', et.actualSampleRateHz, ...
        'setupFailureStage', et.setupFailureStage, ...
        'setupFailureMessage', et.setupFailureMessage, ...
        'operatorChoice', et.operatorChoice);

    % =============================================== per domain
    for d = 1:numel(domainList)
        domain = domainList{d};
        fprintf('\n===== %s (continuous/DC) =====\n', upper(domain));

        utils.trace('domain %s: loading stimuli', domain);
        A = utils.attributes(domain);
        frozen = utils.runCheckpoint('peek', sess, run, domain);
        if isempty(frozen)
        stimuli = utils.readStimuli(cfg, domain);
        utils.trace('domain %s: %d stimuli loaded', domain, height(stimuli));

        % ---- elicitation ---------------------------------------------
        % Cached per session; a new session number deliberately re-elicits.
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

        % ---- stimulus window ------------------------------------------
        [inWindow, win] = utils.applyWindow(stimuli, A, anchor, cfg);
        fprintf('Window %s to %s: %d stimuli (%s).\n', ...
            utils.formatCurrency(win.lo, A.priceStyle), ...
            utils.formatCurrency(win.hi, A.priceStyle), win.n, win.mode);

        % ---- block schedule -------------------------------------------
        levels = cfg.attrLevels;
        if ~isempty(cfg.testing.forceAttrLevel)
            levels = cfg.testing.forceAttrLevel;
        end
        blocks = buildBlocks(levels, sess.participant, rs);

        % Pairs built eagerly so every stimulus ever shown is known before image loading.
        nPairsThisRun = cfg.contdc.nPairs.(lower(domain));
        if ~isempty(cfg.rehearsal.trialsPerCell)
            % Cells are level x task type; nPairs is per level, so this maps directly.
            nPairsThisRun = cfg.rehearsal.trialsPerCell;
        end
        if cfg.testing.enabled
            nPairsThisRun = cfg.testing.nTrialsPerType;
        end
        pairsByLevel = struct();
        selByLevel = struct();
        neededIdx = [];
        usedAcrossLevels = [];   % grows as each level claims its stimuli
        for lvl = unique(levels)
            key = sprintf('lvl%d', lvl);
            selByLevel.(key) = utils.selectAttributes(A, lvl, poolRatings, ...
                cfg.attrMethod, lvl == max(levels) && cfg.lateAtMaxOnly);

            % Cross-level reuse allowed by default; within-level reuse is required by the paradigm.
            if cfg.contdc.allowCrossLevelReuse
                exclude = [];
            else
                exclude = usedAcrossLevels;
            end

            [pairsByLevel.(key), claimed] = utils.buildPairs(inWindow, ...
                selByLevel.(key), A, nPairsThisRun, rs, exclude);
            if numel(pairsByLevel.(key)) < nPairsThisRun
                % Report the stimulus budget and the settings AS THEY ARE, not a
                % generic list of knobs. The old text advised "allow cross-level
                % reuse" unconditionally -- but it defaults to true, so an
                % operator reading it at the rig was told to enable something
                % already enabled, and the real cause (too few stimuli reaching
                % buildPairs) went unnamed.
                error('hw:contdc:shortPairs', ...
                    ['Attribute level %d produced only %d/%d pairs for %s.\n' ...
                     'Only %d stimuli reached pairing, and each may be used twice, ' ...
                     'so about %d pairs is the ceiling.\n' ...
                     'Current settings: nPairs=%d, spread=[%.2f %.2f], ' ...
                     'crossLevelReuse=%d, fitToWindow.%s=%d%s.\n' ...
                     'Do not run imbalanced cells.'], ...
                    lvl, numel(pairsByLevel.(key)), nPairsThisRun, domain, ...
                    ... % height, NOT numel: inWindow is a table, so numel gives
                    ... % rows*columns. Getting this wrong would have printed a
                    ... % nonsense count while reporting a different failure.
                    height(inWindow), height(inWindow), ...
                    nPairsThisRun, cfg.sampling.spread(1), cfg.sampling.spread(2), ...
                    cfg.contdc.allowCrossLevelReuse, domain, ...
                    cfg.sampling.fitToWindow.(domain), ...
                    utils.ternary(strcmpi(domain, 'jobs'), ...
                        sprintf(', nTopIndustries=%d', cfg.sampling.nTopIndustries), ''));
            end
            usedAcrossLevels = unique([usedAcrossLevels, claimed]);

            for pk = 1:numel(pairsByLevel.(key))
                neededIdx(end+1) = pairsByLevel.(key)(pk).moneyIdx;   %#ok<AGROW>
                neededIdx(end+1) = pairsByLevel.(key)(pk).qualityIdx; %#ok<AGROW>
            end
        end

        utils.trace('domain %s: %d distinct stimuli claimed across %d levels (reuse %s)', ...
            domain, numel(usedAcrossLevels), numel(unique(levels)), ...
            utils.ternary(cfg.contdc.allowCrossLevelReuse, 'allowed', 'blocked'));
        frozen = struct();
        frozen.anchor = anchor;
        frozen.anchorRT = anchorRT;
        frozen.poolRatings = poolRatings;
        frozen.attrRTs = attrRTs;
        frozen.coreRatings = coreRatings;
        frozen.coreRTs = coreRTs;
        frozen.industryRatings = industryRatings;
        frozen.inWindow = inWindow;
        frozen.win = win;
        frozen.levels = levels;
        frozen.blocks = blocks;
        frozen.pairsByLevel = pairsByLevel;
        frozen.selByLevel = selByLevel;
        frozen.neededIdx = neededIdx;
        frozen.blockCount = numel(blocks);
        frozen.rsState = rs.State; frozen.globalState = rng; frozen.screenRect = winRect;
        utils.runCheckpoint('freeze', sess, run, domain, frozen);
        else
            anchor = frozen.anchor;
            anchorRT = frozen.anchorRT;
            poolRatings = frozen.poolRatings;
            attrRTs = frozen.attrRTs;
            coreRatings = frozen.coreRatings;
            coreRTs = frozen.coreRTs;
            industryRatings = frozen.industryRatings;
            inWindow = frozen.inWindow;
            win = frozen.win;
            levels = frozen.levels;
            blocks = frozen.blocks;
            pairsByLevel = frozen.pairsByLevel;
            selByLevel = frozen.selByLevel;
            neededIdx = frozen.neededIdx;
        end
        assert(isequal(winRect, frozen.screenRect), 'hw:contdc:displayChanged', 'Display geometry changed on resume.');
        rs.State = frozen.rsState; rng(frozen.globalState);
        aoiLayouts = buildAoiLayouts(winRect, cfg, geom, selByLevel, levels);

        tl = utils.timeline('section', tl, sprintf('%s:instructions', domain));
        if ~(cfg.testing.enabled && cfg.testing.skipInstructions)
            showInstructions(window, cfg, domain);
        end

        % Images loaded once per domain, only for stimuli that will appear.
        utils.trace('domain %s: loading images for %d stimuli (of %d sampled)', ...
            domain, numel(unique(neededIdx)), win.n);
        tex = utils.loadStimulusTextures(window, cfg, inWindow, A, neededIdx, true);

        recovery = utils.taskBlock('recover', sess, run, domain);
        trials = recovery.trials;
        domainEvents = recovery.events;
        parentAttempt = recovery.parentAttemptId;
        if ~isempty(recovery.entryState)
            rs.State = recovery.entryState.rsState; rng(recovery.entryState.globalState);
        end
        tl = utils.timeline('section', tl, sprintf('%s:trials', domain));
        for b = recovery.nextBlock:numel(blocks)
            firstTrial = numel(trials) + 1;
            log = utils.eventLog('init', 20000);
            lvl  = blocks(b).attrLevel;
            task = blocks(b).taskType;

            key = sprintf('lvl%d', lvl);
            sel = selByLevel.(key);
            pairs = pairsByLevel.(key);

            utils.trace('block %d/%d: %s, level %d', b, numel(blocks), task, lvl);
            showBlockIntro(window, cfg, task, lvl, b, numel(blocks));

            entryState = struct('rsState', rs.State, 'globalState', rng);
            attempt = utils.taskBlock('begin', sess, run, domain, b, entryState, parentAttempt);
            log = utils.eventLog('context', log, struct('block', b, 'attemptId', attempt.attemptId));
            recording = utils.blockRecording('start', et);
            gazeStore = recording.store; clockSync = recording.clockSync;
            order = randperm(rs, numel(pairs));

            % Drift check runs INSIDE this block's recording, mirroring
            % auction_task.m:339. It used to run above the block with no
            % gazeStore, which took driftCheck's ownsRecording branch: that
            % opens a separate recording, and gazeBuffer('flush') then
            % discarded every drift sample and stopped the stream, while the
            % drift/calibration markers were dropped entirely so
            % alignBlockGaze had no boundary for the epoch.
            % Placed after randperm on purpose: whether the check runs must
            % not change RNG consumption, or trial order would diverge on a
            % resume of this block.
            if cfg.et.driftCheck && mod(b, cfg.contdc.driftEvery) == 1 && b > 1
                [off, recal, gazeStore, driftMarkers] = utils.driftCheck(et, window, cfg, ...
                    [winRect(3)/2, winRect(4)/2], gazeStore);
                for markerIdx = 1:numel(driftMarkers)
                    marker = driftMarkers(markerIdx);
                    log = utils.eventLog('add', log, marker.event, marker.flipTime, ...
                        struct('trial', 0, 'phase', marker.phase));
                end
                log = utils.eventLog('add', log, 'drift_check', GetSecs, ...
                    struct('offsetDeg', off, 'recalibrated', double(recal)));
            end

            % Price blocks run two trials per pair, so totals differ by task type.
            if strcmp(task, 'choice')
                nTrialsInBlock = numel(order);
            else
                nTrialsInBlock = numel(order) * 2;
            end
            trialInBlock = 0;

            for pi = 1:numel(order)
                p = pairs(order(pi));

                if strcmp(task, 'choice')
                    trialInBlock = trialInBlock + 1;
                    log = utils.eventLog('context', log, struct('trial', trialInBlock));
                    [tr, log, gazeStore] = runChoiceTrial(window, cfg, geom, et, ...
                        log, gazeStore, inWindow, tex, sel, A, p, domain, ...
                        struct('block', b, 'nBlocks', numel(blocks), 'level', lvl, ...
                               'trialInBlock', trialInBlock, 'nTrialsInBlock', nTrialsInBlock));
                    tr.pairIdx = order(pi);
                    if isempty(trials), trials = tr; else, trials(end+1) = tr; end %#ok<AGROW>
                    utils.progressLog(run, ['TRIAL block=%d/%d type=choice level=%d ' ...
                        'trial=%d/%d choseMoney=%d rt=%.3f timedOut=%d'], ...
                        b, numel(blocks), lvl, trialInBlock, nTrialsInBlock, ...
                        tr.choseMoney, tr.rt, tr.timedOut);
                else
                    items = [p.moneyIdx, p.qualityIdx];
                    isMoney = [true, false];
                    o2 = randperm(rs, 2);
                    for q = o2
                        trialInBlock = trialInBlock + 1;
                        log = utils.eventLog('context', log, struct('trial', trialInBlock));
                        [tr, log, gazeStore] = runPriceTrial(window, cfg, geom, et, ...
                            log, gazeStore, inWindow, tex, sel, A, items(q), ...
                            isMoney(q), win, domain, rs, ...
                            struct('block', b, 'nBlocks', numel(blocks), 'level', lvl, ...
                                   'trialInBlock', trialInBlock, 'nTrialsInBlock', nTrialsInBlock));
                        tr.pairIdx = order(pi);
                        if isempty(trials), trials = tr; else, trials(end+1) = tr; end %#ok<AGROW>
                        utils.progressLog(run, ['TRIAL block=%d/%d type=price level=%d ' ...
                            'trial=%d/%d isMoneyOption=%d price=%.2f rt=%.3f timedOut=%d'], ...
                            b, numel(blocks), lvl, trialInBlock, nTrialsInBlock, ...
                            isMoney(q), tr.price, tr.rt, tr.timedOut);
                    end
                end
                utils.checkForQuit;
            end
            log = utils.eventLog('add', log, 'recording_stop', GetSecs, struct('trial', 0));
            blockTrials = trials(firstTrial:end);
            blockData = struct(); blockData.domains = {domain}; blockData.(domain).trials = blockTrials;
            payload = struct(); payload.trials = blockTrials;
            payload.trialTable = buildTrialTable(blockData);
            payload.trialTable.trial = (1:numel(blockTrials))';
            payload.events = utils.eventLog('table', log);
            payload.metadata = struct('frozenPlan', frozen, 'aoiLayouts', aoiLayouts, ...
                'eyeTracking', dataMat.eyeTracking, 'attributes', A);
            payload.clockSync = clockSync;
            payload.nextState = struct('rsState', rs.State, 'globalState', rng);
            utils.savingScreen(window, cfg, 0.1, 'Saving completed block', utils.didYouKnow(run.seed));
            receipt = utils.taskBlock('finish', sess, run, domain, attempt, payload, et, gazeStore);
            parentAttempt = receipt.attemptId;
            domainEvents{end+1} = payload.events;
            clear gazeStore recording payload blockData blockTrials;
        end

        utils.progressLog(run, 'TRIALS FINISHED domain=%s; BEGIN releasing textures', domain);
        Screen('Close', struct2texlist(tex));
        utils.progressLog(run, 'END releasing textures; BEGIN result assembly');

        % ---- store -----------------------------------------------------
        dataMat.(domain).anchor        = anchor;
        dataMat.(domain).anchorRT      = anchorRT;
        dataMat.(domain).poolRatings   = poolRatings;
        dataMat.(domain).poolRatingRTs = attrRTs;
        dataMat.(domain).poolLabels    = {A.pool.label};
        dataMat.(domain).coreRatings   = coreRatings;
        dataMat.(domain).coreRatingRTs = coreRTs;
        dataMat.(domain).coreLabels    = {A.core.label};
        dataMat.(domain).industryRatings = industryRatings;
        dataMat.(domain).window        = win;
        dataMat.(domain).stimuliShown  = inWindow;
        dataMat.(domain).blocks        = blocks;
        dataMat.(domain).pairs         = pairsByLevel;
        dataMat.(domain).trials        = trials;
        dataMat.(domain).events        = utils.stackTables(domainEvents);
        dataMat.(domain).reversals     = utils.scoreReversals(trials);
        dataMat.(domain).aoiLayouts    = aoiLayouts;

        dataMat.(domain).checkpointRun = [run.runId '_' domain];

    end

    utils.progressLog(run, 'BEGIN end-of-task message');
    showMessage(window, cfg, 'Thank you. That is the end of this task.', 2.5);
    utils.progressLog(run, 'END end-of-task message');

    savingFact = utils.didYouKnow(run.seed);
    utils.savingScreen(window, cfg, 0.75, 'Writing trial data', savingFact);
    tl = utils.timeline('stop', tl);
    dataMat.timing = utils.timeline('table', tl);
    utils.progressLog(run, 'BEGIN trial table construction');
    trialTable = buildTrialTable(dataMat);
    utils.progressLog(run, 'END trial table construction rows=%d', height(trialTable));
    try
        utils.saveRun(sess, run, dataMat, trialTable);
    catch aggregateError
        utils.progressLog(run, 'Optional task summary failed: %s', aggregateError.message);
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
    % sca does not reset PsychImaging's persistent config state; both are needed or the next OpenWindow in this MATLAB session fails or returns a bad handle.
    sca;
    clear PsychImaging;
    % Best-effort and separately guarded, matching preference_task. These were
    % bare, so a failure writing the dump or updating the manifest propagated
    % INSTEAD of ME: the battery above then caught the bookkeeping error and the
    % real reason the session died was gone. rethrow(ME) must always be what
    % leaves this block.
    try
        crashFile = fullfile(cfg.paths.crashed, sprintf('%s_%s_crash.mat', run.runId, utils.checkpointIO('id')));
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
function blocks = buildBlocks(levels, participant, rs)
%BUILDBLOCKS  Task type blocked and counterbalanced; level order randomised.

if mod(participant, 2) == 0
    taskOrder = {'choice', 'price'};
else
    taskOrder = {'price', 'choice'};
end

blocks = struct('taskType', {}, 'attrLevel', {});
for t = 1:numel(taskOrder)
    lv = levels(randperm(rs, numel(levels)));
    for k = 1:numel(lv)
        blocks(end+1) = struct('taskType', taskOrder{t}, 'attrLevel', lv(k)); %#ok<AGROW>
    end
end

end


%% ======================================================================
function [tr, log, gazeStore] = runChoiceTrial(window, cfg, geom, et, log, ...
    gazeStore, stimTbl, tex, sel, A, pair, domain, blockInfo)
%RUNCHOICETRIAL  Two options side by side; pick one.

s = cfg.style;
winRect = Screen('Rect', window);

if pair.moneyOnLeft
    leftIdx = pair.moneyIdx;  rightIdx = pair.qualityIdx;
else
    leftIdx = pair.qualityIdx; rightIdx = pair.moneyIdx;
end

L = layoutTwoCards(winRect, cfg, geom, numel(sel.shown));

tr = blankTrial(domain, blockInfo);
tr.taskType   = 'choice';
tr.leftIdx    = leftIdx;
tr.rightIdx   = rightIdx;
tr.moneyIdx   = pair.moneyIdx;
tr.qualityIdx = pair.qualityIdx;
tr.contrast   = pair.contrast;

% Fixation click permits presentation; the first stimulus flip defines t0.
[t0, log] = utils.awaitFixationStart(window, cfg, log, struct( ...
    'trial', blockInfo.trialInBlock, 'nTrials', blockInfo.nTrialsInBlock, ...
    'label', sprintf('%s - choose - %d attributes', domain, blockInfo.level)));
t0 = NaN;

while true
    % No HUD on the response screen by design.
    Screen('FillRect', window, s.bg);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    DrawFormattedText(window, 'Which would you prefer?', 'center', ...
        L.promptY, s.text);

    utils.drawOptionCard(window, cfg, L.cardRects(:,1), stimTbl, tex, sel, leftIdx);
    utils.drawOptionCard(window, cfg, L.cardRects(:,2), stimTbl, tex, sel, rightIdx);

    gazeStore = utils.gazeBuffer('poll', et, gazeStore);
    if et.showGaze && ~isempty(gazeStore.latest)
        drawGazeDot(window, cfg, gazeStore.latest);
    end
    vbl = Screen('Flip', window);
    if isnan(t0)
        t0 = vbl;
        log = utils.eventLog('add', log, 'choice_onset', vbl, ...
            struct('leftIdx', leftIdx, 'rightIdx', rightIdx, 'level', blockInfo.level));
    end
    utils.checkForQuit;

    [mx, my, buttons] = utils.getMouse(window);
    if any(buttons)
        side = NaN;
        for k = 1:2
            r = L.cardRects(:,k);
            if mx >= r(1) && mx <= r(3) && my >= r(2) && my <= r(4), side = k; end
        end
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        if ~isnan(side)
            tr.rt = GetSecs - t0;
            tr.chosenSide = side;
            tr.chosenIdx  = utils.ternary(side == 1, leftIdx, rightIdx);
            tr.choseMoney = (tr.chosenIdx == pair.moneyIdx);
            break
        end
    end

    if GetSecs - t0 > cfg.contdc.choiceTimeoutSec
        tr.rt = NaN; tr.timedOut = true;
        break
    end
end
HideCursor(window);

log = utils.eventLog('add', log, 'choice_response', GetSecs, ...
    struct('chosenIdx', tr.chosenIdx, 'choseMoney', double(tr.choseMoney), 'rt', tr.rt));

itiOnset = interTrial(window, cfg);
log = utils.eventLog('add', log, 'intertrial_onset', itiOnset, struct('trial', 0));

end


%% ======================================================================
function [tr, log, gazeStore] = runPriceTrial(window, cfg, geom, et, log, ...
    gazeStore, stimTbl, tex, sel, A, idx, isMoneyOption, win, domain, rs, blockInfo)
%RUNPRICETRIAL  One option, priced on the continuous scale.
%   Card stays on screen throughout; blanking it turns pricing into a memory task.

s = cfg.style;
winRect = Screen('Rect', window);
L = utils.layoutCardAndArc(winRect, cfg, geom, numel(sel.shown));

tr = blankTrial(domain, blockInfo);
tr.taskType     = 'price';
tr.itemIdx      = idx;
tr.isMoneyOption = isMoneyOption;
tr.postedValue  = stimTbl.(A.valueVar)(idx);

if strcmpi(domain, 'houses')
    q = 'What is the most you would pay for this house?';
else
    q = 'What is the lowest hourly wage you would accept for this job?';
end

scaleMin = win.scaleMin;
scaleMax = win.scaleMax;

cx = (L.arcLeft + L.arcRight) / 2;
cy = L.arcBot - 60;
outerR = min((L.arcRight - L.arcLeft)/2 - 30, (L.arcBot - L.arcTop) * 0.55);
scaleR = outerR - s.priceScale.majorTickPx;
% Five, not seven -- see the matching note in auction_task.m.
nTicks = 5;
tickVals = linspace(scaleMin, scaleMax, nTicks);

itemValue = stimTbl.(A.valueVar)(idx);

% Fixation click permits presentation; the first stimulus flip defines t0.
[t0, log] = utils.awaitFixationStart(window, cfg, log, struct( ...
    'trial', blockInfo.trialInBlock, 'nTrials', blockInfo.nTrialsInBlock, ...
    'label', sprintf('%s - price - %d attributes', domain, blockInfo.level)));
t0 = NaN;

% NaN startFrac marks "not forced" in the saved data.
tr.startFrac = NaN;
while true
    Screen('FillRect', window, s.bg);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    DrawFormattedText(window, q, 'center', L.promptY, s.text);

    utils.drawOptionCard(window, cfg, L.cardRect, stimTbl, tex, sel, idx);

    % s.track, not s.border -- see the matching note in auction_task.m.
    utils.drawPriceArc(window, cx, cy, scaleR, s.track, 4);

    Screen('TextSize', window, s.priceScale.labelSizePx);
    for k = 1:nTicks
        ang = pi + (k-1)/(nTicks-1)*pi;
        Screen('DrawLine', window, s.textDim, ...
            cx+scaleR*cos(ang), ...
            cy+scaleR*sin(ang), ...
            cx+outerR*cos(ang), cy+outerR*sin(ang), s.borderWidthPx);
        lbl = utils.formatCurrency(tickVals(k), 'compact');
        bnd = Screen('TextBounds', window, lbl);
        DrawFormattedText(window, lbl, cx+(outerR+38)*cos(ang)-bnd(3)/2, ...
            cy+(outerR+38)*sin(ang), s.textDim);
    end

    % Advertised-figure marker; anchoring note at the matching block in auction_task.m.
    if cfg.display.showValueMarker
        mFrac = (itemValue - scaleMin) / max(scaleMax - scaleMin, eps);
        if isfinite(mFrac) && mFrac >= 0 && mFrac <= 1
            mAng = pi + mFrac*pi;
            Screen('DrawLine', window, s.marker, ...
                cx + (scaleR-10)*cos(mAng), cy + (scaleR-10)*sin(mAng), ...
                cx + (outerR+10)*cos(mAng), cy + (outerR+10)*sin(mAng), 4);
            mLbl = utils.ternary(strcmpi(domain,'houses'), 'listed', 'offered');
            bnd = Screen('TextBounds', window, mLbl);
            DrawFormattedText(window, mLbl, ...
                cx + (scaleR-32)*cos(mAng) - bnd(3)/2, ...
                cy + (scaleR-32)*sin(mAng), s.marker);
        end
    end

    [mx, my, buttons] = utils.getMouse(window);
    ang = atan2(max(cy - my, 0), mx - cx);
    frac = min(max(1 - ang/pi, 0), 1);
    if ~isfinite(frac), frac = 0.5; end   % defensive: bad read must not reach Screen()
    curVal = scaleMin + frac*(scaleMax - scaleMin);

    px = cx + scaleR*cos(pi + frac*pi);
    py = cy + scaleR*sin(pi + frac*pi);
    Screen('DrawDots', window, [px; py], 18, s.interactive, [], 2);

    curVal = utils.snapValue(curVal, A.priceStyle);

    % Above the arc rather than inside its bowl, matching auction_task.
    Screen('TextSize', window, s.sizeTitle);
    txt = utils.formatCurrency(curVal, A.priceStyle);
    bnd = Screen('TextBounds', window, txt);
    DrawFormattedText(window, txt, cx - bnd(3)/2, ...
        max(L.arcTop - 6, cy - outerR - s.priceScale.readoutLiftPx), s.money);

    gazeStore = utils.gazeBuffer('poll', et, gazeStore);
    if et.showGaze && ~isempty(gazeStore.latest)
        drawGazeDot(window, cfg, gazeStore.latest);
    end
    vbl = Screen('Flip', window);
    if isnan(t0)
        t0 = vbl;
        log = utils.eventLog('add', log, 'price_onset', vbl, ...
            struct('itemIdx', idx, 'level', blockInfo.level, 'isMoneyOption', double(isMoneyOption)));
    end
    utils.checkForQuit;

    if buttons(1)
        tr.price = curVal;
        tr.rt = GetSecs - t0;
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        break
    end
    if GetSecs - t0 > cfg.contdc.priceTimeoutSec
        tr.timedOut = true;
        break
    end
end

log = utils.eventLog('add', log, 'price_response', GetSecs, ...
    struct('itemIdx', idx, 'price', tr.price, 'rt', tr.rt));

itiOnset = interTrial(window, cfg);
log = utils.eventLog('add', log, 'intertrial_onset', itiOnset, struct('trial', 0));

end


%% ======================================================================
function L = layoutTwoCards(winRect, cfg, geom, nAttrs)
s = cfg.style;
W = winRect(3); H = winRect(4);
hudH = s.hud.enabled * s.hud.heightPx;

L.promptY = hudH + 46;
top = hudH + 96;
bot = H - 50;
gap = geom.targetSepPx;
marg = 70;
cardW = floor((W - 2*marg - gap) / 2);

L.cardRects = [ marg,            marg + cardW + gap; ...
                top,             top; ...
                marg + cardW,    W - marg; ...
                bot,             bot ];
L.nCols = 1;
L.nAttrs = nAttrs;
end


%% ======================================================================
function layouts = buildAoiLayouts(winRect, cfg, geom, selByLevel, levels)
layouts = struct();
for lvl = unique(levels)
    key = sprintf('lvl%d', lvl);
    sel = selByLevel.(key);

    choiceL = layoutTwoCards(winRect, cfg, geom, numel(sel.shown));
    left = utils.cardAOIs(cfg, choiceL.cardRects(:,1), sel, 'choice_left');
    right = utils.cardAOIs(cfg, choiceL.cardRects(:,2), sel, 'choice_right');
    choice.rects = [left.rects, right.rects];
    choice.names = [left.names, right.names];
    [choice.ok, choice.report] = utils.checkAOIs(choice.rects, choice.names, geom, true);
    if ~choice.ok && strcmp(cfg.aoiEnforcement, 'strict')
        warning('hw:contdc:choiceAoiTooClose', ...
            'Some choice-card AOIs are below the minimum separation -- see report above.');
    end

    priceL = utils.layoutCardAndArc(winRect, cfg, geom, numel(sel.shown));
    price = utils.cardAOIs(cfg, priceL.cardRect, sel, 'price');
    [price.ok, price.report] = utils.checkAOIs(price.rects, price.names, geom, true);
    if ~price.ok && strcmp(cfg.aoiEnforcement, 'strict')
        warning('hw:contdc:priceAoiTooClose', ...
            'Some price-card AOIs are below the minimum separation -- see report above.');
    end

    layouts.(key) = struct('choice', choice, 'price', price);
end
end


%% ======================================================================


%% ======================================================================
function tr = blankTrial(domain, blockInfo)
tr = struct('domain', domain, 'block', blockInfo.block, ...
    'level', blockInfo.level, 'taskType', '', 'pairIdx', NaN, ...
    'leftIdx', NaN, 'rightIdx', NaN, 'moneyIdx', NaN, 'qualityIdx', NaN, ...
    'chosenSide', NaN, 'chosenIdx', NaN, 'choseMoney', NaN, ...
    'itemIdx', NaN, 'isMoneyOption', NaN, 'postedValue', NaN, ...
    'price', NaN, 'contrast', NaN, 'rt', NaN, 'timedOut', false, ...
    'startFrac', NaN);   % NaN on choice trials -- they have no arc
end


%% ======================================================================
function showBlockIntro(window, cfg, taskType, level, b, nBlocks)
s = cfg.style;
if strcmp(taskType, 'choice')
    what = 'You will see two options and choose the one you prefer.';
else
    what = 'You will see one option and say what it is worth to you.';
end
msg = sprintf('Block %d of %d\n\n%s\n\nEach option shows %d features.\n\nClick to begin.', ...
    b, nBlocks, what, level);
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);
DrawFormattedText(window, msg, 'center', 'center', s.text, 55, 0, 0, 1.7);
Screen('Flip', window);
utils.waitForClick(window);
end


%% ======================================================================
function showInstructions(window, cfg, domain)
s = cfg.style;
if strcmpi(domain, 'houses')
    body = ['You will now look at houses.\n\n' ...
            'Sometimes you will choose between two houses.\n' ...
            'Sometimes you will say what a single house is worth to you.\n\n' ...
            'There are no right answers -- we want your own judgement.'];
else
    body = ['You will now look at jobs.\n\n' ...
            'Sometimes you will choose between two jobs.\n' ...
            'Sometimes you will say what wage a single job is worth to you.\n\n' ...
            'There are no right answers -- we want your own judgement.'];
end
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeContent);
DrawFormattedText(window, [body quitNotice()], 'center', 'center', ...
    s.text, 60, 0, 0, 1.6);
Screen('Flip', window);
utils.waitForClick(window);
end


%% ======================================================================
function vbl = interTrial(window, cfg)
s = cfg.style;
Screen('FillRect', window, s.bg);
scr = Screen('Rect', window);
Screen('DrawDots', window, [scr(3)/2; scr(4)/2], 10, s.textDim, [], 2);
vbl = Screen('Flip', window);
WaitSecs(cfg.contdc.itiSec);
end


%% ======================================================================
function showMessage(window, cfg, msg, secs)
s = cfg.style;
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);
DrawFormattedText(window, msg, 'center', 'center', s.text, 55, 0, 0, 1.6);
Screen('Flip', window);
WaitSecs(secs);
end


%% ======================================================================
function drawGazeDot(window, cfg, sample)
[x, y] = utils.gazeToPixels(sample, window);
if ~isnan(x) && ~isnan(y)
    Screen('DrawDots', window, [x; y], 26, [255 80 80 180]/255, [], 2);
end
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
rows = {};
for d = 1:numel(dataMat.domains)
    dom = dataMat.domains{d};
    if ~isfield(dataMat, dom) || ~isfield(dataMat.(dom), 'trials'), continue; end
    Tr = dataMat.(dom).trials;
    for t = 1:numel(Tr)
        rows{end+1} = { dom, Tr(t).block, Tr(t).level, Tr(t).taskType, ...
            Tr(t).pairIdx, Tr(t).chosenIdx, Tr(t).choseMoney, ...
            Tr(t).itemIdx, Tr(t).isMoneyOption, Tr(t).postedValue, ...
            Tr(t).price, Tr(t).contrast, Tr(t).rt, Tr(t).timedOut, ...
            Tr(t).startFrac }; %#ok<AGROW>
    end
end
if isempty(rows), T = table(); return; end
T = cell2table(vertcat(rows{:}), 'VariableNames', {'domain','block','attrLevel', ...
    'taskType','pairIdx','chosenIdx','choseMoney','itemIdx','isMoneyOption', ...
    'postedValue','price','contrast','rt','timedOut','startFrac'});
end

%% ======================================================================
function s = quitNotice()
%QUITNOTICE  Footer for every instruction screen.
s = ['\n\n\nYou can stop at any time: press the Q key and the session ' ...
     'will end.\n\n\nClick to continue.'];
end
