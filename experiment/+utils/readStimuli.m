function T = readStimuli(cfg, domain)
%UTILS.READSTIMULI  Load a prepared stimulus table with correct types.
%
%   T = utils.readStimuli(cfg, domain)

f = cfg.stimFiles.(lower(domain));
if ~exist(f, 'file')
    error('hw:readStimuli:missing', ...
        ['Stimulus file not found:\n  %s\n' ...
         'Prepared stimulus files are produced by stimgen/prepare_stimuli.py.'], f);
end

opts = detectImportOptions(f);
opts.VariableNamingRule = 'preserve';
T = readtable(f, opts);

% Strip currency formatting from text columns that are numeric underneath.
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

% Keep bare filenames only: code always joins against cfg.paths.images, so any path prefix in the CSV makes every image "missing".
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
        % fileparts splits '\' only on Windows; normalise to '/' first for cross-platform behaviour.
        raw = strrep(raw, '\', '/');
        [~, base, ext] = fileparts(raw);
        vals{r} = [base ext];
    end
    T.(col) = vals;
end

end
