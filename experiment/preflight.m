function report = preflight(participant, sessionNum, varargin)
%PREFLIGHT  Print the resolved battery plan and non-PTB readiness checks.
%
%   report = preflight(participant, sessionNum, 'rig', 'lab', 'runChecks', false)
%   Resolves the run_battery.m schedule without opening a Psychtoolbox window.

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

p = inputParser;
p.addRequired('participant', @(x) isnumeric(x) && isscalar(x));
p.addRequired('sessionNum',  @(x) isnumeric(x) && isscalar(x));
p.addParameter('projRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('rig', 'lab', @(x) ismember(lower(char(x)), {'lab','dev'}));
p.addParameter('testing', false, @islogical);
p.addParameter('trialsPerCell', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && x >= 1 && x == round(x)));
p.addParameter('jobsArm', 'synthetic', @(x) ismember(lower(char(x)), ...
    {'synthetic','ecological','attenuated'}));
p.addParameter('forceDomain', '', @(x) ischar(x) || isstring(x));
p.addParameter('taskOrder', [], @(x) isempty(x) || ...
    (isnumeric(x) && isscalar(x) && x >= 1 && x <= 6 && x == round(x)));
p.addParameter('runChecks', true, @islogical);
p.addParameter('windowRect', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 4));
p.parse(participant, sessionNum, varargin{:});
opt = p.Results;

cfg = utils.config('projRoot', opt.projRoot, 'rig', opt.rig, ...
    'testing', opt.testing, 'jobsArm', opt.jobsArm, ...
    'trialsPerCell', opt.trialsPerCell);
rows = utils.batteryPlan(participant, sessionNum, opt.forceDomain, opt.taskOrder);

winRect = opt.windowRect;
if isempty(winRect)
    winRect = [0 0 cfg.geom.widthPx cfg.geom.heightPx];
end
geom = cfg.geom;
geom.widthPx = winRect(3) - winRect(1);
geom.heightPx = winRect(4) - winRect(2);

report = struct();
report.participant = participant;
report.sessionNum = sessionNum;
report.rig = cfg.rig;
report.jobsArm = cfg.stimuli.jobsArm;
report.resolvedPlan = [rows{:}];
report.estimatedMinutes = estimateMinutes(cfg, rows);
report.pathOK = [];
report.imageReports = struct();
report.aoiReports = struct();
report.allAoiOK = true;

fprintf('\n=== Housing/Wages preflight ===\n');
fprintf('Participant %d | session %d | rig %s | jobs arm %s\n\n', ...
    participant, sessionNum, cfg.rig, cfg.stimuli.jobsArm);
if ~isempty(cfg.rehearsal.trialsPerCell)
    fprintf(2, ['REHEARSAL: %d trial(s) per design cell. Counts below are the\n' ...
                '           SHORT ones -- a full study run is %d auction trials\n' ...
                '           and %d/%d contdc pairs per level (jobs/houses).\n\n'], ...
        cfg.rehearsal.trialsPerCell, cfg.auction.nTrials, ...
        cfg.contdc.nPairs.jobs, cfg.contdc.nPairs.houses);
end

fprintf('-- resolvedPlan --\n');
for k = 1:numel(rows)
    r = rows{k};
    fprintf('  %d. %-8s %-8s session %d\n', k, r.task, ...
        strjoin(r.domains, '+'), r.session);
end

fprintf('\n-- design knobs --\n');
fprintf('  auction trials:            %d\n', cfg.auction.nTrials);
fprintf('  auction blocks:            %d (%d trials each, competition blocked)\n', ...
    cfg.auction.nBlocks, cfg.auction.nTrials / cfg.auction.nBlocks);
fprintf('  auction options/trial:     %d\n', cfg.auction.nOptionsPerTrial);
fprintf('  auction trial timeout:     %.0f sec\n', cfg.auction.trialTimeoutSec);
fprintf('  auction practice episodes: 1 before real trials\n');
fprintf('  attr levels:               %s\n', mat2str(cfg.attrLevels));
fprintf('  contdc pairs houses/jobs:  %d / %d\n', ...
    cfg.contdc.nPairs.houses, cfg.contdc.nPairs.jobs);
fprintf('  contdc timeouts:           choice %.0fs, price %.0fs\n', ...
    cfg.contdc.choiceTimeoutSec, cfg.contdc.priceTimeoutSec);
