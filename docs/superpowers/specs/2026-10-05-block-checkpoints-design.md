# Block checkpoints and organised gaze data

## Outcome and approval state

Replace end-of-task bulk saving with recoverable, self-contained block artifacts
for the auction, continuous choice/pricing, and preference tasks. A completed
block survives MATLAB being forcibly closed; an interrupted block is repeated
as a new identifiable attempt. Offline tools produce combined analysis data.

The user approved the block-level recovery policy and this written specification
on 2026-10-05. No implementation or persistent goal is launched. The technical
details below are approved design choices, not retrospective claims about the
existing implementation. Live progress belongs exclusively in WORK.md.

## Evidence and limits

The reproduced contdc run accumulated 55,635 samples. Tracker shutdown and
concatenation completed; the final log entry begins a gaze MAT save to the OSU
share. Forced closure left an unreadable file. An RA's completed file loads.
Larger files also exist: size is not an established failure threshold. The
redesign protects data and reduces saving work without claiming a proven cause.

Currently gaze is an array of SDK samples, saved with -v7.3; trials, blocks,
events and AOIs live in a separate behavioral MAT. No gaze-analysis exporter
joins them. Contdc onset events precede fixation; auction events sometimes use
the preceding flip. Existing data cannot acquire exact missing onsets retroactively.

## Scope and exclusions

Included: lossless compact storage, checkpoint transactions, explicit trial and
block association, actual display timestamps, interrupted-block recovery,
retryable share replication, offline combining, diagnostic benchmarking, tests,
and operator instructions. Preserve approved study conditions and trial counts.

Excluded: changing pair-selection policy, removing repeated house items, centring
card layouts, downsampling gaze, dropping raw gaze fields, changing consent or
counterbalancing, repairing corrupt legacy files, and automatic trial-level resume.
Those sampling/layout findings remain separate WORK.md tasks.

## Block boundaries

| Task | Checkpoint unit | Entry state that must survive restart |
|---|---|---|
| Auction | Each existing plan.block, even where adjacent blocks share a competition condition | Original/current plan, won-item history, elicitation, selected attributes, stimulus window/table, global and task RNG states |
| Continuous DC | Each existing task-type × attribute-level block (six by default) | Frozen pairs and attribute selections, resolved block order, pair/item presentation order or exact RNG entry state, elicitation, stimuli |
| Preference | Existing domain/section, subdivided into consecutive chunks of at most 40 trials | Frozen photo/job plan, section order, trial offset and RNG state |

The proposed preference chunk size is a storage boundary, not a new experimental
condition. Preserve presentation order and existing section instructions. Any
saving pause is outside a trial and identified in the event record. Do not repeat
completed sections or consume practice randomness again when resuming a block.

Auction recovery must undo state changes from abandoned trials: accepted bids
retire items from future trials. Restore the interrupted block's entry snapshot,
not the abandoned attempt's final state. New participant responses can legitimately
change subsequent adaptive outcomes; completed blocks must remain unchanged.

## Artifact and identity contract

Use a versioned schema and separate immutable logical identity from attempts:
participant, run kind, session, task, domain, logical run ID, block ordinal,
collision-resistant attempt ID, and trial ordinal. Persist the resolved battery,
assignment, config, stimulus provenance and block-entry state before collecting.
A restart must not silently substitute current defaults or regenerate completed
plans. Incompatible source/config changes stop recovery with a specific explanation.

A block bundle has a behavioral MAT/CSV, a gaze MAT, and a commit receipt. Each
component carries matching identity/schema fields; its metadata or immutable
local companion includes clock alignment, screen/AOI geometry, stimulus IDs,
eye-tracker configuration/calibration results, and the state needed to interpret
it. Save serializable metadata, not textures, images, or a live SDK handle.
Store the next-block state with the committed block so data and recovery state
cannot disagree after a manifest-write interruption.

Behavior rows retain explicit trial/block/attempt keys. Gaze columns retain both
raw clocks, all available left/right eye measurements, pupil and validity fields,
and their original numeric classes. Pack repeated nested leaves into typed arrays
with a schema describing how to reconstruct every sample. No rounding, integer
clock-to-double conversion, averaging eyes, sample deletion or downsampling.
Unexpected SDK fields must be preserved losslessly or produce an explicit schema
error with the raw buffer retained; never silently drop them. Inspect a real SDK
sample and benchmark known-good data before locking the packer schema.

Every sample receives a trial/phase association where supported by actual event
times. Fixation, intertrial and boundary samples remain explicitly non-stimulus
phases; unknown clock alignment is flagged, never guessed. Global sample/trial
identifiers disambiguate sections whose original counters restart at one.

## Timestamp and gaze lifecycle contract

Record first stimulus onset from the actual Screen('Flip') return. Record screen
changes, responses and trial endings with explicit block, attempt, trial and phase
keys. Preserve the distinction between presentation timestamps and response times.
Fixation-click timing is not stimulus onset. Validate the contdc, auction detail/
bid/search, and preference paths separately; do not rely on event names alone.

Start a fresh gaze buffer/event log and clock-sync pair at each block. At block
end drain and stop collection, preserving all samples already collected; bound
memory to the current block. Saving/break gaps are explicitly recorded and are
not presented as missing task samples. Start/re-subscribe and synchronise again
before the next block's trials. Never clear an unsaved buffer on failed checkpoint.

## Local checkpoint transaction

