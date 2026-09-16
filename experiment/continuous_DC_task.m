function dataMat = continuous_DC_task(sess, run)
%CONTINUOUS_DC_TASK  Pricing versus discrete choice, crossed with attribute count.
%
%   dataMat = continuous_DC_task(sess, run)
%
%   Rebuilt rather than refactored: the previous main loop referenced five
%   variables that were never defined (stimTbl, allTextures, type, saveName,
%   subID), so it could not run at all.
%
%   Design. Each pair of options is both CHOSEN between and PRICED
%   separately, which is what makes a preference reversal measurable -- the
%   old version drew choice and pricing items independently, so the two
%   responses could never be compared for the same options. Task type is
%   blocked and counterbalanced, following the classic paradigm, so that
%   participants are not visibly trying to stay consistent with a choice
%   they made moments earlier.
%
%   This task now carries the attribute-count manipulation (2/4/6), handed
%   over from auction_task, which has too few trials to cross it with
%   competition.

if nargin < 1 || isempty(sess)
    sess = utils.startSession();
end
if nargin < 2 || isempty(run)
    run = utils.beginRun(sess, 'contdc');
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
% Which visual theme this run was collected under. Without it a
% session that was rolled back mid-way cannot be stratified later.
dataMat.theme   = cfg.style.themeName;
% [] on a full study run; an integer on a shortened rehearsal. A
% rehearsal saves into the real Data tree like any other run, so
% this is what keeps it filterable out of the analysis later.
dataMat.trialsPerCell = cfg.rehearsal.trialsPerCell;
window = [];

