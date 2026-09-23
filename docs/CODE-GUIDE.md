# Code guide — how this project works

A practical orientation for lab members. You do not need to read the code to
work on this project; this document plus `docs/ra-setup-deck.html` (the
session-running guide) should cover almost everything. When something here
does not match what you see, ask Murray rather than guessing.

## The study in one paragraph

Participants value houses and jobs under eye-tracking. In the **auction
task**, options arrive on a market and the participant inspects, rejects, and
eventually bids on one (a second-price auction, so honest bids are the best
strategy). In the **continuous discrete-choice (contdc) task**, the same kinds
of options are both *chosen between* and *priced*, which is what lets us
measure preference reversals — cases where choosing and pricing disagree. A
third short **preference task** collects style preferences directly: ratings
and side-by-side choices of house photos, and side-by-side choices between
jobs shown as industry + job title. Each session covers one domain (jobs or
houses); every participant does two sessions on separate days.

## What runs what

Everything starts from one file:

- **`experiment/run_battery.m`** — the only file anyone edits on a session
  day, and only its switches at the top (participant handling is prompted).
  It figures out which tasks this participant gets, in which order, runs
  them back to back, and writes all the data. Task order is counterbalanced
  automatically from the participant number — never reorder tasks by hand.
- **`experiment/preflight.m`** — run this before a session to check the rig:
  it validates screen geometry and prints the planned schedule and an
  estimated duration.
- **`scripts/verify_matlab.m`** — a quick self-check to run first on a new
  machine or after the code changes.
- **`experiment/demo_battery.m`** — a compressed walk-through of the tasks
  for showing people. Never for data collection.

The three task files (`auction_task.m`, `continuous_DC_task.m`,
`preference_task.m`) and the `experiment/+utils/` folder are the machinery
underneath. `+utils` is a MATLAB "package": `utils.something(...)` in the
code means "the function in `+utils/something.m`".

## Where things live

| Place | What it is |
|---|---|
| `experiment/` | The live experiment code |
| `experiment/stimuli/` | Stimulus lists (CSVs, tracked in git) and the house image set (605MB, **not** in git — it lives on the lab share) |
| `experiment/Data/` | Participant data (**not** in git, never committed) |
| `analysis/` | R pipeline that reads the run CSVs and produces figures and an integrity report |
| `docs/` | Documents like this one, the RA deck, meeting notes, the design review |
| `reference/` | Other people's code kept for reference — read-only, mostly not ours |

## The data a session produces

Every task run writes, under `experiment/Data/`:

- a `.mat` file with the full record (`dataMat`), one per task per session;
- a `.csv` of trial-level data (the thing the R pipeline reads);
- a gaze `.mat` per domain when eye-tracking is on;
- a session manifest (`Data/sessions/`) recording which runs happened, so a
  participant's whole history is reconstructable;
- a timing CSV (`Data/sessions/sub-XXXXX_ses-NN_timing.csv`) breaking down
  how long each task and each section (instructions, practice, trials, ...)
  took.

Filenames carry participant, session, task, and domain, e.g.
`sub-00012_ses-01_task-auction_dom-jobs_20260921_143205.csv`.

## Running the analysis

From the repo root, with R installed:

```
Rscript analysis/R/run_all.R
```

It prints a data-integrity report (read it — it flags malformed cells) and
writes descriptive figures. The analysis runs on any OS with R — paths are
resolved relative to the script, nothing is Windows-specific. The two
`scripts/*.ps1` files are the exception: they are deliberately Windows-only
(the lab share and rig are Windows); on a Mac or Linux machine you work from
exported CSVs instead. Running the experiment itself requires the Windows
rig (MATLAB, Psychtoolbox, the Tobii SDK, and the image set live there).

## Things that are deliberate (do not "fix" these)

- **The dark colour scheme.** A light theme would flood the pupil and ruin
  pupillometry. The theme is not a style preference.
- **Second-price auction wording.** The instructions state the payment rule
  because that is what makes truthful bidding optimal.
- **`SkipSyncTests` is on.** A property of these machines' graphics drivers,
  not a shortcut.
- **Stimulus values that repeat or look "jittered".** The stimulus lists are
  generated with controlled correlations and windowing; regenerating or
  editing them by hand breaks the design.

## If a session crashes

The battery saves a crash file under `Data/Crashes/` and offers to continue
with the next task. Note what was on screen and tell Murray; do not delete
anything. Completed runs are already saved — a crash never loses earlier
tasks.

## For anyone changing code

`bash scripts/verify_static.sh` must pass before anything is deployed — it
pins dozens of easy-to-break invariants. The first run of any change happens
at the rig via `scripts/verify_matlab.m`, because the development machines
have no MATLAB. Deployment to the lab share is `scripts/deploy_to_share.ps1`
(it backs up before replacing and never touches data or images).
