function tex = loadStimulusTextures(window, cfg, stimTbl, A, idxNeeded, showProgress)
%UTILS.LOADSTIMULUSTEXTURES  Load identity images for specific stimuli only.
%
%   tex = utils.loadStimulusTextures(window, cfg, stimTbl, A, idxNeeded)
%   tex = utils.loadStimulusTextures(window, cfg, stimTbl, A, idxNeeded, true)
%
%   Loads textures ONLY for the rows in idxNeeded, not every stimulus in
%   the sampled window. A domain typically samples 30-100 candidate
%   stimuli (utils.sampleWindow's minN and up) but only a much smaller
%   subset of those ever actually appears in a trial plan or pair set --
%   loading images for every candidate, for houses' 6 photos each, over a
%   network share, was both slow and the reason texture loading was
%   visible as a pause between blocks.
%
%   Pass idxNeeded as the UNION of every stimulus index that will actually
%   be shown across the whole domain (every pair's money/quality index, or
%   every trial plan's stimIdx) -- compute this BEFORE calling, so loading
%   happens once, up front, rather than repeatedly per block.
%
%   showProgress (default true) draws a simple "FETCHING PHOTOS..." bar
%   while loading, since this can take a few seconds.

if nargin < 6, showProgress = true; end

tex = struct();
imgVars = {};
for k = 1:numel(A.identity)
    if strcmp(A.identity(k).kind, 'image')
        imgVars{end+1} = A.identity(k).var; %#ok<AGROW>
    end
end
if isempty(imgVars)
    return   % this domain has no image-kind identity attributes (jobs)
end

idxNeeded = unique(idxNeeded(:))';
idxNeeded = idxNeeded(idxNeeded >= 1 & idxNeeded <= height(stimTbl));

total = numel(imgVars) * numel(idxNeeded);
done  = 0;
missing = {};

if showProgress
    drawLoadingScreen(window, cfg, 0, max(total,1));
end

for w = 1:numel(imgVars)
    v = imgVars{w};
    handles = nan(height(stimTbl), 1);
    if ismember(v, stimTbl.Properties.VariableNames)
        for ii = 1:numel(idxNeeded)
            r = idxNeeded(ii);
            f = stimTbl.(v){r};
            p = fullfile(cfg.paths.images, f);
            if exist(p, 'file')
                try
                    img = imread(p);
                    handles(r) = Screen('MakeTexture', window, img);
                catch ME
                    missing{end+1} = sprintf('%s (load failed: %s)', p, ME.message); %#ok<AGROW>
                end
            else
                missing{end+1} = p; %#ok<AGROW>
            end
            done = done + 1;
            if showProgress && mod(done, 5) == 0
                drawLoadingScreen(window, cfg, done, total);
            end
        end
    end
    tex.(v) = handles;
end

if showProgress
    drawLoadingScreen(window, cfg, total, max(total,1));
end

if ~isempty(missing)
    n = numel(missing);
    fprintf(2, '\n%d of %d image loads failed. First few:\n', n, total);
    for k = 1:min(5, n)
        fprintf(2, '  %s\n', missing{k});
    end
    fprintf(2, ['If every load failed, check cfg.paths.images and confirm the\n' ...
                'CSV''s filename columns match real files there exactly (including\n' ...
                'case and extension) -- try utils.checkImages(cfg, domain) for a\n' ...
                'full report without needing to run the task.\n\n']);
end

end


function drawLoadingScreen(window, cfg, done, total)
s = cfg.style;
Screen('FillRect', window, s.bg);
scr = Screen('Rect', window);
cx = scr(3)/2; cy = scr(4)/2;

Screen('TextFont', window, s.fontChrome);
Screen('TextSize', window, s.sizeHeading);
DrawFormattedText(window, 'FETCHING PHOTOS...', 'center', cy - 50, s.money);

barW = 420; barH = 22;
frac = min(1, done / max(total, 1));
Screen('FrameRect', window, s.border, [cx-barW/2, cy, cx+barW/2, cy+barH], 2);
if frac > 0
    Screen('FillRect', window, s.interactive, ...
        [cx-barW/2, cy, cx-barW/2 + barW*frac, cy+barH]);
end

Screen('TextFont', window, s.fontContent);
Screen('TextSize', window, s.sizeLabel);
DrawFormattedText(window, sprintf('%d / %d', done, total), 'center', cy + 40, s.textDim);

Screen('Flip', window);
end
