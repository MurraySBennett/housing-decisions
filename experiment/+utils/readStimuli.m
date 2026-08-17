function T = readStimuli(cfg, domain)
%UTILS.READSTIMULI  Load a prepared stimulus table with correct types.
%
%   Replaces the bare readtable() calls, which left currency columns as
%   text when they contained '$' or thousands separators, and left the
%   auto-generated readHouse.m importer unused and out of sync.

f = cfg.stimFiles.(lower(domain));
if ~exist(f, 'file')
    error('hw:readStimuli:missing', ...
        ['Stimulus file not found:\n  %s\n' ...
         'Prepared stimulus files are produced by stimgen/prepare_stimuli.py.'], f);
end

opts = detectImportOptions(f);
opts.VariableNamingRule = 'preserve';
T = readtable(f, opts);

% Strip currency formatting from any column that came in as text but is
% numeric underneath.
for k = 1:width(T)
    col = T.(k);
    if iscellstr(col) || isstring(col)
        cleaned = regexprep(string(col), '[\$,]', '');
        num = str2double(cleaned);
        if all(~isnan(num) | strlength(strtrim(cleaned)) == 0)
            T.(k) = num;
        end
    end
end

A = utils.attributes(domain);
if ~ismember(A.valueVar, T.Properties.VariableNames)
    error('hw:readStimuli:noValueVar', ...
        'Stimulus file %s has no "%s" column.', f, A.valueVar);
end

% Strip any directory portion from image filename columns, keeping just
% the bare filename. The CSV can end up with values like
% '.\Stimuli\Images\ext1.png' left over from an old folder layout -- the
% code always joins these against cfg.paths.images itself
% (fullfile(cfg.paths.images, filename)), so a leftover path prefix in the
% CSV makes every single image "missing" even though the actual file is
% sitting right there under the bare name. Doing this once, here, means
% every downstream consumer (loading textures, checking images, anything
% written later) automatically gets a clean filename regardless of
% whatever the CSV happens to contain.
imgVars = {};
for k = 1:numel(A.identity)
    if strcmp(A.identity(k).kind, 'image'), imgVars{end+1} = A.identity(k).var; end %#ok<AGROW>
end
for k = 1:numel(A.pool)
    if strcmp(A.pool(k).kind, 'image'), imgVars{end+1} = A.pool(k).var; end %#ok<AGROW>
end
for v = imgVars
    col = v{1};
    if ~ismember(col, T.Properties.VariableNames), continue; end
    vals = T.(col);
    if ~iscellstr(vals) && ~isstring(vals), continue; end
    vals = cellstr(vals);   % normalizes string arrays and cellstr alike
    for r = 1:numel(vals)
        raw = strtrim(vals{r});
        % fileparts only recognizes '\' as a separator ON WINDOWS -- on
        % any other platform it's treated as a literal character and the
        % path doesn't get split at all. Normalizing to '/' first makes
        % this work the same regardless of what platform is running the
        % code (and makes it something I can actually verify myself).
        raw = strrep(raw, '\', '/');
        [~, base, ext] = fileparts(raw);
        vals{r} = [base ext];
    end
    T.(col) = vals;
end

end
