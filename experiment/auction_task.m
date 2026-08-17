function dataMat = auction_task(sess, run)
%AUCTION_TASK  Sequential search with a continuous price response.
%
%   dataMat = auction_task(sess, run)
%
%   Converted from a script to a function so it can be called back to back
%   with continuous_DC_task inside one MATLAB session. Called directly with
%   no arguments it will bootstrap its own session, so it still runs
%   standalone for a between-subjects design.
%
%   A "trial" here is a whole search episode: options arrive and expire on
%   the market, the participant inspects and rejects until they find one
%   worth bidding on, and the episode ends when a bid clears or the options
%   run out. Twelve of those fills roughly twelve minutes and yields a lot
%   of gaze data per trial.

if nargin < 1 || isempty(sess)
    sess = utils.startSession();
end
if nargin < 2 || isempty(run)
    run = utils.beginRun(sess, 'auction');
    standalone = true;
else
    standalone = false;
end

% Domains belong to the RUN now (see utils.beginRun), so the same task can be
% called for jobs only, houses only, or both, independently of what other
% tasks this participant is doing.
if isfield(run, 'domains') && ~isempty(run.domains)
    domainList = run.domains;
else
    domainList = sess.domains;
end

cfg = sess.cfg;
rs  = RandStream('twister', 'Seed', run.seed);

dataMat = struct();
dataMat.domains = domainList;
window = [];
et = struct('enabled', false, 'obj', [], 'showGaze', false, 'analyzable', false);

