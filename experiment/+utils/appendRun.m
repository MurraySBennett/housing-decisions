function appendRun(manifestFile, entry)
%UTILS.APPENDRUN  Atomically append one run entry to a participant manifest.

M = load(manifestFile, 'manifest');
manifest = M.manifest;
manifest.runs(end+1) = entry; %#ok<NASGU>

utils.checkpointIO('write', manifestFile, struct('manifest', manifest), true);

end
