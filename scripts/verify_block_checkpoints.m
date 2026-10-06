function verify_block_checkpoints
% Run the headless checkpoint tests; PTB/rig validation is separate.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'experiment'));
sdk = getenv('HW_TOBII_ROOT');
if ~isempty(sdk), addpath(genpath(sdk)); end
results = runtests(fullfile(root, 'scripts', 'tests'));
disp(results);
assert(~isempty(results) && all([results.Passed]), 'hw:tests:failed', ...
    'Block-checkpoint tests did not all pass.');
end