try
    % =============================================== display setup
    % Defensive reset even on a clean start: if a PREVIOUS run in this same
    % MATLAB session crashed in a way that didn't reach our own cleanup
    % code (e.g. a Ctrl-C, or an error thrown by something outside our
    % try/catch), PsychImaging's persistent configuration-phase state can
    % still be dirty here. This is a no-op if everything was already clean.
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
    Priority(MaxPriority(window));
    % Cursor stays visible throughout -- almost every screen in this task
    % is click-driven (grid boxes, detail panel, pricing arc / choice
    % cards), so participants need to see where they're pointing.
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
                                 'mediaMode', et.showGaze);

    % =============================================== per domain
    for d = 1:numel(domainList)
        domain = domainList{d};
        fprintf('\n===== %s =====\n', upper(domain));

        utils.trace('domain %s: loading stimuli', domain);
        A = utils.attributes(domain);
        stimuli = utils.readStimuli(cfg, domain);
        utils.trace('domain %s: %d stimuli loaded', domain, height(stimuli));

        % ---- elicitation ------------------------------------------
        % Reuse the participant's budget/reservation-wage anchor and
        % attribute ratings if this domain was already elicited earlier
        % THIS SESSION (e.g. contdc ran first, auction runs next) -- no
        % reason to make them state their budget or re-rate ten attributes
        % twice in one sitting. A different session number (a real day
        % break) is a deliberate cache miss: re-eliciting there gives a
        % fresh, consistent measurement rather than reusing a stated
        % preference that may not still hold.
        cached = utils.elicitationCache('load', sess, domain);
        if ~isempty(cached)
            anchor          = cached.anchor;
            anchorRT        = cached.anchorRT;
            poolRatings     = cached.poolRatings;
            attrRTs         = cached.attrRTs;
            industryRatings = cached.industryRatings;
            if strcmpi(domain, 'jobs') && ~isempty(cached.keepIndustries)
                stimuli = stimuli(ismember(stimuli.industry, cached.keepIndustries), :);
            end
        elseif cfg.testing.enabled && cfg.testing.skipElicitation
            anchor = utils.ternary(strcmpi(domain,'houses'), 400000, 25);
            anchorRT = NaN;
            poolRatings = linspace(0.9, 0.1, A.nPool);
            attrRTs = nan(1, A.nPool);
            industryRatings = [];
        else
            utils.trace('domain %s: eliciting anchor', domain);
            [anchor, anchorRT] = utils.elicitAnchor(window, cfg, domain);
            utils.trace('domain %s: anchor = %g', domain, anchor);

            industryRatings = [];
            keepIndustries = {};
            if strcmpi(domain, 'jobs')
                inds = unique(stimuli.industry);
                [industryRatings, ~, ~] = utils.elicitVAS(window, cfg, cellstr(inds), ...
                    'How likely would you be to apply for a job in each of these industries?', ...
                    {'Entirely unlikely', 'Extremely likely'});
                [~, ord] = sort(industryRatings, 'descend');
                keepIndustries = cellstr(inds(ord(1:min(cfg.sampling.nTopIndustries, numel(ord)))));
                stimuli = stimuli(ismember(stimuli.industry, keepIndustries), :);
                fprintf('Filtered to %d jobs across %d industries.\n', height(stimuli), numel(keepIndustries));
            end

            [poolRatings, attrRTs, ~] = utils.elicitVAS(window, cfg, {A.pool.label}, ...
                'How important is each of these to you?', ...
                {'Entirely unimportant', 'Extremely important'});

            capture = struct();
            capture.anchor          = anchor;
            capture.anchorRT        = anchorRT;
            capture.poolRatings     = poolRatings;
            capture.attrRTs         = attrRTs;
            capture.industryRatings = industryRatings;
            capture.keepIndustries  = keepIndustries;
            utils.elicitationCache('save', sess, domain, capture);
        end

        % ---- attribute selection ----------------------------------
        % Fixed level in this task: 12 trials over 2 competition levels is
        % 6 per level, which works; adding 3 attribute levels would leave 2
        % per cell, which does not. The attribute-count manipulation lives
        % in continuous_DC_task, which has short trials and can afford it.
        sel = utils.selectAttributes(A, cfg.auction.nAttrs, poolRatings, ...
                                  cfg.attrMethod, false);
        fprintf('Showing %d attributes (mean importance rank %.1f).\n', ...
            numel(sel.shown), sel.meanRank);

        % ---- stimulus window --------------------------------------
        vals = stimuli.(A.valueVar);
        win = utils.sampleWindow(vals, anchor, cfg.sampling.spread, ...
                              cfg.sampling.minN);
        inWindow = stimuli(win.idx, :);
        fprintf('Window %s to %s: %d stimuli (widened %.2fx).\n', ...
            utils.formatCurrency(win.lo, A.priceStyle), ...
            utils.formatCurrency(win.hi, A.priceStyle), win.n, win.widenBy);

        % ---- trial plan -------------------------------------------
        nTrials = cfg.auction.nTrials;
        if cfg.testing.enabled
            nTrials = cfg.testing.nTrialsPerType;
        end
        planCfg = cfg; planCfg.auction.nTrials = nTrials;
        planCfg.auction.nOptionsPerTrial = min(cfg.auction.nOptionsPerTrial, win.n);
        plan = utils.trialPlan(planCfg, win.n, rs);

        if ~isempty(cfg.testing.forceCompetition)
            [plan.competition] = deal(cfg.testing.forceCompetition);
        end

        % ---- textures ---------------------------------------------
        % Loaded ONLY for stimuli that actually appear across the trial
        % plan, not every candidate in the sampled window -- the window
        % can hold several times more stimuli than any trial ever shows.
        neededIdx = [];
        for t = 1:numel(plan)
            neededIdx = [neededIdx, plan(t).stimIdx]; %#ok<AGROW>
        end
        utils.trace('domain %s: loading images for %d stimuli (of %d sampled)', ...
            domain, numel(unique(neededIdx)), win.n);
        tex = utils.loadStimulusTextures(window, cfg, inWindow, A, neededIdx, true);

        % ---- instructions -----------------------------------------
        if ~(cfg.testing.enabled && cfg.testing.skipInstructions)
            showInstructions(window, cfg, domain);
        end

        % ---- layout + AOI validation ------------------------------
        L = layoutGrid(winRect, cfg);
        % 'dev' rig runs (laptop, no tracker) get this as information only --
        % it's still useful to see spacing before the lab session, but there
        % is nothing to protect since no gaze data will be collected.
        [aoiOK, aoiReport] = utils.checkAOIs(L.aoiRects, L.aoiNames, geom, true);
        if ~aoiOK && strcmp(cfg.aoiEnforcement, 'strict')
            warning('hw:auction:aoiTooClose', ...
                'Some AOIs are below the minimum separation -- see report above.');
        end

        % ---- run trials -------------------------------------------
        trials = struct([]);
        log = utils.eventLog('init', 20000);
        gazeStore = utils.gazeBuffer('init');

        utils.trace('domain %s: starting %d trials', domain, numel(plan));
        for t = 1:numel(plan)
            if cfg.et.driftCheck && mod(t, cfg.auction.driftEvery) == 1 && t > 1
                [offset, recal] = utils.driftCheck(et, window, cfg, ...
                    [winRect(3)/2, winRect(4)/2]);
                log = utils.eventLog('add', log, 'drift_check', GetSecs, ...
                    struct('offsetDeg', offset, 'recalibrated', double(recal)));
            end

            [trial, log, gazeStore] = runSearchEpisode( ...
                window, cfg, geom, L, et, log, gazeStore, ...
                inWindow, tex, sel, A, domain, plan(t), numel(plan), rs, win);

            if isempty(trials), trials = trial; else, trials(end+1) = trial; end %#ok<AGROW>
        end

        % ---- store ------------------------------------------------
        dataMat.(domain).anchor          = anchor;
        dataMat.(domain).anchorRT        = anchorRT;
        dataMat.(domain).reservationWage = utils.ternary(strcmpi(domain,'jobs'), anchor, NaN);
        dataMat.(domain).budget          = utils.ternary(strcmpi(domain,'houses'), anchor, NaN);
        dataMat.(domain).poolRatings     = poolRatings;
        dataMat.(domain).poolRatingRTs   = attrRTs;
        dataMat.(domain).poolLabels      = {A.pool.label};
        dataMat.(domain).industryRatings = industryRatings;
        dataMat.(domain).attrSelection   = sel;
        dataMat.(domain).window          = win;
        dataMat.(domain).stimuliShown    = inWindow;
        dataMat.(domain).plan            = plan;
        dataMat.(domain).trials          = trials;
        dataMat.(domain).events          = utils.eventLog('table', log);
        dataMat.(domain).aoiRects        = L.aoiRects;
        dataMat.(domain).aoiNames        = L.aoiNames;
        dataMat.(domain).aoiReport       = aoiReport;

        % Gaze goes to its own file: it is orders of magnitude larger than
        % everything else and does not belong in the behavioural .mat.
        gaze = utils.gazeBuffer('flush', et, gazeStore);
        if ~isempty(gaze)
            gazeFile = strrep(run.gazeFile, '_gaze.mat', sprintf('_%s_gaze.mat', domain));
            save(gazeFile, 'gaze', '-v7.3');
            dataMat.(domain).gazeFile = gazeFile;
            fprintf('Saved %d gaze samples to %s\n', numel(gaze), gazeFile);
        end

        Screen('Close', struct2texlist(tex));
    end

    % =============================================== payout
    payout = utils.incentives('compute', sess, dataMat, cfg.incentives);
    dataMat.payout = payout;
    if cfg.incentives.enabled
        showPayout(window, cfg, payout);
    else
        showMessage(window, cfg, 'Thank you. That is the end of this task.', 2.5);
    end

    % =============================================== save
    utils.saveRun(sess, run, dataMat, buildTrialTable(dataMat));

    ListenChar(0); ShowCursor; Priority(0); sca; clear PsychImaging;
    if standalone, utils.endRun(sess, run, 'complete'); end

