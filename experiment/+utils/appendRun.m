function appendRun(manifestFile, entry)
%UTILS.APPENDRUN  Atomically append one run entry to a participant manifest.

M = load(manifestFile, 'manifest');
manifest = M.manifest;
manifest.runs(end+1) = entry; %#ok<NASGU>

tmp = [manifestFile '.tmp'];
save(tmp, 'manifest');
movefile(tmp, manifestFile, 'f');

end