fprintf('  cross-level reuse:         %s\n', ...
    utils.ternary(cfg.contdc.allowCrossLevelReuse, 'allowed', 'blocked'));
fprintf('  force domain:              %s\n', ...
    utils.ternary(isempty(char(opt.forceDomain)), '(none)', char(opt.forceDomain)));
fprintf('  estimated duration:        %.1f minutes\n', report.estimatedMinutes);

if ~opt.runChecks
    fprintf('\nChecks skipped (runChecks=false).\n\n');
    return
end

try
    report.pathOK = utils.verifyPaths(cfg);
catch ME
    report.pathOK = false;
    report.pathError = ME.message;
    fprintf(2, 'Path check failed: %s\n', ME.message);
end

allDomains = {};
for k = 1:numel(rows)
    allDomains = [allDomains, rows{k}.domains]; %#ok<AGROW>
end
allDomains = unique(allDomains);

for k = 1:numel(allDomains)
    domain = allDomains{k};
    try
        report.imageReports.(domain) = utils.checkImages(cfg, domain);
    catch ME
        report.imageReports.(domain) = struct('ok', false, ...
            'checked', 0, 'missing', NaN, 'error', ME.message);
        fprintf(2, 'Image check failed for %s: %s\n', domain, ME.message);
    end
    try
        report.aoiReports.(domain) = checkDomainAOIs(cfg, geom, winRect, domain);
        report.allAoiOK = report.allAoiOK && domainAoiOK(report.aoiReports.(domain));
    catch ME
        report.aoiReports.(domain) = struct('ok', false, 'error', ME.message);
        report.allAoiOK = false;
        fprintf(2, 'AOI check failed for %s: %s\n', domain, ME.message);
    end
end
fprintf('Preflight finished.\n\n');

end

function minutes = estimateMinutes(cfg, rows)
seconds = 0;
for k = 1:numel(rows)
    r = rows{k};
    for d = 1:numel(r.domains)
        domain = lower(r.domains{d});
        switch r.task
            case 'auction'
                % Must mirror the rehearsal override auction_task applies.
                nTrials = cfg.auction.nTrials;
                if ~isempty(cfg.rehearsal.trialsPerCell)
                    nTrials = cfg.rehearsal.trialsPerCell * 2;
                end
                seconds = seconds + cfg.auction.trialTimeoutSec * nTrials;
                seconds = seconds + cfg.auction.feedbackSec * nTrials;
                seconds = seconds + cfg.auction.trialTimeoutSec; % practice
                seconds = seconds + 90; % instructions, checks, transitions
                seconds = seconds + 30 * max(0, cfg.auction.nBlocks - 1);
            case 'contdc'
                nPairs = cfg.contdc.nPairs.(domain);
                if ~isempty(cfg.rehearsal.trialsPerCell)
                    nPairs = cfg.rehearsal.trialsPerCell;
                end
                nLevels = numel(cfg.attrLevels);
                seconds = seconds + nLevels * nPairs * cfg.contdc.choiceTimeoutSec;
                seconds = seconds + nLevels * nPairs * 2 * cfg.contdc.priceTimeoutSec;
                seconds = seconds + nLevels * nPairs * 3 * cfg.contdc.itiSec;
                seconds = seconds + 120; % instructions and block intros
            case 'pref'
                % Trial counts and pacing must mirror preference_task.m.
                switch domain
                    case 'houses'
                        seconds = seconds + 60 * (4 + 1.1) + 160 * (3 + 1.1) + 60;
                    case 'jobs'
                        seconds = seconds + 160 * (2.5 + 1.1) + 30;
                end
        end
    end
end
minutes = seconds / 60;
end

function out = checkDomainAOIs(cfg, geom, winRect, domain)
A = utils.attributes(domain);
ratings = linspace(0.9, 0.1, A.nPool);
out = struct();

if strcmpi(domain, 'houses') || strcmpi(domain, 'jobs')
    selAuction = utils.selectAttributes(A, cfg.auction.nAttrs, ratings, ...
        cfg.attrMethod, false);
    a = auctionAOIs(winRect, cfg, geom, selAuction);
    [out.auctionGrid.ok, out.auctionGrid.report] = ...
        utils.checkAOIs(a.gridRects, a.gridNames, geom, true);
    [out.auctionDetail.ok, out.auctionDetail.report] = ...
        utils.checkAOIs(a.detailRects, a.detailNames, geom, true);
    [out.auctionBid.ok, out.auctionBid.report] = ...
        utils.checkAOIs(a.bidRects, a.bidNames, geom, true);
