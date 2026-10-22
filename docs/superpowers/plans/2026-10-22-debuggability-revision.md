# Revise housing-decisions for human debuggability

## Context

Rig debugging is moving to collaborators who work in person
with the RAs and expects linear, obvious MATLAB — any "where/why did X happen"
answerable in 2–3 files. The code is AI-assisted and layered: today "where did
this trial's data get written" is up to 18 hops across 13 files; "the session
crashed — what happened next" is 20 hops across 12 files with two handlers and
two differently-shaped crash dumps.

Decisions made (do not relitigate): scope is `experiment/` + `scripts/` (not
`analysis/R`); behaviour-preserving — same features, same on-disk formats,
tests stay green; exception: the block-checkpoint/recovery/publish machinery
may be simplified aggressively; share replication stays (earlier removal
request withdrawn).

Deployment constraint (verified): `runCheckpoint('open')` fingerprints every
`.m` file into the run signature and refuses cross-version resumption — so
each phase is one push to main, RAs pull only between participants. Gate for
every phase: `matlab -batch "addpath('scripts'); verify_block_checkpoints"`
(floor 52) + `scripts/check_syntax.m` + `python scripts/check_utils_calls.py`.

## Phases — each lands independently, tests green before the next

### Phase 1 — Unify the crash path (tiny diff, pays out on the next crash)
`auction_task.m:480-507` is the canonical catch. Copy it verbatim into
`preference_task.m:216-233` and `continuous_DC_task.m` (~:451) as *identical
visible text* — honest duplication; read one catch and you know all three.
Fixes four preference divergences at once: bare catch that silently skips the
dump on a timing failure; `-v7.3` dump `scripts/read_crash_dump.py` cannot
open; wrong directory; missing `sess`/`run` vars. Dump format everywhere:
default v7 `save`, vars `ME, dataMat, sess, run`, into `cfg.paths.crashed`.
Ownership split stays two-handler: tasks own evidence + teardown + rethrow;
`run_battery.m` owns manifest/mirror/publish/export. Both dumps stay (the task
dump alone holds `dataMat`; run_battery's covers pre-task errors) — one
comment each stating their role. Test: `test_session_tail` gains a pref-crash
dump-readability case (v7 + required vars).

### Phase 2 — Kill divergence traps + the export-abort bug (mechanical)
- New `experiment/+utils/gazeValidity.m`: single accessor for the Tobii
  Validity field; the five independent implementations (`gazeToPixels.m:34`,
  `positionGuide.m:295`, `gazeCodec.m:218`, `diagnoseTrackBox.m:130`,
  `export_gaze_csv.m:225`) call it, each keeping its own one-line policy
  (assert/coerce) at the call site — behaviour-identical.
- **stimIdx fix lands here**: guard `trialPlanRows`
  (`scripts/export_gaze_csv.m:398`) with `isfield(plan,'stimIdx')` → empty for
  pref plans; move `exportSession.m:82`'s whole-derivation catch inside the
  per-run loop so one bad run can't permanently abort all derived exports.
- Standardize `eventLog('init', 20000)` in all three tasks (prealloc only).
Tests: `test_gaze_csv_export` gains a pref-plan case; `test_block_exports`
gains a one-bad-run-doesn't-abort case.

### Phase 3 — Split runCheckpoint; keep the stable dispatchers
`experiment/+utils/runCheckpoint.m` (6 modes, on both canonical traces) →
`openRun.m`, `freezePlan.m` (freeze/peek), `runComplete.m`; `resolve`
dissolves into Phase 4's `recoverBlocks`. Callers: `run_battery.m:89`, three
tasks, `preflight.m`; tests `test_run_recovery`, `test_session_context`.
Explicitly NOT split: `checkpointIO` (66 lines, 4 verb modes, 92 sites — pure
churn), `gazeCodec` (it IS the on-disk gaze format; pack/verify side-by-side
is the win), `eventLog`/`timeline`/`incentives`/`sessionContext`/
`elicitationCache`/`gazeBuffer`/`consentRecord` (small, verb-named, off-trace).

### Phase 4 — Collapse the write/recovery chain (the aggressive zone)
Delete `taskBlock.m` and `blockRecording.m`; rework `blockStore.m` into named
files so the whole trial-write path reads top-to-bottom in one file:
- `beginBlock.m` = taskBlock 'begin' + blockStore 'begin'
- `commitBlock.m` = taskBlock 'finish' + blockRecording 'finish' + blockStore
  'commit' + inlined `alignBlockGaze.m`
- `scanBlocks.m` = blockStore scan/recover lineage walk (still called by
  `scripts/combine_blocks.m`, `scripts/sync_blocks.m`)
- `recoverBlocks.m` = taskBlock 'recover' + runCheckpoint 'resolve'
- `startRecording.m`/`drainRecording.m` replace blockRecording's two modes.
`makeReceipt`/`validateReceipt` move verbatim — all artifacts
(entry/responses/behavior/gaze/prepared/receipt .mat) byte-compatible.
Aggressive cuts: (a) drop the orphan-receipt reconstruction branch
(`blockStore.m:65-78`) — a kill between gaze.mat and prepared.mat redoes the
block instead of resurrecting it; old data still scans (it has receipts);
(b) `taskBlock.m:10`'s pref special case disappears — `recoverBlocks` returns
blocks only and each task assembles its own trials, reuniting pref's
half-logic (`preference_task.m:132-135`) with its other half.
Resulting trace: task → commitBlock → checkpointIO. Three files, was seven.
Tests follow renames; orphan cases removed (floor stays ≥52 — if it can't,
keep the orphan branch, not the floor). `BLOCK_CHECKPOINTS.md` rewritten in
the same commit (also fixing the stale "51 cases" and "not yet cleared"
wording).

### Phase 5 — Normalize (don't extract) the block loop
Keep the 7-step block loop duplicated in all three tasks — a shared driver
would hide exactly what a debugger needs to see — but normalize step order,
variable names, and section comments so a side-by-side diff shows only real
differences (`auction_task.m:315-399`, `continuous_DC_task.m:272-388`,
`preference_task.m:131-177`). Unify only `showMessage` (three near-copies with
a drifting timeout arg) → `+utils/showMessage.m`. `buildTrialTable` stays
local per task (shapes differ by design) with a one-line output-schema header.

### Phase 6 — Targeted inlining + DEBUGGING.md (last, when traces are short)
Inline single-caller crumbs: `preferenceChunks`→preference_task,
`consentRecord`→launchSurvey, `taskSeed`→openRun, `collectWins`→its caller.
Leave `clockSync` (multi-caller) and all UI helpers / large single-caller
files (`positionGuide`, `diagnoseTrackBox`, `buildPhotoPreferencePlan`,
`mirrorDiagnostics`, `verifyPaths`) as files. New `docs/DEBUGGING.md`, one
page per canonical question: (1) "where did this trial's data get written" —
block loop → commitBlock → checkpointIO, naming every file and path template;
(2) "a session crashed — what happened next" — task catch → run_battery
catch, both dumps, `read_crash_dump.py` usage, recovery via scanBlocks and the
signature-refusal rule. Link from `docs/CODE-GUIDE.md` and
`experiment/README.md`.

## Verification

Per phase: the gate command above, locally (MATLAB installed; suite tolerates
no-Tobii skips). After Phase 4 additionally: `test_block_sync` +
`test_session_tail` (publish/export end-to-end against tempdir shares), and a
`demo_battery` run. After the final phase: the lab runs `rig_checks` on
the rig (all three stages) and one practice session end-to-end; success = pref
run exports, no "EXPORTS NOT DERIVED", derived files on the share.
WORK.md `## Now` updated per phase; each phase is one commit on main.
