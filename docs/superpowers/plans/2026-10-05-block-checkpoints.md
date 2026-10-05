# Block Checkpoints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for native execution, or superpowers:subagent-driven-development only if the user explicitly selects that workflow. Steps use checkbox syntax; WORK.md is the only live progress record.

**Goal:** Preserve verified completed blocks across forced MATLAB closure, repeat only an interrupted block as a new attempt, and export lossless gaze with explicit trial/block organisation.

**Architecture:** Immutable block-entry snapshots and attempt bundles on durable local disk are the recovery authority. Behavioral data is committed before compact gaze; a verified receipt marks a complete bundle. Share replication and combination are offline, idempotent operations.

**Tech Stack:** Existing MATLAB/Psychtoolbox/Tobii experiment; MATLAB headless tests and MAT/CSV storage; existing R analysis; Bash/Python static verification. No new runtime/toolbox dependency without evidence it is necessary.

**Spec:** `docs/superpowers/specs/2026-10-05-block-checkpoints-design.md` (approved in conversation).

## Global constraints

- Preserve approved study conditions and trial counts.
- No rounding, integer clock-to-double conversion, averaging eyes, sample deletion or downsampling.
- Never overwrite an earlier attempt, and never delete historical participant files during recovery.
- Network availability must not gate local capture or local recovery.
- Combining is repeatable, does not mutate raw files, and is never a prerequisite for ending a participant session.
- Do not change pair-selection policy, repeated-item policy, card layout, consent, or counterbalancing.
- Use existing auction plan blocks; six contdc task-type/attribute-level blocks; preference section chunks of at most 40 trials.
- Local default is Windows LOCALAPPDATA/housing-wages/Data, preference-directory fallback elsewhere, with HW_LOCAL_DATA_ROOT override and isolated participant/practice/demo roots.
- Participant data remains ignored, never in commits. Legacy files remain unchanged; missing exact legacy onsets must never be invented.
- This machine has no MATLAB/PTB: static-only results do not establish runtime safety.

## Execution and permissions

Execute in an isolated development branch/worktree in housing-decisions, after checking current status and the approved spec. Allowed: repository changes, tests, local commits, synthetic fixtures, read-only official documentation, and copies of explicitly supplied data. Do not send messages, push the new format, deploy to a rig/share, delete old outputs, or modify original participant data without authorization.

Recommended execution is native, sequential implementation with a focused independent review before release. Read-only fan-out is permitted by the working agreement; a multi-agent implementation workflow is not pre-authorized. Commit each independently validated milestone. Preserve WORK.md's existing local-only ignore policy; update it throughout, not a second progress file.

No persistent goal exists yet. The launch instruction at the end is for the user to issue explicitly. Do not reinterpret spec/plan approval as a goal launch.

## Review focus

1. A kill between verified file rename and receipt/manifest publication must recover the completed bundle without repeating its block (Task 2).
2. Two attempts, stale remote state, changed defaults, or restarted clocks must never silently mix into one logical run (Tasks 3, 4, 6).
3. An auction retry must restore pre-block retirements and random state, including practice-related consumption (Task 5).
4. Disabled/invalid tracking, unknown SDK leaves and clocks above 2^53 must not lose behavioral data or silently alter gaze (Tasks 1, 2, 4).
5. Existing R globs and old MAT files must not count fragments twice or claim precise stimulus times absent from legacy recordings (Tasks 6, 7).

## File and interface map

New helpers live in `experiment/+utils/`; tests live in `scripts/tests/`.

| File | Responsibility and public interface |
|---|---|
| `gazeCodec.m` | `out = gazeCodec(action, value)`, actions pack/unpack; preserve shape, leaf paths, types and samples |
| `blockStore.m` | `out = blockStore(action, cfg, varargin)`, actions begin/commit/scan/recover; owns immutable local attempt transactions |
| `checkpointIO.m` | Private-to-storage filesystem operations: verified same-directory replacement, content identity and safe directory publication; no task decisions |
| `runCheckpoint.m` | `out = runCheckpoint(action, sess, varargin)`, actions open/freeze/resolve; logical run identity and frozen context |
| `blockRecording.m` | `out = blockRecording(action, et, varargin)`, actions start/finish; bounded gaze lifecycle and per-block clock anchors |
| `alignBlockGaze.m` | `association = alignBlockGaze(packed, events, clockSync)`; sample-to-trial/phase mapping and explicit uncertainty |
| `combine_blocks.m` | `report = combine_blocks(localRoot, outputRoot, varargin)`; validated canonical exports, explicit legacy/partial options |
| `sync_blocks.m` | `report = sync_blocks(localRoot, shareRoot)`; copy finalized artifacts, verify, publish receipts last |
| `benchmark_gaze_storage.m` | `report = benchmark_gaze_storage(sourceFile, outputRoot, varargin)`; non-destructive codec/format/local/share comparisons |
| `verify_block_checkpoints.m` | Headless suite runner; fails if any MATLAB checkpoint tests fail |