end

for lvl = cfg.attrLevels
    key = sprintf('lvl%d', lvl);
    sel = utils.selectAttributes(A, lvl, ratings, cfg.attrMethod, ...
        lvl == max(cfg.attrLevels) && cfg.lateAtMaxOnly);
    c = contdcAOIs(winRect, cfg, geom, sel);
    [out.contdc.(key).choice.ok, out.contdc.(key).choice.report] = ...
        utils.checkAOIs(c.choiceRects, c.choiceNames, geom, true);
    [out.contdc.(key).price.ok, out.contdc.(key).price.report] = ...
        utils.checkAOIs(c.priceRects, c.priceNames, geom, true);
end
end

function L = auctionAOIs(winRect, cfg, geom, sel)
s = cfg.style;
W = winRect(3); H = winRect(4);
hudH = s.hud.enabled * s.hud.heightPx;
nCols = 3; nRows = 2;
pad = 48;
cellW = floor(W / nCols);
cellH = floor((H - hudH) / nRows);
boxRects = zeros(4, nCols*nRows);
k = 0;
for r = 1:nRows
    for c = 1:nCols
        k = k + 1;
        boxRects(:,k) = [ (c-1)*cellW + pad; ...
                          hudH + (r-1)*cellH + pad; ...
                          c*cellW - pad; ...
                          hudH + r*cellH - pad ];
    end
end

L.gridRects = zeros(4, 2*size(boxRects,2));
L.gridNames = cell(1, 2*size(boxRects,2));
for k = 1:size(boxRects,2)
    bx = boxRects(:,k);
    bh = bx(4)-bx(2);
    imgRect = [bx(1)+16; bx(2)+16; bx(3)-16; bx(2)+round(bh*0.48)];
    txtRect = [bx(1)+16; bx(2)+round(bh*0.68); bx(3)-16; bx(4)-16];
    L.gridRects(:, 2*k-1) = imgRect;
    L.gridRects(:, 2*k) = txtRect;
    L.gridNames{2*k-1} = sprintf('box%d_img', k);
    L.gridNames{2*k} = sprintf('box%d_txt', k);
end

% Not re-implemented here: the same functions auction_task calls.
detail = utils.layoutDetailAOIs(winRect, cfg, sel);
L.detailRects = detail.rects;
L.detailNames = detail.names;

% Bid screen shows the card beside the scale, so its attribute AOIs need checking too.
bidL = utils.layoutCardAndArc(winRect, cfg, geom, numel(sel.shown));
bid = utils.cardAOIs(cfg, bidL.cardRect, sel, 'bid');
L.bidRects = bid.rects;
L.bidNames = bid.names;
end

function L = contdcAOIs(winRect, cfg, geom, sel)
s = cfg.style;
W = winRect(3); H = winRect(4);
hudH = s.hud.enabled * s.hud.heightPx;
top = hudH + 96;
bot = H - 50;
gap = geom.targetSepPx;
marg = 70;
cardW = floor((W - 2*marg - gap) / 2);
cards = [marg, marg + cardW + gap; top, top; marg + cardW, W - marg; bot, bot];
left = utils.cardAOIs(cfg, cards(:,1), sel, 'choice_left');
right = utils.cardAOIs(cfg, cards(:,2), sel, 'choice_right');
L.choiceRects = [left.rects, right.rects];
L.choiceNames = [left.names, right.names];

% Price card layout mirrors the auction bid screen (utils.layoutCardAndArc).
priceL = utils.layoutCardAndArc(winRect, cfg, geom, numel(sel.shown));
price = utils.cardAOIs(cfg, priceL.cardRect, sel, 'price');
L.priceRects = price.rects;
L.priceNames = price.names;
end

function ok = domainAoiOK(r)
ok = true;
if isfield(r, 'auctionGrid'), ok = ok && r.auctionGrid.ok; end
if isfield(r, 'auctionDetail'), ok = ok && r.auctionDetail.ok; end
if isfield(r, 'auctionBid'), ok = ok && r.auctionBid.ok; end
if isfield(r, 'contdc')
    lvls = fieldnames(r.contdc);
    for i = 1:numel(lvls)
        x = r.contdc.(lvls{i});
        ok = ok && x.choice.ok && x.price.ok;
    end
end
end
