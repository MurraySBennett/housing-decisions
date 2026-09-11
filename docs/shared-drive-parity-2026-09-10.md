# Shared-drive parity audit — 2026-09-10

Compared local repo `experiment/` against:

```
\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment
```

Excluded participant/runtime data, `house_images/`, and archived code.

## Result

- `run_battery.m` matched the shared drive.
- Raw stimulus CSVs matched by SHA256:
  - `stimuli/house_stimuli.csv`
  - `stimuli/job_stimuli.csv`
- The shared drive had the jobs preparation pipeline missing from the repo:
  - `stimuli/prepare_stimuli.py`
  - `stimuli/README.md`
  - `stimuli/stimgen/configs/*.json`
  - `stimuli/prepared/job_stimuli_<arm>.csv`
  - `stimuli/prepared/job_stimuli_<arm>_provenance.json`
- The shared drive also had later source changes imported here:
  - fixed identity-photo and attribute-slot geometry
  - `+utils/attrSlotRects.m`
  - domain-specific continuous/DC pair counts and cross-level reuse control

## Still fixed after import

The shared-drive copy still carried several known bugs. These were fixed in
the repo after import:

- auction no-bid trials now initialize `trial.bidRT = NaN`
- rejected auction bids recompute `now` before setting vacancy gaps
- bid cancellation uses right-click and is visible on screen
- continuous/DC uses a private `RandStream` seeded from `run.seed`
- VAS randomization accepts the task stream instead of consuming global RNG
- timed-out/NaN choices are skipped when scoring preference reversals
- `sampleWindow` returns indices into the original, unfiltered table
- incentive payout text reports `pick.trial`, not nonexistent `pick.block`
