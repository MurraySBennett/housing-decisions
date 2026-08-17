# housing-decisions

Housing and wage valuation tasks. A house auction and a continuous
discrete-choice task, run in MATLAB with Psychtoolbox and eye-tracking.

## Layout

| Directory | What it is |
|---|---|
| `experiment/` | **The live experiment.** `auction_task.m`, `continuous_DC_task.m`, `run_battery.m`, and the `+utils` package. |
| `reference/` | **Other people's code**, kept for reference while implementing. Not mine — see below. |
| `docs/` | Articles, grant material, task-design notes |

## What is mine and what is not

This matters, so it is written down rather than remembered.

- **`experiment/`** — mine. The live housing/wages battery.
- **`reference/risky-intertemporal/`** — *not mine.* The risky-intertemporal
  choice design being emulated for the housing/wages task. Note
  `RiskyIntertemp_NoEyetrackingMSB.m`, which is my adaptation of it.
- **`reference/house-choice/`** — *not mine.* The house auction design (`JHO_`)
  that the auction task is being built from. Both the `Experiment/` and
  `Data/SONA/` variants are kept; they differ.
- **`reference/legacy-pricing/`** — mine, superseded. The earlier modular
  MATLAB implementation (`Trial.m`, `Stimulus.m`, `PricingScale.m`, and the
  no-eye-tracking and test variants). Kept because "probably superseded" was not
  a good enough reason to delete it.

## Stimuli

Not in this repository. See [STIMULI.md](STIMULI.md).

## History

Assembled August 2026 from two directories that had drifted apart.
`housing_wages/` turned out to be the live experiment — five months newer than
`house_jobs/pricing/`, with 71 additional files and a deliberately pruned
stimulus set. The folder names implied the reverse; the timestamps settled it.

`house_jobs/` was 3.7GB, of which under 4MB was code worth keeping. The rest was
other people's participant data attached to reference implementations, plus a
web scraper that was never used for the data actually collected.