catch ME
    ListenChar(0); ShowCursor; Priority(0);
    % Always call sca, even if `window` never got assigned -- a failed
    % OpenWindow leaves PsychImaging's internal configuration state dirty,
    % and if that's never cleared the NEXT task's OpenWindow call fails
    % too ("did not finalize the previous phase"), which is exactly the
    % cascade that made one bad run take a whole session down with it.
    % Screen('CloseAll') is safe to call even when nothing is open.
    %
    % sca resets Screen-level window state but NOT PsychImaging's own
    % persistent configuration-phase variables (they live inside the
    % psychimaging.m function itself, not in Screen's MEX state). Without
    % clearing those too, the NEXT OpenWindow call in this MATLAB session
    % can come back with a handle that LOOKS valid but isn't fully
    % initialized -- which shows up as a generic Screen "Usage:" error on
    % the first real draw call after it opens, not at OpenWindow itself.
    sca;
    clear PsychImaging;
    crashFile = fullfile(cfg.paths.crashed, [run.runId '_crash.mat']);
    save(crashFile, 'ME', 'dataMat', 'sess', 'run');
    fprintf(2, '\nCrashed. Partial data saved to:\n  %s\n', crashFile);
    if standalone, utils.endRun(sess, run, 'crashed'); end
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
trial.stimIdx     = planRow.stimIdx;
trial.repIdx      = planRow.repIdx;
trial.nAttrs      = numel(sel.shown);

% Arrival schedule. Competition drives turnover: under high competition
% options come and go faster, so there is more pressure to decide.
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
trial.endReason   = 'exhausted';

% Fixation-start gate: sets a known gaze anchor before the episode begins,
% and lets the participant start when ready. Crucially this happens BEFORE
% the market clock starts (t0 below) -- the arrival/expiry schedule starts
% ticking from when they click ready, not from whenever this function
% happened to be called, so an option's on-market window is never silently
% eaten by them still reading the fixation screen.
[t0, log] = utils.awaitFixationStart(window, cfg, log, struct( ...
    'trial', planRow.trial, 'nTrials', nTrials, ...
    'label', sprintf('%s - %s competition', domain, planRow.competition)));
lastFlip = t0;

while true
    now = GetSecs - t0;

    % ---- retire expired options ------------------------------------
    for b = 1:nBoxes
        if ~isnan(boxStim(b))
            k = find(planRow.stimIdx == boxStim(b), 1);
            if ~isempty(k) && now > expiry(k)
                log = utils.eventLog('add', log, 'option_remove', lastFlip, ...
                    struct('box', b, 'stimIdx', boxStim(b), ...
                           'trial', planRow.trial, 'reason', 'expired'));
                boxStim(b) = NaN;
                boxVacantUntil(b) = now + utils.gammaSample( ...
                    cfg.auction.vacancyShape, ...
                    cfg.auction.vacancyGapMean/cfg.auction.vacancyShape, 1, rs);
            end
        end
    end

    % ---- fill empty boxes -------------------------------------------
    % A box must ALSO have cleared its vacancy timer, not just be empty
    % with a queued arrival ready -- otherwise a rejection or expiry that
    % happens to coincide with an arrival backlog gets an instant
    % replacement, which is the "market" not behaving like one.
    for b = 1:nBoxes
        if isnan(boxStim(b)) && nextIdx <= numel(planRow.stimIdx) ...
                && now >= arrivals(nextIdx) && now >= boxVacantUntil(b)
            boxStim(b)  = planRow.stimIdx(nextIdx);
            boxSince(b) = now;
            presented(end+1) = planRow.stimIdx(nextIdx); %#ok<AGROW>
            log = utils.eventLog('add', log, 'option_appear', lastFlip, ...
                struct('box', b, 'stimIdx', boxStim(b), ...
                       'trial', planRow.trial, ...
                       'repIdx', planRow.repIdx(nextIdx)));
            nextIdx = nextIdx + 1;
        end
    end

    % ---- end conditions ---------------------------------------------
    if all(isnan(boxStim)) && nextIdx > numel(planRow.stimIdx)
        trial.endReason = 'exhausted';
        break
    end
    if now > cfg.auction.trialTimeoutSec
        trial.endReason = 'timeout';
        break
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
        log = utils.eventLog('add', log, 'option_reject', lastFlip, ...
            struct('box', b, 'stimIdx', stimIdx, 'trial', planRow.trial, ...
                   'dwellSec', now - boxSince(b)));
        boxStim(b) = NaN;
        boxVacantUntil(b) = now + utils.gammaSample( ...
            cfg.auction.vacancyShape, ...
            cfg.auction.vacancyGapMean/cfg.auction.vacancyShape, 1, rs);
        continue
    end

    % ---- detail view ---------------------------------------------------
    enterT = GetSecs;
    log = utils.eventLog('add', log, 'detail_enter', lastFlip, ...
        struct('stimIdx', stimIdx, 'trial', planRow.trial, 'box', b));

    [action, gazeStore, log] = showDetail(window, cfg, geom, et, log, ...
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

    [bid, bidRT, gazeStore, log] = getBid(window, cfg, et, log, gazeStore, ...
        stimTbl, sel, A, stimIdx, domain, planRow, nTrials, win);

    if isnan(bid)
        continue
    end

    % BDM: the bid decides WHETHER you transact, never what you pay. That
    % is what makes truthful bidding optimal -- under the old first-price
    % rule the recorded numbers were strategically shaded bids, not
    % valuations, and the model would have absorbed the shading into its
    % threshold and start-point parameters.
    isHouse  = strcmpi(domain, 'houses');
    accepted = utils.ternary(isHouse, bid >= threshold, bid <= threshold);

    trial.bid        = bid;
    trial.bidRT      = bidRT;
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
        showOutcome(window, cfg, true, domain, threshold, bid);
        break
    else
        boxStim(b) = NaN;
        boxVacantUntil(b) = now + utils.gammaSample( ...
            cfg.auction.vacancyShape, ...
            cfg.auction.vacancyGapMean/cfg.auction.vacancyShape, 1, rs);
        showOutcome(window, cfg, false, domain, threshold, bid);
    end
end

trial.duration    = GetSecs - t0;
trial.presented   = presented;
trial.rejected    = rejected;
trial.nPresented  = numel(presented);
trial.nRejected   = numel(rejected);
trial.inspections = inspections;

end


%% ======================================================================
function L = layoutGrid(winRect, cfg)
%LAYOUTGRID  Six option tiles below the HUD, with AOI rects.
%
%   Each tile carries ONE preview image rather than two. The old layout put
%   the exterior and living-room thumbnails 40 px apart -- about 1 deg --
%   which no remote tracker can separate. One image per tile removes the
%   problem instead of papering over it.

s = cfg.style;
W = winRect(3); H = winRect(4);
hudH = s.hud.enabled * s.hud.heightPx;

nCols = 3; nRows = 2;
pad = 18;
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
    L.imgRects(:,k) = [bx(1)+16; bx(2)+16; bx(3)-16; bx(2)+round(bh*0.58)];
    L.txtRects(:,k) = [bx(1)+16; bx(2)+round(bh*0.66); bx(3)-16; bx(4)-16];
    L.aoiRects(:, 2*k-1) = L.imgRects(:,k);
    L.aoiRects(:, 2*k)   = L.txtRects(:,k);
    L.aoiNames{2*k-1} = sprintf('box%d_img', k);
    L.aoiNames{2*k}   = sprintf('box%d_txt', k);
end

end


%% ======================================================================
function drawGrid(window, cfg, L, stimTbl, tex, sel, A, boxStim, domain, hud) %#ok<INUSD>
% hud is intentionally unused: the search grid stays clean of progress or
% condition chrome so nothing here competes with the options themselves
% for gaze. That information is shown once, on the fixation-start screen
% that precedes each search episode (see utils.awaitFixationStart), and
% again at block boundaries -- never during the response itself.
s = cfg.style;
Screen('FillRect', window, s.bg);

for b = 1:size(L.boxRects, 2)
    r = L.boxRects(:,b)';
    if isnan(boxStim(b))
        Screen('FrameRect', window, s.bgPanel, r, 2);
        continue
    end
    idx = boxStim(b);

    Screen('FillRect',  window, s.bgPanel, r);
    Screen('FrameRect', window, s.interactive, r, s.borderWidthPx);

    % Preview image (houses only)
    if strcmpi(domain, 'houses') && isfield(tex, 'extPic') && ~isnan(tex.extPic(idx))
        Screen('DrawTexture', window, tex.extPic(idx), [], L.imgRects(:,b)');
    end

    % Preview text: identity plus the core value plus the single highest
    % rated attribute the participant actually cares about.
    Screen('TextFont', window, s.fontContent);
    tr = L.txtRects(:,b)';
    y = tr(2) + 8;

    Screen('TextSize', window, s.sizeLabel);
    idText = identityString(stimTbl, sel, idx);
    DrawFormattedText(window, idText, tr(1)+8, y+20, s.textDim, 34, 0, 0, 1.2);
    y = y + 46;

    Screen('TextSize', window, s.sizeContent);
    valText = utils.formatCurrency(stimTbl.(A.valueVar)(idx), A.priceStyle);
    DrawFormattedText(window, valText, tr(1)+8, y+22, s.money);
end

end


%% ======================================================================
function [action, gazeStore, log] = showDetail(window, cfg, geom, et, log, ...
    gazeStore, stimTbl, tex, sel, A, idx, domain, hud)
%SHOWDETAIL  Full-width attribute panel for one option.
%
%   The old version drew into the LEFT HALF of the screen only and left the
%   right half empty, while cramming six images and six text rows into
%   960 px -- gaps of 28 px, about 0.74 deg. Using the full width is what
%   makes the AOI separation achievable at all.

s = cfg.style;
winRect = Screen('Rect', window);
W = winRect(3); H = winRect(4);
hudH = s.hud.enabled * s.hud.heightPx;

n = numel(sel.shown);
nCols = min(n, 4);
nRows = ceil(n / nCols);

gap  = geom.targetSepPx;
marg = 60;
panelW = floor((W - 2*marg - (nCols-1)*gap) / nCols);

% Identity images (houses: all six photos) get their own reserved strip
% above the attribute grid, shown ALWAYS regardless of attribute-count
% level -- zero height if this domain's identity has no images (jobs).
hasIdentityImages = any(strcmp({sel.identity.kind}, 'image'));
stripH = utils.ternary(hasIdentityImages, 170, 0);
idRect = [marg, hudH + 70, W - marg, hudH + 70 + stripH];
gridTop = hudH + 100 + stripH;

availH = H - hudH - 220 - stripH;
panelH = floor((availH - (nRows-1)*gap) / nRows);

action = '';
while true
    % Detail view stays clean for the same reason as the search grid --
    % no HUD here, only the option's own attributes.
    Screen('FillRect', window, s.bg);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    utils.drawIdentityStrip(window, cfg, tex, sel, idx, idRect);
    idText = identityString(stimTbl, sel, idx);
    if ~isempty(idText)
        DrawFormattedText(window, idText, 'center', hudH + 52, s.text);
    end

    for k = 1:n
        c = mod(k-1, nCols); r = floor((k-1)/nCols);
        px = marg + c*(panelW+gap);
        py = gridTop + r*(panelH+gap);
        pr = [px, py, px+panelW, py+panelH];

        Screen('FillRect',  window, s.bgPanel, pr);
        Screen('FrameRect', window, s.border, pr, 2);

        attr = sel.shown(k);
        Screen('TextSize', window, s.sizeLabel);
        DrawFormattedText(window, attr.label, px+12, py+28, s.textDim, 30, 0, 0, 1.2);

        if strcmp(attr.kind, 'image')
            if isfield(tex, attr.var) && ~isnan(tex.(attr.var)(idx))
                imr = [px+12, py+46, px+panelW-12, py+panelH-12];
                Screen('DrawTexture', window, tex.(attr.var)(idx), [], imr);
            end
        else
            Screen('TextSize', window, s.sizeContent);
            col = utils.ternary(strcmp(attr.var, A.valueVar), s.money, s.text);
            DrawFormattedText(window, valueString(stimTbl, attr, idx), ...
                px+12, py + panelH/2 + 12, col, 26, 0, 0, 1.3);
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
    Screen('Flip', window);
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
function [bid, rt, gazeStore, log] = getBid(window, cfg, et, log, gazeStore, ...
    stimTbl, sel, A, idx, domain, planRow, nTrials, win)
%GETBID  Semicircular continuous price scale.
%
%   Two fixes. The scale maximum now comes from the sampled WINDOW rather
%   than the item's own list price -- the old rule meant a participant could
%   never bid above list, and with a $9.98M outlier in the set an
%   item-derived scale put every realistic bid in the leftmost few percent
%   of the arc. And tick labels go through utils.formatCurrency, which picks
%   its unit from the magnitude; the old hard-coded '$%.0fk' rendered every
%   tick on the wage scale as '$0k'.

s = cfg.style;
winRect = Screen('Rect', window);
W = winRect(3); H = winRect(4);

scaleMin = win.scaleMin;
scaleMax = win.scaleMax;

cx = W/2; cy = H * 0.80;
outerR = min(W*0.40, H*0.62);
innerR = outerR * 0.82;

nTicks = 7;
tickVals = linspace(scaleMin, scaleMax, nTicks);

bid = NaN; rt = NaN;
t0 = GetSecs;
SetMouse(round(cx), round(cy - innerR), window);

while true
    % Bid screen stays clean too -- competition level was already shown on
    % the fixation-start screen at the top of this search episode.
    Screen('FillRect', window, s.bg);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    if strcmpi(domain, 'houses')
        q = 'How much would you offer for this house?';
    else
        q = 'What hourly wage would you accept for this job?';
    end
    DrawFormattedText(window, q, 'center', H*0.14, s.text);

    % Arc
    a = linspace(pi, 2*pi, 180);
    ax = cx + outerR*cos(a);  ay = cy + outerR*sin(a);
    bx = cx + innerR*cos(a);  by = cy + innerR*sin(a);
    Screen('DrawLines', window, [reshape([ax;bx],1,[]); reshape([ay;by],1,[])], ...
        3, s.border);

    % Ticks and labels
    Screen('TextSize', window, s.sizeLabel);
    for k = 1:nTicks
        ang = pi + (k-1)/(nTicks-1) * pi;
        tx1 = cx + innerR*cos(ang); ty1 = cy + innerR*sin(ang);
        tx2 = cx + outerR*cos(ang); ty2 = cy + outerR*sin(ang);
        Screen('DrawLine', window, s.textDim, tx1, ty1, tx2, ty2, 3);

        lbl = utils.formatCurrency(tickVals(k), 'compact');
        lx = cx + (outerR+42)*cos(ang); ly = cy + (outerR+42)*sin(ang);
        bnd = Screen('TextBounds', window, lbl);
        DrawFormattedText(window, lbl, lx - bnd(3)/2, ly, s.textDim);
    end

    % Response
    [mx, my, buttons] = utils.getMouse(window);
    dx = mx - cx; dy = cy - my;
    ang = atan2(max(dy, 0), dx);
    frac = 1 - ang/pi;
    frac = min(max(frac, 0), 1);
    if ~isfinite(frac), frac = 0.5; end   % defensive: never let a bad mouse
                                           % read reach a Screen() coordinate
    curVal = scaleMin + frac * (scaleMax - scaleMin);

    px = cx + innerR*cos(pi + frac*pi);
    py = cy + innerR*sin(pi + frac*pi);
    Screen('DrawLine', window, s.interactive, cx, cy, px, py, 4);
    Screen('DrawDots', window, [px; py], 20, s.interactive, [], 2);

    Screen('TextSize', window, s.sizeTitle);
    txt = utils.formatCurrency(curVal, A.priceStyle);
    bnd = Screen('TextBounds', window, txt);
    DrawFormattedText(window, txt, cx - bnd(3)/2, cy - 60, s.money);

    gazeStore = utils.gazeBuffer('poll', et, gazeStore);
    if et.showGaze && ~isempty(gazeStore.latest)
        drawGazeDot(window, cfg, gazeStore.latest);
    end
    Screen('Flip', window);
    utils.checkForQuit;

    if buttons(1)
        bid = curVal;
        rt = GetSecs - t0;
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        log = utils.eventLog('add', log, 'bid_made', GetSecs, ...
            struct('stimIdx', idx, 'trial', planRow.trial, 'bid', bid, 'rt', rt));
        return
    elseif buttons(2)
        while any(buttons), [~,~,buttons] = utils.getMouse(window); end
        return
    end
end

end


%% ======================================================================
function showOutcome(window, cfg, accepted, domain, pricePaid, bid)
s = cfg.style;
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeHeading);

isHouse = strcmpi(domain, 'houses');
style = utils.ternary(isHouse, 'total', 'hourly');

if accepted
    if isHouse
        msg = sprintf(['Your offer was accepted.\n\n' ...
            'You offered %s.\nYou pay the market price of %s.'], ...
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
Screen('Flip', window);
WaitSecs(cfg.auction.feedbackSec);

end


%% ======================================================================
function showInstructions(window, cfg, domain)
s = cfg.style;
txt = utils.incentives('instructions', domain, cfg.incentives);
Screen('FillRect', window, s.bg);
Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeContent);
DrawFormattedText(window, [txt '\n\n\nClick to continue.'], ...
    'center', 'center', s.text, 62, 0, 0, 1.6);
Screen('Flip', window);
utils.waitForClick(window);
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
function str = identityString(stimTbl, sel, idx)
parts = {};
for k = 1:numel(sel.identity)
    v = sel.identity(k).var;
    if ismember(v, stimTbl.Properties.VariableNames)
        val = stimTbl.(v)(idx);
        if iscell(val), val = val{1}; end
        if ischar(val) || isstring(val)
            parts{end+1} = char(val); %#ok<AGROW>
        end
    end
end
if isempty(parts), str = ''; else, str = strjoin(parts, '  -  '); end
end


%% ======================================================================
function str = valueString(stimTbl, attr, idx)
v = stimTbl.(attr.var)(idx);
if iscell(v), v = v{1}; end
switch attr.kind
    case {'currency', 'total'}
        str = utils.formatCurrency(v, 'total');
    case 'hourly'
        str = utils.formatCurrency(v, 'hourly');
    case 'rating'
        str = sprintf('%.1f / 5', v);
    case 'count'
        str = sprintf('%g', v);
    case 'year'
        str = sprintf('%d', round(v));
    case 'number'
        str = sprintf('%.4g', v);
    case 'category'
        str = char(string(v));
    otherwise
        str = char(string(v));
end
end


%% ======================================================================
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
%BUILDTRIALTABLE  Long-format one row per trial, for the CSV.
rows = {};
for d = 1:numel(dataMat.domains)
    dom = dataMat.domains{d};
    if ~isfield(dataMat, dom) || ~isfield(dataMat.(dom), 'trials'), continue; end
    Tr = dataMat.(dom).trials;
    for t = 1:numel(Tr)
        rows{end+1} = { dom, Tr(t).trial, Tr(t).competition, Tr(t).nAttrs, ...
            Tr(t).nPresented, Tr(t).nRejected, Tr(t).duration, ...
            Tr(t).bidAccepted, Tr(t).bid, Tr(t).threshold, Tr(t).pricePaid, ...
            Tr(t).trueValue, Tr(t).bidStimIdx, Tr(t).endReason, ...
            dataMat.(dom).anchor }; %#ok<AGROW>
    end
end
if isempty(rows), T = table(); return; end
M = vertcat(rows{:});
T = cell2table(M, 'VariableNames', {'domain','trial','competition','nAttrs', ...
    'nPresented','nRejected','durationSec','bidAccepted','bid','threshold', ...
    'pricePaid','trueValue','bidStimIdx','endReason','anchor'});
end