try
    % =============================================== display
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

    % The window exists but nothing has been drawn yet, which is the
    % only point at which fonts can be probed. This is the sole place
    % cfg.style is mutated after utils.config builds it -- safe, since
    % every consumer reads cfg.style at draw time.
    cfg.style = utils.resolveFonts(window, cfg.style);
    utils.trace('fonts: content=%s chrome=%s', ...
        cfg.style.fontContent, cfg.style.fontChrome);

    Priority(MaxPriority(window));
    % Cursor stays visible throughout -- almost every screen in this task
    % is click-driven (grid boxes, detail panel, pricing arc / choice
    % cards), so participants need to see where they're pointing.
    ShowCursor('Arrow', window);
    ListenChar(2);

    geom = cfg.geom;
    geom.widthPx = winRect(3); geom.heightPx = winRect(4);

    % Eye tracking now runs here too -- the old file created an `et`
    % variable and then never used it.
    utils.trace('setting up eye tracker (enabled=%d)', cfg.et.enabled);
    et = utils.setupEyeTracker(cfg, window, ~cfg.testing.enabled);
    utils.trace('eye tracker setup done (connected=%d)', et.enabled);
    dataMat.eyeTracking = struct('enabled', et.enabled, ...
        'analyzable', et.analyzable, 'positioned', et.positioned, ...
        'mediaMode', et.showGaze, ...
        'requestedSampleRateHz', et.requestedSampleRateHz, ...
        'actualSampleRateHz', et.actualSampleRateHz);

    % =============================================== per domain
    for d = 1:numel(domainList)
        domain = domainList{d};
        fprintf('\n===== %s (continuous/DC) =====\n', upper(domain));

        utils.trace('domain %s: loading stimuli', domain);
        A = utils.attributes(domain);
        stimuli = utils.readStimuli(cfg, domain);
        utils.trace('domain %s: %d stimuli loaded', domain, height(stimuli));

        % ---- elicitation ---------------------------------------------
        % Reuse the participant's budget/reservation-wage anchor and
        % attribute ratings if this domain was already elicited earlier
        % THIS SESSION (e.g. auction ran first, contdc runs next) -- no
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
            % Listed price / offered wage is rated on the same line as the
            % pool, and then excluded from the selection that follows --
            % it is always shown, so its rating cannot decide anything.
            % See utils.elicitAttrRatings for why it is collected at all.
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
        % Selects rows, or keeps them all and fits their prices onto the
        % window, depending on cfg.sampling.fitToWindow for this domain.
        % This is also what supplies the 36 distinct houses buildPairs
        % needs for 3 attribute levels with cross-level reuse blocked.
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

        % Pairs for every attribute level, built EAGERLY here rather than
        % lazily inside the block loop -- this is what lets us know the
        % full set of stimuli that will ever be shown BEFORE loading any
        % images, instead of loading per block.
        nPairsThisRun = cfg.contdc.nPairs.(lower(domain));
        if ~isempty(cfg.rehearsal.trialsPerCell)
            % contdc's design cells are attribute level x task type, and
            % nPairs is already per level, so this maps straight across.
            % A price block prices BOTH options of every pair, so it still
            % yields twice a choice block's trials at the same nPairs.
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

            % Exclude stimuli already claimed by an earlier level, so a
            % participant never values the same house/job twice under
            % different information loads. Reuse WITHIN a level (choose
            % between a pair, then price each of its two options) is
            % required by the paradigm and is unaffected by this.
            if cfg.contdc.allowCrossLevelReuse
                exclude = [];
            else
                exclude = usedAcrossLevels;
            end

            [pairsByLevel.(key), claimed] = utils.buildPairs(inWindow, ...
                selByLevel.(key), A, nPairsThisRun, rs, exclude);
            usedAcrossLevels = unique([usedAcrossLevels, claimed]);

            for pk = 1:numel(pairsByLevel.(key))
                neededIdx(end+1) = pairsByLevel.(key)(pk).moneyIdx;   %#ok<AGROW>
                neededIdx(end+1) = pairsByLevel.(key)(pk).qualityIdx; %#ok<AGROW>
            end
        end

        utils.trace('domain %s: %d distinct stimuli claimed across %d levels (reuse %s)', ...
            domain, numel(usedAcrossLevels), numel(unique(levels)), ...
            utils.ternary(cfg.contdc.allowCrossLevelReuse, 'allowed', 'blocked'));
        aoiLayouts = buildAoiLayouts(winRect, cfg, geom, selByLevel, levels);

        if ~(cfg.testing.enabled && cfg.testing.skipInstructions)
            showInstructions(window, cfg, domain);
        end

        % Load images ONCE for the domain, only for stimuli that will
        % actually appear -- not the whole sampled window (which can be
        % several times larger than what any trial ever shows), and not
        % once per block. This is also what makes the "fetching photos"
        % screen show up once, up front, rather than as a pause between
        % every block.
        utils.trace('domain %s: loading images for %d stimuli (of %d sampled)', ...
            domain, numel(unique(neededIdx)), win.n);
        tex = utils.loadStimulusTextures(window, cfg, inWindow, A, neededIdx, true);

        log = utils.eventLog('init', 20000);
        gazeStore = utils.gazeBuffer('init');
        clockSync = struct('start', utils.clockSync(et), 'end', []);
        trials = struct([]);

        for b = 1:numel(blocks)
            lvl  = blocks(b).attrLevel;
            task = blocks(b).taskType;

            key = sprintf('lvl%d', lvl);
            sel = selByLevel.(key);
            pairs = pairsByLevel.(key);

            if cfg.et.driftCheck && mod(b, cfg.contdc.driftEvery) == 1 && b > 1
                [off, recal] = utils.driftCheck(et, window, cfg, ...
                    [winRect(3)/2, winRect(4)/2]);
                log = utils.eventLog('add', log, 'drift_check', GetSecs, ...
                    struct('offsetDeg', off, 'recalibrated', double(recal)));
            end

            utils.trace('block %d/%d: %s, level %d', b, numel(blocks), task, lvl);
            showBlockIntro(window, cfg, task, lvl, b, numel(blocks));

            order = randperm(rs, numel(pairs));

            % Trial-within-block counting, separate from block counting.
            % Choice blocks run one trial per pair; price blocks run TWO
            % (money option and quality option, each priced separately),
            % so the total differs by task type even at the same nPairs.
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
                    [tr, log, gazeStore] = runChoiceTrial(window, cfg, geom, et, ...
                        log, gazeStore, inWindow, tex, sel, A, p, domain, ...
                        struct('block', b, 'nBlocks', numel(blocks), 'level', lvl, ...
                               'trialInBlock', trialInBlock, 'nTrialsInBlock', nTrialsInBlock));
                    tr.pairIdx = order(pi);
                    if isempty(trials), trials = tr; else, trials(end+1) = tr; end %#ok<AGROW>
                else
                    % Each pair yields two pricing trials, one per option,
                    % presented in random order.
                    items = [p.moneyIdx, p.qualityIdx];
                    isMoney = [true, false];
                    o2 = randperm(rs, 2);
                    for q = o2
                        trialInBlock = trialInBlock + 1;
                        [tr, log, gazeStore] = runPriceTrial(window, cfg, geom, et, ...
                            log, gazeStore, inWindow, tex, sel, A, items(q), ...
                            isMoney(q), win, domain, rs, ...
                            struct('block', b, 'nBlocks', numel(blocks), 'level', lvl, ...
                                   'trialInBlock', trialInBlock, 'nTrialsInBlock', nTrialsInBlock));
                        tr.pairIdx = order(pi);
                        if isempty(trials), trials = tr; else, trials(end+1) = tr; end %#ok<AGROW>
                    end
                end
                utils.checkForQuit;
            end
        end

        Screen('Close', struct2texlist(tex));

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
        dataMat.(domain).events        = utils.eventLog('table', log);
        dataMat.(domain).reversals     = scoreReversals(trials);
        dataMat.(domain).aoiLayouts    = aoiLayouts;

        % Blocking disk writes from here. See the matching note in
        % auction_task.m -- a frozen screen reads as a crash.
        savingFact = utils.didYouKnow(run.seed);
        utils.savingScreen(window, cfg, 0.10, 'Collecting eye-tracking samples', savingFact);

        clockSync.end = utils.clockSync(et);
        gaze = utils.gazeBuffer('flush', et, gazeStore);
        if ~isempty(gaze)
            utils.savingScreen(window, cfg, 0.25, 'Writing eye-tracking data', savingFact);
            gf = strrep(run.gazeFile, '_gaze.mat', sprintf('_%s_gaze.mat', domain));
            eyeTracking = dataMat.eyeTracking; %#ok<NASGU>
            save(gf, 'gaze', 'clockSync', 'eyeTracking', '-v7.3');
            dataMat.(domain).gazeFile = gf;
            fprintf('Saved %d gaze samples.\n', numel(gaze));
        end
        dataMat.(domain).clockSync = clockSync;
        utils.savingScreen(window, cfg, 0.55, 'Releasing images', savingFact);
    end

    showMessage(window, cfg, 'Thank you. That is the end of this task.', 2.5);

    savingFact = utils.didYouKnow(run.seed);
    utils.savingScreen(window, cfg, 0.75, 'Writing trial data', savingFact);
    utils.saveRun(sess, run, dataMat, buildTrialTable(dataMat));
    utils.savingScreen(window, cfg, 1.00, 'Done - thank you', savingFact);
    WaitSecs(1.2);

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
    % sprintf, not string concatenation -- the old ['CRASH_SAVE_' subjectNum]
    % concatenated a number into a char array and produced a garbage
    % filename at exactly the moment the file mattered most.
    crashFile = fullfile(cfg.paths.crashed, sprintf('%s_crash.mat', run.runId));
    save(crashFile, 'ME', 'dataMat', 'sess', 'run');
    fprintf(2, '\nCrashed. Partial data saved to:\n  %s\n', crashFile);
    if standalone, utils.endRun(sess, run, 'crashed'); end
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

