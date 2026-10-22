# You can ignore this folder

Nothing in a session depends on you running anything here. These tests run
**before code is pushed to main** — by whoever is pushing — so by the time a
rig pulls, they have already passed. Running a session never executes them.

The one place an operator meets them is stage 3 of `rig_checks`, which runs
the suite as a diagnostic after a pull. You do not need to understand its
output: it ends in PASSED or FAILED, and the job is to send back the log file
it names.

If you are changing experiment code: `matlab -batch
"run('scripts/verify_block_checkpoints.m')"` runs everything headlessly (no
tracker, no display needed; one SDK case skips off the rig). Keep it green
before you push — that is what lets everyone else ignore this folder.
