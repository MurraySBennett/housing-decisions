# Debugging map

Two questions cover most rig debugging. Each answer is at most three files
deep. Written 2026-10-22, after the debuggability revision; if a file named
here does not exist, this map is stale — say so rather than guessing.

## 1. "Where did this trial's data get written?"

Read, in order:

1. **The task file** (`experiment/auction_task.m`, `continuous_DC_task.m`, or
   `preference_task.m`) — find the block loop. The save sequence is written
   out in the loop itself, identically in all three tasks:
   - `utils.beginBlock(...)` opens the attempt directory and writes
     `entry.mat` (the state the block starts from);
   - the trials run, accumulating gaze through `utils.gazeBuffer`;
   - `responses.mat` is written (a pre-drain copy of everything behavioral);
   - `utils.drainRecording(...)` takes the final gaze poll and clock anchor;
   - `utils.commitBlock(...)` writes the rest.
2. **`experiment/+utils/commitBlock.m`** — the whole write path, top to
   bottom: `behavior.mat` first (behavior can never be lost to a gaze
   failure), then `gaze.mat` (packed by `utils.gazeCodec`, trial-labelled by
   `utils.alignBlockGaze`), then the two-phase descriptor `prepared.mat` →
   `receipt.mat`. A block only COUNTS when a descriptor validates
   (`utils.scanBlocks` is the authority).
3. **`experiment/+utils/checkpointIO.m`** — how every file above is actually
   written: temp file, SHA-256 verify, rename. If a write failed, it failed
   here, loudly.

Where on disk: `<local data root>/<runKind>/blocks/<runId>_<domain>/
block-NNNN/attempt-<UUID>/`. The local data root is printed by
`utils.startSession`; it is `%LOCALAPPDATA%\housing-wages\Data` on the rigs.
The share never sees data during capture — replication happens after the
session (`utils.publishToShare`, then `utils.exportSession` for the derived
CSVs).

Per-run summaries (`auction/`, `cont_dc/`, `pref/` MAT+CSV) are written by
`utils.saveRun` and are OPTIONAL — receipts stay authoritative when a summary
save fails.

## 2. "The session crashed — what happened next?"

Two handlers run, in this order, with strict ownership:

1. **The task's `catch ME`** — byte-identical in all three task files
   (`test_crash_dump` enforces it), so read any one of them. It does four
   things: preserves any undrained gaze (`utils.preserveGazeFailure`, into
   `emergency/`), logs the error to the progress log, releases the display,
   and writes **the crash dump** — `<runId>_<UUID>_crash.mat` under
   `<data root>/<runKind>/crashed/`, a default-v7 save of `ME, dataMat, sess,
   run`. Then it rethrows: the original error always leaves the task.
2. **`experiment/run_battery.m`'s catch** — marks the run `crashed` in the
   manifest (`utils.endRun`), writes its own dump (covers errors thrown
   before the task's try opened; the task dump is the one with `dataMat`),
   mirrors diagnostics to the share (`utils.mirrorDiagnostics`), and runs the
   normal end-of-session replication (`utils.publishToShare`,
   `utils.exportSession`) — committed blocks are already safe on disk and go
   to the share even on a crash day.

To read a dump without MATLAB: `python scripts/read_crash_dump.py <file>` —
it recovers the error identifier, message and stack paths via scipy. It can
only open v7 dumps, which is why the handlers must never save `-v7.3`.

What recovery does on restart: same participant/session/code → `utils.openRun`
returns the same run identity (or refuses on a signature mismatch — changed
code/config/stimuli deliberately block resumption, see `utils.runSignature`);
`utils.frozenPlan` replays the frozen plan; `utils.recoverBlocks` republishes
any half-published descriptor and hands back the completed blocks; the task
redoes the first incomplete block from its recorded entry state. A block that
lost BOTH descriptors is redone, not resurrected (policy 2026-10-22).

The per-trial timeline of the crashed run is in
`<tempdir>/housing-wages-logs/<runId>.log` on the rig — the progress log is
append-per-line and survives hard kills.

## Everything else

- `docs/CODE-GUIDE.md` — what each top-level script is for.
- `experiment/BLOCK_CHECKPOINTS.md` — the checkpoint format, operator
  procedures, and the rehearsal checklist.
- `experiment/rig_checks.m` — the one command to run on a rig when anything
  is in doubt; send the log file it names, not a screenshot.