log = utils.eventLog('add', log, 'choice_onset', GetSecs, ...
    struct('leftIdx', leftIdx, 'rightIdx', rightIdx, 'level', blockInfo.level));

% Fixation-start gate: known gaze anchor at trial onset, self-paced start.
% t0 becomes the fixation click's own flip time -- the true stimulus-locked
% reference for RT -- rather than whenever this function was entered.
[t0, log] = utils.awaitFixationStart(window, cfg, log, struct( ...
    'trial', blockInfo.trialInBlock, 'nTrials', blockInfo.nTrialsInBlock, ...
    'label', sprintf('%s - choose - %d attributes', domain, blockInfo.level)));

while true
    % Trial screen stays clean -- no HUD here. Progress and condition
    % (block, level, task type) were already shown on the fixation-start
    % screen above; showing them again here would be exactly the kind of
    % off-task, gaze-competing chrome we're trying to avoid during the
    % actual response.
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
    Screen('Flip', window);
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

interTrial(window, cfg);

end


%% ======================================================================
function [tr, log, gazeStore] = runPriceTrial(window, cfg, geom, et, log, ...
    gazeStore, stimTbl, tex, sel, A, idx, isMoneyOption, win, domain, rs, blockInfo)
%RUNPRICETRIAL  One option, priced on the continuous scale.
%
%   The card stays on screen throughout. The old version blanked it once
%   the participant clicked "ready to price" (clearAttrs), which removed the
%   very anchor the multiple-anchor model addition exists to study, and
%   turned the trial into a memory task.

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

