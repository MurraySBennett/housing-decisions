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
assert(~isempty(results), 'hw:tests:failed', 'No checkpoint tests ran.');
assert(~any([results.Failed]), 'hw:tests:failed', ...
    'Block-checkpoint tests did not all pass.');

% Incomplete is not Failed. A case that filters itself with assumeTrue -- the
% SDK round-trip in test_gaze_codec is the only one today -- is Incomplete but
% not Failed, and the old all([results.Passed]) check therefore made this
% runner permanently red on any machine without the Tobii SDK. That is every
% machine except the rig, which made local iteration impossible and is part of
% why the session tail went uncovered for so long.
%
% On the rig the SDK IS present, so nothing may filter there: with
% HW_TOBII_ROOT set, an incomplete case is a failure.
incomplete = results([results.Incomplete]);
if ~isempty(incomplete)
    names = strjoin({incomplete.Name}, ', ');
    assert(isempty(sdk), 'hw:tests:incomplete', ...
        'HW_TOBII_ROOT is set, so nothing should be skipped, but these were: %s', names);
    fprintf(2, ['\nNOTE: %d case(s) skipped because HW_TOBII_ROOT is not set:\n' ...
                '  %s\n' ...
                'That is expected off the rig. The rig run covers them.\n\n'], ...
        numel(incomplete), names);
end
end
