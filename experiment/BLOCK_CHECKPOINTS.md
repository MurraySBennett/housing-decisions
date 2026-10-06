# Block checkpoints: operator and validation guide

This format is under validation. Do not deploy it for participants until the
MATLAB/SDK checks and rig rehearsals below pass. Static checks are insufficient.
Old participant files remain unchanged; damaged files are not repaired by this change.

## Where the data and logs go

Capture and recovery use a **local** disk. On Windows the default parent is
`%LOCALAPPDATA%\housing-wages\Data`; otherwise it is MATLAB's
`fullfile(prefdir,'housing-wages','Data')`. `HW_LOCAL_DATA_ROOT` overrides that
parent. Its `participant` and `practice` subdirectories are separate.
Demo runs use a fresh `fullfile(tempdir,'housing-wages-demo',UUID)` sandbox;
the console prints its full data path. `projRoot` never chooses the capture disk.
`utils.startSession` prints the resolved data root. Enter the participant ID
from the study register; local disks cannot safely allocate study-wide IDs.

`HW_DATA_ROOT` / `HW_PRACTICE_DATA_ROOT` now designate replication destinations.
They are not used to capture or recover blocks. Stimulus assets and the SDK may
still need their configured locations; local saving does not make remote assets
available offline. Keep a local asset/SDK installation for disconnected rehearsals.

Inside the selected run-kind root:

- `runs/<run>/run.mat`: frozen identity, assignment, configuration/source hashes.
- `runs/<run>/<domain>-plan.mat`: generated schedule, elicitation, RNG state;
  auction practice responses/events/packed gaze are retained here too.
- `blocks/<run>_<domain>/block-NNNN/attempt-<UUID>/entry.mat`: pre-block state.
- `responses.mat`: responses/events saved before the final tracker drain.
- `behavior.mat`, `gaze.mat`: verified finalized artifacts. Gaze contains typed
  numeric columns, schema and sample association; no downsampling or rounding.
- `prepared.mat`, `receipt.mat`: hashes, identity and counts. A receipt confirms
  the bundle; recovery can reconstruct it from a valid finalized pair after a kill.
- `sessions/`: immutable resolved battery/task context and elicitation; current
  manifests and timing. `session_history/` retains byte-identical versions during
  replication; incompatible calibration/assignment changes stop the transfer.
- `emergency/`: raw chunks from catchable failures. These never count as completion.
- `auction/`, `cont_dc/`, `pref/`: optional whole-task summaries. Receipts remain
  authoritative if a summary save fails.

Progress logs are in `fullfile(tempdir,'housing-wages-logs')`. Every run prints its
exact `.log` path. Each entry is closed immediately, so normal MATLAB shutdown
is not needed. After a crash retain that log, the entire run folder under
`runs/`, and its matching `blocks/` tree. Never delete partial files to retry.

## Restart

Use the same code, configuration, participant ID, session and assignment on the
same rig/local data root. Completed tasks are skipped by the battery. Before
trials the console prints the verified-block count, next block, and new attempt
UUID. An unfinished block repeats from its pre-block plan and RNG state; its old
attempt remains separate. Auction item retirements from an abandoned block do
not carry into the retry. Preference uses consecutive chunks of at most 40
trials, without changing its order or total counts.

Changed code/configuration or conflicting completed attempts stop recovery.
Resolve such conflicts from the retained evidence; do not delete an attempt or
change a manifest to force continuation. Legacy sessions cannot be resumed as
if they contained block checkpoints. If all blocks finished before a final
summary/payout failure, recovery skips the task; inspect the records before
settling any unpaid auction incentive.

For another rig, first verify the complete run tree was copied to that rig's
local run-kind root. `sync_blocks` can copy from one local/archive root to another;
it never reads the network automatically during task capture. A new empty local
directory cannot know about data collected elsewhere. Never treat an empty rig
as evidence a participant is new.

## Offline replication and exports

Run from the repository root in MATLAB, with the experiment closed:

```matlab
addpath('experiment','scripts');
cfg = utils.config('runKind','participant');
transfer = sync_blocks(cfg.paths.data, cfg.paths.shareData);
disp(struct2table(transfer));
```

`complete` means the reported finalized blocks copied with matching SHA-256
hashes; it does not mean every study task finished. `pending` means retry is
needed or an interrupted attempt remains locally. `conflict` needs investigation.
Local originals are retained in every case. Transfer is explicit, retryable and
idempotent. Never run two writers for the same participant at once.

Combine into a **separate, new derived directory**, not inside the raw tree:

```matlab
exportRoot = fullfile(tempdir,'housing-derived'); % choose a durable analysis location
report = combine_blocks(cfg.paths.data, exportRoot);
disp(struct2table(report));
```

A repeated export of identical source artifacts is idempotent. Different content
at an existing output path is a conflict, so use a new derived directory after
collecting more blocks. Incomplete runs fail by default. Explicit
`'allowPartial',true` places incomplete results under `partial/`, outside normal
analysis globs, and marks every row incomplete. Only one validated attempt
lineage is exported. Raw fragments are never analysis CSVs.

