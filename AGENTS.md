# housing-decisions — agent entry point

A MATLAB + Psychtoolbox eye-tracking battery on housing and wage valuation: a
house auction task and a continuous discrete-choice task. Assembled 2026-08-17
from two earlier projects (`house_jobs`, `housing_wages`).

## Resume here

If you are a new session with no prior context, read in this order and stop
when you can state the next action:

1. `WORK.md` — the live work state: where things left off (`## Now`) and the
   open tasks by stream. **This alone is usually enough.**
2. `docs/review-2026-09-09.md` — the full code review, ~30 findings with file
   and line references. Read it before changing task code.
3. `git log --oneline -10` and `git status --short` — what actually happened
   last, and what is dirty right now.
4. Only if the live state names them: the specific files it names.

Do **not** read the whole repo to "get up to speed." If the live state is not
enough to act, that is a defect in the live state — say so and fix it first.

There is exactly one live state file for this repo: `WORK.md`. Do not create a
second one, a dated copy, or a `-v2`. Overwrite it; git history is the
archive. Maintain it as you work; the conventions — streams, horizons, the
session-end rewrite — are in the global working agreement, not restated here.

## Working agreements

- **`reference/` is other people's code.** `reference/house-choice/` (the `JHO_`
  auction design) and `reference/risky-intertemporal/` are not Murray's and are
  kept for reference while implementing. Do not edit or refactor them.
  `reference/legacy-pricing/` is hers but superseded. `README.md` records what
  is whose — keep it accurate.
- **A second copy of this experiment lives on the OSU share** at
  `\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\`. It is a
  real parallel source of truth, not a backup. Changes that matter should be
  checked against it; `docs/shared-drive-parity-2026-09-10.md` is the record of
  the last pass.
- **House images are ~605MB and are not in git** — see `STIMULI.md`. The files
  that *define* the design (stimulus CSVs, stimgen configs, `prepare_stimuli.py`,
  provenance JSONs) are tracked; the images are not. The `.gitignore` does this
  with `experiment/stimuli/*` plus explicit un-ignores — add new tracked
  stimulus files to that allow-list rather than loosening the rule.
- **Participant data never enters git.** `data/` is ignored and holds gaze and
  session files.
- **This machine cannot run the experiment.** Verification here is static —
  `scripts/verify_static.sh` and `scripts/verify_matlab.m`. Anything needing
  Psychtoolbox, the eye tracker, or the rig display is lab work, and `WORK.md`
  should say so rather than an agent attempting it.
- **The bar is that a session runs seamlessly and pleasantly.** Participant-
  facing behaviour — instructions, comprehension checks, recoverable mis-clicks,
  no dead time — is not polish to be deferred. Bad sessions cost data.