log = utils.eventLog('add', log, 'price_onset', GetSecs, ...
    struct('itemIdx', idx, 'level', blockInfo.level, ...
           'isMoneyOption', double(isMoneyOption)));

scaleMin = win.scaleMin;
scaleMax = win.scaleMax;

% Arc lives entirely within its own zone from utils.layoutCardAndArc -- side by
% side with the card, not stacked beneath it, so there is no vertical
% competition between the price scale and the attribute content.
cx = (L.arcLeft + L.arcRight) / 2;
cy = L.arcBot - 60;
outerR = min((L.arcRight - L.arcLeft)/2 - 30, (L.arcBot - L.arcTop) * 0.55);
innerR = outerR * 0.80;
% Five, not seven -- see the matching note in auction_task.m.
nTicks = 5;
tickVals = linspace(scaleMin, scaleMax, nTicks);

% The advertised figure for this option, for the scale marker below.
itemValue = stimTbl.(A.valueVar)(idx);

% Fixation-start gate: known gaze anchor at trial onset, self-paced start.
% t0 becomes the fixation click's own flip time, the true stimulus-locked
% RT reference, rather than whenever this function happened to be entered.
[t0, log] = utils.awaitFixationStart(window, cfg, log, struct( ...
    'trial', blockInfo.trialInBlock, 'nTrials', blockInfo.nTrialsInBlock, ...
    'label', sprintf('%s - price - %d attributes', domain, blockInfo.level)));

% Randomised start -- see the long note in auction_task.m's getBid. A
% constant midpoint is a nuisance anchor; the advertised value would be a
% confounded one; random is the only start that cannot bias an estimate.
% Recorded as tr.startFrac so residual anchoring stays testable.
startFrac = rand(rs);
tr.startFrac = startFrac;
SetMouse(round(cx + innerR*cos(pi + startFrac*pi)), ...
         round(cy + innerR*sin(pi + startFrac*pi)), window);
