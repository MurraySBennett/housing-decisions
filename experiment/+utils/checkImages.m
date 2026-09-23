function report = checkImages(cfg, domain)
%UTILS.CHECKIMAGES  Diagnose why identity images aren't loading.
%   utils.checkImages(utils.config('rig','lab'), 'houses')
%   No PTB needed; reports near-matches (case, extension, whitespace).

A = utils.attributes(domain);
T = utils.readStimuli(cfg, domain);

fprintf('\n=== Image check: %s ===\n\n', domain);
fprintf('cfg.paths.images = %s\n', cfg.paths.images);

report = struct('ok', false, 'checked', 0, 'missing', 0);

if ~exist(cfg.paths.images, 'dir')
    fprintf(2, '  DOES NOT EXIST. Nothing below this will work until this path is right.\n\n');
    return
end

d = dir(cfg.paths.images);
d = d(~[d.isdir]);
fprintf('  exists, contains %d files.\n\n', numel(d));
onDisk = {d.name};

imgVars = {};
for k = 1:numel(A.identity)
    if strcmp(A.identity(k).kind, 'image'), imgVars{end+1} = A.identity(k).var; end %#ok<AGROW>
end
if isempty(imgVars)
    fprintf('%s has no image-kind identity attributes -- nothing to check.\n\n', domain);
    report.ok = true;
    return
end

nSample = min(8, height(T));
nChecked = 0; nMissing = 0;

for w = 1:numel(imgVars)
    v = imgVars{w};
    fprintf('-- %s --\n', v);
    if ~ismember(v, T.Properties.VariableNames)
        fprintf(2, '  column "%s" not found in the stimulus table at all.\n', v);
        continue
    end
    for r = 1:nSample
        raw = T.(v){r};
        f = strtrim(char(raw));
        p = fullfile(cfg.paths.images, f);
        nChecked = nChecked + 1;
        if exist(p, 'file')
            fprintf('  row %2d: OK       %s\n', r, f);
        else
            nMissing = nMissing + 1;
            fprintf('  row %2d: MISSING  "%s"\n', r, f);
            if ~strcmp(f, raw)
                fprintf('           (CSV value had leading/trailing whitespace: "%s")\n', raw);
            end
            cand = onDisk(strcmpi(onDisk, f));
            if isempty(cand)
                [~, base] = fileparts(f);
                cand = onDisk(strncmpi(onDisk, base, numel(base)));
            end
            if ~isempty(cand)
                fprintf('           closest match on disk: %s\n', cand{1});
            else
                fprintf('           no similarly-named file found on disk at all.\n');
            end
        end
    end
    fprintf('\n');
end

report.checked = nChecked;
report.missing = nMissing;
report.ok = (nMissing == 0);

if report.ok
    fprintf(['All %d sampled files found. If images still do not render in the\n' ...
             'task, the mismatch is likely in Screen(''MakeTexture'') itself\n' ...
             '(corrupt file, unsupported format) rather than the path -- check\n' ...
             'for warnings printed during utils.loadStimulusTextures.\n\n'], nChecked);
else
    fprintf(2, ['%d of %d sampled files were missing. Common causes: filenames in\n' ...
                'the CSV do not exactly match files on disk (case, extension,\n' ...
                'stray whitespace), or cfg.paths.images points at the wrong folder.\n\n'], ...
        nMissing, nChecked);
end

end