Canonical CSVs retain the old behavioral columns and add `block`, `attempt_id`,
`checkpoint_schema`, and `complete`. Companion MAT files retain block metadata,
events, cross-block reversal scores, and an `attemptInventory` identifying both
included receipts and excluded interrupted attempts with evidence paths. Each `<run>_<domain>_gaze.mat` contains
`gazeExport.blocks`, a cell per block. Each block retains its integer clock
columns, leaf schema, raw sample order, events' association and attempt identity;
clock epochs are not concatenated into a fictitious continuous session clock.
`association` gives sample index, PTB time, trial and phase. Invalid anchors or
clock resets remain `unknown`. Intervals include their onset and exclude the
next onset. SDK objects can be reconstructed per block with
`utils.gazeCodec('unpack', gazeExport.blocks{1}.packed)` when the SDK is installed.

`combine_blocks(...,'legacyFiles',{'/path/to/old.mat','/path/to/old.csv'})` archives
explicit legacy files unchanged under `legacy/` with source hashes and a timing
limitation record. It does not infer blocks or exact onsets, mix old and new
attempts, or make unreadable gaze files readable.

## Checks away from the lab

The MATLAB checkpoint suite can run without a display session or connected eye
tracker. It uses temporary directories and fake tracking for buffer/drift tests;
the actual-SDK value-object case still needs the SDK class files. On a computer
with MATLAB, set HW_TOBII_ROOT and run verify_block_checkpoints as below. A
readable RA file also permits the storage benchmark without collecting new data.

The 38 cases include actual auction trial-row conversion through block commit,
reload and recovery. They do not execute every interactive task screen or prove
PTB timing, device streaming, browser intake behavior, or physical kill/restart.
Python/Bash syntax, helper-reference and discovery checks cannot replace them.
The e20db45 ZIP is superseded: a later source audit found auction missing-anchor
and demo undefined-variable failures, corrected in the subsequent build.

The intake issue that previously blocked restart is fixed. `utils.launchSurvey`
reads `utils.consentRecord` first and, when a consented record is already on
file for that participant and session, reports when consent was taken and does
not reopen the survey; the record itself is write-once, so a resumed run can no
longer replace the evidence of when consent was obtained. A second write lands
beside the original under `sub-XXXXX_ses-YY_survey_<id>.mat` with a warning.

What this does NOT fix: if the participant's browser tab died with the crash,
the unanswered half of their Qualtrics response is stranded on that response,
and no code can reunite it with a new one. The resume path says so on the
console. A clean checkpoint receipt alone is still not evidence that intake and
end-of-task processing are complete.

## Required acceptance before release

On a MATLAB machine, from this development checkout's root:

```matlab
addpath('experiment','scripts');
setenv('HW_TOBII_ROOT','C:\path\to\TobiiPro.SDK.Matlab_1.9.0.59');
diary(fullfile(tempdir,'housing-checkpoint-validation.log'));
verify_block_checkpoints;
verify_matlab;
report = benchmark_gaze_storage('C:\path\to\readable_RA_gaze.mat', ...
    fullfile(tempdir,'housing-gaze-benchmarks'));
disp(struct2table(report.outputs));
diary off;
```

Replace those two paths with the installed SDK and a known-readable RA file.
The benchmark reads its input and writes uniquely named copies. It requires exact
roundtrip equivalence of every original field/type/shape; report measured sizes
and save/load times, not a guessed compression ratio. Optional `'shareRoot',path`
creates another unique benchmark directory there, only when that write is wanted.
The suite requires exactly 38 discovered cases and fails if the actual-SDK test is skipped. The rig also needs Psychtoolbox
for the existing `verify_matlab` checks where applicable.

Then rehearse **each of auction, continuous DC and preference**, in isolated
practice storage using the same settings intended for capture:

1. Complete one block; note its receipt hash and displayed next block.
2. Force-close MATLAB mid-next-block. Restart: the completed block must be
   unchanged, the interrupted block must restart with a new UUID and matching
   plan/order. Auction must restore pre-block won-item history.
3. Repeat a forced close during saving; recovery must either recognize the
   verified completed bundle or repeat that interrupted block, never skip it
   based on file existence alone. Keep all evidence.
4. Disconnect the share with local assets/SDK available. Confirm capture/recovery
   still works, failed sync leaves local files intact, and repeated sync succeeds.
5. Verify actual Screen Flip onsets, fixation/response/intertrial phases, block
   identity, monotonic raw clocks, valid integer-relative clock sync, sample
   counts and exact SDK reconstruction. Test disabled tracking too.
6. Combine the resumed run; verify expected trial counts, no duplicate attempts,
   matched choice/pricing pairs and preference section order. Run participant QC
   against the **derived** root. Confirm two syncs/exports change no raw hashes.
7. Exercise a deliberately unwritable test destination and conflicting synthetic
   attempts with the headless suite; never fill a real participant disk to test it.

Return the validation diary, benchmark report and rehearsal results. No goal
completion or deployment claim is warranted until that evidence is checked.
Temporary-file rename protects against process interruption; it is not a claim
of fsync-backed survival through power loss.
