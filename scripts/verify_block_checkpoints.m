function verify_block_checkpoints
% Run the headless checkpoint tests; PTB/rig validation is separate.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'experiment'));
addpath(fullfile(root, 'scripts'), fullfile(root, 'scripts', 'tests'));
addpath(fullfile(root, 'scripts', 'tests', 'fixtures'));
sdk = getenv('HW_TOBII_ROOT');
if ~isempty(sdk), addpath(genpath(sdk)); end
suite = testsuite(fullfile(root, 'scripts', 'tests'));
% A floor, not an equality -- see scripts/check_checkpoint_test_discovery.py.
% Adding a test must never break the rig check; raise this when cases are removed.
assert(numel(suite) >= 52, 'hw:tests:discovery', 'Expected at least 52 checkpoint test cases, discovered %d.', numel(suite));
results = run(suite);
disp(results);
assert(~isempty(results) && all([results.Passed]), 'hw:tests:failed', ...
    'Block-checkpoint tests did not all pass.');
end