Use durable local storage outside the repository and tempdir. Proposed default:
Windows LOCALAPPDATA/housing-wages/Data, with a MATLAB preference-directory
fallback on other platforms and an explicit HW_LOCAL_DATA_ROOT override. Partition
participant/practice/demo data. Verify local writability before any new block;
network availability must not gate local capture or local recovery.

1. Persist the immutable block-entry snapshot and new attempt identity atomically.
2. Collect trials; use no blocking file writes in response-sensitive trial loops.
3. Save responses/events/state first to a temporary behavioral file; close, reload
   and validate identity, counts and structure, then rename within the same directory.
4. Pack gaze, save to a temporary file, close and verify sample counts, timestamps,
   types, metadata and associations before final rename. Record stage durations.
5. Commit a receipt identifying both artifacts and their verified contents. Only
   then is the block complete. Keep compact behavioral evidence even if gaze fails.
6. Update a reconstructable local manifest and discard the in-memory block only
   after durable completion. Proceed to the next incomplete block.

A forced close at any boundary must leave either a validated complete bundle or
an explicitly incomplete attempt. A renamed artifact without its receipt is
revalidated on restart before it can count as complete. Temporary/corrupt files
and file existence alone never establish completion. Never overwrite an earlier
attempt, and never delete historical participant files during recovery.

## Recovery and replication

Resume the saved participant/session/assignment, skip verified completed tasks
and blocks, and announce the exact next block and whether it is a repeated attempt.
A fully written block with only a stale manifest is reconciled from its receipt.
Superseded incomplete attempts must not trigger endless participant-resume offers.
Preserve earlier timing rows rather than overwriting them on restart.

Local completion and share replication are separate statuses. A retryable transfer
command copies finalized bundles to temporary destinations, verifies them, and
publishes receipts last. It runs after collection or separately, so a stalled
network transfer cannot block the next experimental trial. Originals stay local;
no automatic deletion/retention policy is introduced. Replication is idempotent,
and conflicting content under the same identity is an error, not last-write-wins.
Cross-computer resume requires a verified replicated checkpoint chain; conflicting
or missing checkpoints must be surfaced rather than guessed.

## Offline combination and legacy data

The combiner works after one run or after collection. It selects validated block
attempts, checks duplicates/gaps/inconsistent metadata, orders trials explicitly,
and retains provenance/exclusion flags for abandoned attempts. Multiple completed
attempts without an unambiguous committed lineage require a choice; never silently
pick the newest. Partial datasets may be exported only with an explicit incomplete
status. A combined gaze table carries participant/session/task/domain/block/trial/
phase/attempt keys; preserve raw timestamps alongside any aligned time.

Export existing behavioral column names so current R analyses continue to work,
adding schema and attempt provenance. Keep block fragments outside the legacy
CSV glob to prevent double counting. Recompute cross-block preference reversals
using the original pair identities. Combining is repeatable, does not mutate raw
files, and is never a prerequisite for ending a participant session.

Legacy files remain unchanged and are read through an explicit legacy route.
No automatic checkpoint recovery from old manifests or reconstructed exact onsets.
Report which event/timing associations are observable versus inferred. Existing
corrupt gaze files are preserved; recovery is a separate investigation.

## Verification and release criteria

- Lossless roundtrip of real/synthetic nested SDK samples, empty recordings,
  invalid eyes, unequal chunk sizes, extra fields, NaNs, and integer timestamps
  above 2^53. Reconstructed values/classes/order must match using NaN-aware equality.
- Inject interruptions before/after each write, rename, receipt and manifest update;
  completed blocks survive, incomplete blocks repeat under new attempt IDs, and
  prior outputs never change. Test disk-full/unwritable roots and share disconnects.
- Verify replay of saved block plans/RNG and auction retirements, without rerunning
  completed blocks. Include disabled tracker, corrupt checkpoints, legacy manifests,
  duplicate attempts, changed configs and idempotent replication/combining.
- Verify sample/event/trial joins at boundaries and across recording restarts; do
  not silently assign an interval when clock sync fails. Check event keys and real
  stimulus-flip timestamps in source and with a rig exercise.
- Benchmark an existing readable gaze file, preserving originals: current versus
  packed representation, local versus share saving, file size, save/load durations,
  sample equivalence and memory where measurable. State measured improvements;
  no promised compression ratio or duration before measurement.
- Run bash scripts/verify_static.sh, python3 scripts/check_utils_calls.py,
  git diff --check, new headless MATLAB tests and relevant R consumer checks.
  This machine has no MATLAB/PTB: static-only results do not establish runtime safety.
- Before participant deployment, rig rehearsal must cover every task, a forced
  close mid-block and during saving, restart, disconnected share, and verified
  offline combination. Report code-ready and rig-validated as distinct states.

## Execution boundaries and next artifact

Allowed repository: housing-decisions. Read local source and official SDK/MATLAB
references as needed; use synthetic fixtures and explicitly supplied data copies.
Participant data remains ignored, never in commits. Do not alter originals, send
mail, deploy to the share or push the new format to the rig without authorization.

After approval of this spec, prepare a saved/committed implementation plan with
ordered milestones, concrete interfaces, fault-injection tests and runtime gates.
Use the user's explicit goal-launch process before substantial execution. A saved
plan or design approval alone does not launch a persistent goal. Missing rig/data
access must be stated; never replace runtime checks with static success claims.