Interface contracts: `context` identifies schema version, participant/runKind/session/task/domain/logicalRunId/blockOrdinal and parent receipt; `entryState` contains frozen plan, elicitation and RNG state. `attempt = blockStore('begin', cfg, context, entryState)` adds a collision-resistant attemptId and local directory. `payload` contains behavioral trials/CSV table, events, block metadata, raw gaze, clockSync and nextState. `receipt = blockStore('commit', cfg, attempt, payload)` returns only after validation. `scan/recover` consume logicalRunId and return committed lineage, next block, restart snapshot and explicit conflicts; they do not invent participant choices.

`runCheckpoint('open', sess, task, domains)` returns a logical-run context; `freeze` accepts that context plus materialized plans/state before collecting; `resolve` returns frozen context and validated block recovery. `blockRecording('start', et)` returns a fresh block buffer/start anchor; `finish` accepts its buffer and returns raw gaze and end anchor. `gazeCodec('pack', raw)` returns schemaVersion/sampleCount/originalShape/leafSchema/columns; unpack reconstructs the original SDK value representation. Define unsupported SDK object handling from real evidence before locking this interface.

## Task 1: Lossless gaze codec and reproducible storage benchmark

**Files:** Create `experiment/+utils/gazeCodec.m`, `scripts/benchmark_gaze_storage.m`, `scripts/verify_block_checkpoints.m`, `scripts/tests/test_gaze_codec.m`, `scripts/tests/fixtures/gaze_samples.m`.

- [ ] Obtain a copied known-good sample/schema from the RA's readable file or the installed SDK; preserve originals. If inaccessible, build synthetic fixtures and keep actual-SDK validation explicitly pending rather than guessing the full schema.
- [ ] Write failing MATLAB tests for `isequaln(gazeCodec('unpack', gazeCodec('pack', raw)), raw)`, verifying classes/shapes separately. Cover empty samples, nested binocular vectors, NaNs/invalid flags, integer clocks created as `uint64(2)^53 + uint64(1)`, heterogeneous/extra leaves, unequal chunk sizes and sample order.
- [ ] Run `matlab -batch "addpath('scripts'); verify_block_checkpoints"` where MATLAB is available; record the expected missing-helper failure. If unavailable here, record that fact and do not claim red/green runtime verification.
- [ ] Implement schema-driven column packing without field loss or precision conversion. Unknown unsupported leaves stop packing explicitly; the caller retains raw data. Test supported SDK objects as well as structs if the real sample requires them.
- [ ] Implement the benchmark: unique output directory, source/output identity guard, no source writes, timings and sizes for baseline versus packed saves/loads, optional separate share destination, and mandatory roundtrip equivalence. Retain metadata, keep the source readable after every test, and report incomplete results if any stage fails. Do not run a full experiment to benchmark serialization.
- [ ] Run the headless suite and static checks; commit the codec/benchmark with honest runtime status. Schema finalization depends on real-SDK evidence; other filesystem work may continue independently if unavailable.

## Task 2: Durable local block transactions

**Files:** Create `experiment/+utils/blockStore.m`, `experiment/+utils/checkpointIO.m`, `scripts/tests/test_block_store.m`; modify `experiment/+utils/config.m`, `experiment/+utils/progressLog.m`, `.gitignore` if needed for synthetic outputs.

**Consumes:** Task 1 codec. **Produces:** attempt/receipt/recovery contract above.

- [ ] Write failing tests using real temporary directories: after each modeled interruption state, scan returns either a validated complete block or explicit incomplete attempt. Assert bytes/hashes of pre-existing attempts never change. Include behavior-only, truncated gaze, missing receipt, stale manifest, mismatched IDs, receipt mismatch and conflicting valid attempts.
- [ ] Test local-root resolution, practice separation, disabled tracking (explicit empty gaze valid), unwritable storage and unavailable share. Assert share paths are never accessed by local begin/commit/recover.
- [ ] Implement behavior-first write/reload/validate/rename, then codec and gaze validation, then receipt and nextState. Receipts include counts, schema, parent lineage and file digests. End-only manifest updates are reconstructable. Use same-directory temporary files; distinguish process-interruption protection from a power-loss durability guarantee.
- [ ] Implement conservative orphan reconciliation: only promote a complete verified bundle with compatible parent/identity; never promote arbitrary file existence. Preserve raw buffer/behavior on codec or disk failure, return explicit failure before advancing, and log the actual operation/error locally.
- [ ] Run tests and existing static checks. Commit only the checkpoint/storage milestone; failure evidence stays in WORK.md.