while true
    % Response screen stays clean -- no HUD. Same rationale as the choice
    % trial: progress/condition info already shown on the fixation screen,
    % nothing here should compete with the card and scale for gaze.
    Screen('FillRect', window, s.bg);

    Screen('TextFont', window, s.fontContent);
    Screen('TextSize', window, s.sizeHeading);
    DrawFormattedText(window, q, 'center', L.promptY, s.text);

    utils.drawOptionCard(window, cfg, L.cardRect, stimTbl, tex, sel, idx);

    % Arc
    a = linspace(pi, 2*pi, 160);
    % s.track, not s.border -- see the matching note in auction_task.m.
    Screen('DrawLines', window, ...
        [reshape([cx+outerR*cos(a); cx+innerR*cos(a)],1,[]); ...
         reshape([cy+outerR*sin(a); cy+innerR*sin(a)],1,[])], 4, s.track);

    Screen('TextSize', window, s.sizeLabel);
    for k = 1:nTicks
        ang = pi + (k-1)/(nTicks-1)*pi;
        Screen('DrawLine', window, s.textDim, ...
            cx+innerR*cos(ang), cy+innerR*sin(ang), ...
            cx+outerR*cos(ang), cy+outerR*sin(ang), s.hairlinePx);
        lbl = utils.formatCurrency(tickVals(k), 'compact');
        bnd = Screen('TextBounds', window, lbl);
        DrawFormattedText(window, lbl, cx+(outerR+38)*cos(ang)-bnd(3)/2, ...
            cy+(outerR+38)*sin(ang), s.textDim);
    end

    % Where the advertised figure sits on this scale. See the
    % methodological note at the matching block in auction_task.m -- the
    % anchoring concern is if anything sharper here, because the listed
    % figure is also on the card a few centimetres away.
    if cfg.display.showValueMarker
        mFrac = (itemValue - scaleMin) / max(scaleMax - scaleMin, eps);
        if isfinite(mFrac) && mFrac >= 0 && mFrac <= 1
            mAng = pi + mFrac*pi;
            Screen('DrawLine', window, s.marker, ...
                cx + (innerR-10)*cos(mAng), cy + (innerR-10)*sin(mAng), ...
                cx + (outerR+10)*cos(mAng), cy + (outerR+10)*sin(mAng), 4);
            mLbl = utils.ternary(strcmpi(domain,'houses'), 'listed', 'offered');
            bnd = Screen('TextBounds', window, mLbl);
            DrawFormattedText(window, mLbl, ...
                cx + (innerR-32)*cos(mAng) - bnd(3)/2, ...
                cy + (innerR-32)*sin(mAng), s.marker);
        end
    end

    [mx, my, buttons] = utils.getMouse(window);
    ang = atan2(max(cy - my, 0), mx - cx);
    frac = min(max(1 - ang/pi, 0), 1);
    if ~isfinite(frac), frac = 0.5; end   % defensive: never let a bad mouse
                                           % read reach a Screen() coordinate
    curVal = scaleMin + frac*(scaleMax - scaleMin);

    px = cx + innerR*cos(pi + frac*pi);
    py = cy + innerR*sin(pi + frac*pi);
    Screen('DrawDots', window, [px; py], 18, s.interactive, [], 2);

    % Snap to the displayed resolution -- see utils.snapValue.
    curVal = utils.snapValue(curVal, A.priceStyle);

    % Above the arc rather than inside its bowl, matching auction_task.
    Screen('TextSize', window, s.sizeTitle);
    txt = utils.formatCurrency(curVal, A.priceStyle);
    bnd = Screen('TextBounds', window, txt);
    DrawFormattedText(window, txt, cx - bnd(3)/2, ...
        max(L.arcTop - 6, cy - outerR - 52), s.money);

    gazeStore = utils.gazeBuffer('poll', et, gazeStore);
    if et.showGaze && ~isempty(gazeStore.latest)
        drawGazeDot(window, cfg, gazeStore.latest);
    end
    Screen('Flip', window);
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

interTrial(window, cfg);

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
function rev = scoreReversals(trials)
%SCOREREVERSALS  Per pair: chose one option but priced the other higher.
%
%   The classic signature. Computed here so it appears in the saved file
%   rather than being reconstructed later from raw trials.

rev = struct('pairIdx', {}, 'level', {}, 'choseMoney', {}, ...
             'pricedMoneyHigher', {}, 'reversal', {});

if isempty(trials), return; end
levels = unique([trials.level]);

for L = levels
    sub = trials([trials.level] == L);
    ch  = sub(strcmp({sub.taskType}, 'choice'));
    pr  = sub(strcmp({sub.taskType}, 'price'));

    for k = 1:numel(ch)
        if ch(k).timedOut || isnan(ch(k).choseMoney)
            continue
        end
        pIdx = ch(k).pairIdx;
        pp = pr([pr.pairIdx] == pIdx);
        if numel(pp) < 2, continue; end

        m = pp([pp.isMoneyOption]);
        q = pp(~[pp.isMoneyOption]);
        if isempty(m) || isempty(q) || isnan(m(1).price) || isnan(q(1).price)
            continue
        end

        pricedMoneyHigher = m(1).price > q(1).price;
        r = struct();
        r.pairIdx           = pIdx;
        r.level             = L;
        r.choseMoney        = ch(k).choseMoney;
        r.pricedMoneyHigher = pricedMoneyHigher;
        r.reversal          = (ch(k).choseMoney ~= pricedMoneyHigher);
        rev(end+1) = r; %#ok<AGROW>
    end
end

end


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
% See the note in auction_task.m -- 'q' always worked, participants
% were just never told.
DrawFormattedText(window, [body quitNotice()], 'center', 'center', ...
    s.text, 60, 0, 0, 1.6);
Screen('Flip', window);
utils.waitForClick(window);
end


%% ======================================================================
function interTrial(window, cfg)
s = cfg.style;
Screen('FillRect', window, s.bg);
scr = Screen('Rect', window);
Screen('DrawDots', window, [scr(3)/2; scr(4)/2], 10, s.textDim, [], 2);
Screen('Flip', window);
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