## Task 3: Frozen logical runs and restart selection

**Files:** Create `experiment/+utils/runCheckpoint.m`, `scripts/tests/test_run_recovery.m`; modify `startSession.m`, `beginRun.m`, `appendRun.m`, `endRun.m`, `elicitationCache.m`, `experiment/run_battery.m` under their existing directories.

**Consumes:** Task 2 scan/recover. **Produces:** saved assignment/context/entryState and next-block decision used by Tasks 4–5.

- [ ] Write failing tests: choose first uncommitted block; skip complete tasks; distinguish logical run from timestamped attempt; ignore superseded failures when deciding whether a participant is unfinished; retain old timing rows; refuse incompatible frozen config/stimulus provenance. Legacy manifests require explicit legacy handling, not fabricated checkpoints.
- [ ] Implement durable local session/elicitation/plan snapshots, preserving consent behavior and participant assignments. Materialize task-specific plans at first execution; resumptions load snapshots rather than rerunning elicitation or randomisation. Resolve and display participant/session/task/block/attempt before task entry.
- [ ] Ensure a stale manifest cannot invalidate a verified block and a participant fully complete in valid artifacts is not automatically offered for replay. Verify replicated chains before cross-computer resumption; missing/conflicting local/remote evidence is surfaced.
- [ ] Keep crash diagnostics separate by task/attempt, preserving task partial data rather than overwriting it in the battery catch. Store timing incrementally without erasing completed attempts.
- [ ] Run headless and static checks; commit identity/recovery integration. Tasks 4–5 complete task-specific snapshots; do not expose an apparently working partial recovery path to participants.

## Task 4: Accurate block recording and continuous-DC integration

**Files:** Create `experiment/+utils/blockRecording.m`, `experiment/+utils/alignBlockGaze.m`, `scripts/tests/test_block_recording.m`, `scripts/tests/test_contdc_blocks.m`; modify `experiment/continuous_DC_task.m`, `experiment/+utils/gazeBuffer.m`, `eventLog.m`, `awaitFixationStart.m` where needed.

- [ ] Write tests with controlled event/clock/sample fixtures: retain integer raw clocks, align using relative deltas, map samples at exact boundaries with a documented half-open interval rule, mark fixation/intertrial/unknown phases, flag invalid anchors, and distinguish restarted blocks/attempts. Test drain/stop/re-subscribe order via a test tracker while asserting retained samples and events, not merely call counts.
- [ ] Integrate frozen six-block schedule/pairs/selections/orders. Persist entry state before trials; accumulate only the current block. At block finish save responses then gaze through Task 2 and advance only on a receipt. Retain necessary cross-block response summaries without accumulating raw gaze.
- [ ] Capture choice/price stimulus onset from the first actual stimulus Screen Flip return, never from pre-fixation GetSecs. Add explicit trial/block/attempt/phase keys to events and response rows. Keep response timing anchored to the appropriate actual onset.
- [ ] Test interruption after a choice block and during its matched pricing block: completed choices remain unchanged, pricing retries retain pair identities, and new attempts are distinct. Test eye-tracking disabled and failed sync without losing behavioral outputs.
- [ ] Run checks, inspect stimulus-flip placement in source, and commit. Actual PTB timestamp behavior remains a rig gate.

## Task 5: Auction and preference block integration

**Files:** Modify `experiment/auction_task.m`, `experiment/preference_task.m`; create `scripts/tests/test_auction_blocks.m`, `scripts/tests/test_preference_blocks.m`. Extract small task-state helpers to `experiment/+utils/` only when needed to test pure schedule/state transitions without PTB.

- [ ] Write auction tests: restore original/current plan and won-item history at block entry; restore both RNG states; replay does not retain abandoned retirements; previously completed block hashes never change. Preserve block boundaries inside ABBA's uninterrupted competition condition.
- [ ] Integrate auction checkpoint boundaries, state snapshots and true flip timestamps for option appearance/removal and detail/bid screens. Retain relevant dynamic AOI/event identity. Avoid double-consuming practice RNG during resumed execution.
- [ ] Write preference tests: chunks contain at most 40 consecutive trials, original section order/stimulus sequence and total trial counts remain unchanged, resumed chunks retain unique global trial keys, and rating/PWC relationships survive. Include the final short chunk and jobs-only PWC.
- [ ] Integrate preference chunks through the shared recording/transaction path. Preserve first-stimulus-flip capture and all metadata; record I/O breaks as nontrial intervals.
- [ ] Run all headless tests plus static checks and commit. Confirm all three tasks now use the same completion contract and none retain unbounded domain-wide gaze solely for a final save.

## Task 6: Offline replication, combination and analysis compatibility

**Files:** Create `scripts/sync_blocks.m`, `scripts/combine_blocks.m`, `scripts/tests/test_block_exports.m`, `scripts/tests/test_block_sync.m`; modify `analysis/R/io.R`, `analysis/README.md`, `scripts/test_run_all_safety.R` as needed; move/expose contdc reversal calculation as a pure shared helper if necessary.

- [ ] Write real-file tests: syncing twice changes no source bytes and yields one canonical destination; interrupted destination copies are not published; content conflicts fail; network failure retains all local data; receipt publication occurs only after destination verification.
- [ ] Implement explicit offline sync, never automatic blocking share I/O between trials. Return complete/pending/conflict status per bundle; preserve local originals unconditionally.
- [ ] Write combination tests for ordered valid blocks, missing blocks, two valid conflicting attempts, resumed ancestry, invalid receipt, unknown schema and legacy imports. Assert repeat execution is idempotent and raw trees unchanged. Incomplete export requires an explicit option and flags.
- [ ] Implement canonical behavioral CSV exports, keyed gaze/events tables, retained raw timestamps, sample/attempt provenance and cross-block reversals. Old R globs see only canonical outputs; raw fragments live outside their task CSV patterns. Legacy timing limitations are explicit; never synthesize exact onsets.
- [ ] Run new MATLAB tests, `Rscript scripts/test_run_all_safety.R`, and a small synthetic combined-export fixture through `Rscript analysis/R/00_participant_qc.R --data <fixture-output>`; verify expected row counts/no double counting. Document which path is derived output versus immutable raw storage. Commit.

## Task 7: Full verification, benchmark and operator handoff

**Files:** Update `experiment/README.md`, `analysis/README.md`, `scripts/verify_static.sh`, `scripts/verify_matlab.m`; keep progress in WORK.md. Add an executable/manual rig checklist next to existing operator documentation only if it is not another live-state file.

- [ ] Run `bash scripts/verify_static.sh`, `python3 scripts/check_utils_calls.py`, `git diff --check`, `Rscript scripts/test_run_all_safety.R` and the complete headless MATLAB suite. Run the existing `verify_matlab` function too where MATLAB is installed. Record exact unavailable checks instead of asserting they passed.
- [ ] Benchmark a copied readable RA file using Task 1's tool. Report source and packed sizes, timings and verified equivalence. Investigate regressions before proposing deployment; distinguish network delay from local serialization cost using measured results.
- [ ] Obtain focused independent code review of transaction/recovery/timestamp/codec paths; repair findings and rerun affected checks. This is ordinary review, not the separately gated ultra workflow.
- [ ] Write short operator instructions for local data location, exact resume display, pending-transfer status, sync/combiner invocation and log retrieval. Explain that repeated interrupted blocks remain separate attempts and that old raw files are unchanged.
- [ ] Gate rig release on explicit authorization. Rehearse all three tasks in practice mode, force close mid-block and during save, resume, disconnect the share, verify timing and combine outputs. Confirm exact trial counts and no overwritten completed blocks. Require a real SDK roundtrip and true onset evidence before claiming validation.
- [ ] Commit verified changes locally. Report code-ready versus rig-validated separately. Do not push/deploy while runtime acceptance remains unverified or without authorization.

## Failure handling and completion

Failing tests block their milestone; diagnose and repair within scope, retaining all original data. Missing MATLAB/rig/real-data access permits independent implementation/static work but blocks claims that runtime acceptance passed. Ask for the specific missing runtime result when it becomes the only remaining dependency. Do not keep proposing unevidenced causes or repeated blind rig attempts.

Return to the user for changes to scientific conditions, unsupported SDK data that cannot be retained losslessly, conflicts requiring attempt selection, unavailable runtime validation, or publication/deployment authorization. Keep existing corrupted runs unchanged. Goal completion requires the full agreed acceptance evidence, not merely a clean static check or implemented scripts.

## Ready-to-use launch instruction

Make executing `/home/msb/projects/housing-decisions/docs/superpowers/plans/2026-10-05-block-checkpoints.md` a goal. Use native execution through the seven milestones, preserve the approved scope and all original data, and continue through storage/recovery tests, lossless gaze verification, offline export checks and the required rig acceptance. If MATLAB, a real gaze copy or rig access is unavailable, finish independent work and request the missing evidence without claiming runtime success. Do not push or deploy the new format without my approval.
