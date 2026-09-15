---
project: housing-decisions
---

# Work — housing-decisions

## Now

**Code is deployed to the lab share and the RA-facing work is half done.** The
share now carries the current experiment code plus the R analysis; the RA deck
is written but stayed local because it needs another pass. The deploy was a
manual explicit-manifest copy, which is a stopgap — see the `infra` stream, and
do not let it become the normal way code reaches that machine.

**The experiment is code-complete; a demo path, an analysis path, and an RA
guide now exist alongside it.** New on 2026-09-15: `experiment/demo_battery.m`
(every participant-facing element in ~6 min, into a sandbox that is never the
real `Data/` tree), `analysis/` in R (reads the run CSVs, prints an integrity
report, writes ten descriptive figures, and can run on simulated data with no
MATLAB at all), and `docs/ra-setup-deck.html` (the session guide for a new RA).
The analysis pipeline is verified end to end on simulated data; the demo script
is **verified statically only** — this machine has no MATLAB, so its first real
run on the rig is the test. Everything still gating collection is unchanged:
settle the conditions, stand up REP, book rig time, rehearse. The bar is still
that **it has to run seamlessly and pleasantly.**

## Streams

### experiments
- [ ] now (M) settle the conditions and design — which PLAN rows, which `JOBS_ARM` (three are prepared and committed: `attenuated`, `ecological`, `synthetic`), `attrLevels`, `nTrials`/`nPairs`. The knob table is in review section D. Check the choice against `docs/grant/Wage_and_House_Pricing_Model_Grant_Proposal.pdf` — the proposal may already commit to conditions, and diverging from it silently is worse than diverging deliberately. **This gates everything downstream**
- [ ] now (S) write down what "runs seamlessly and pleasantly" means as checkable criteria *before* the rehearsal, so the dress run has a pass/fail bar rather than a vibe. Candidates: no visible stutter between trials, no dead time a participant would read as a crash, every instruction understood without asking, a mis-click always recoverable, and the participant always able to tell where they are and how much is left
- [ ] next (S) run `preflight.m` against the finalised design and check the block schedule and estimated duration are tolerable to sit through — it prints both
- [ ] next (L) dress rehearsal on the lab rig, once conditions are settled: confirm monitor diagonal and viewing distance in `rigProfiles`, install `Press Start 2P`, then one full TESTING run **and** one full real-mode run as a throwaway participant. Open the saved `.mat`, `.csv` and gaze files afterwards and check every field before participant 1
- [ ] now (S) run `demo_battery` on a machine with MATLAB and fix whatever it
  hits — it is committed unrun, and the first execution is its only real test.
  Then `Rscript analysis/R/run_all.R --data experiment/Data_demo` to confirm the
  real saved CSVs parse the way the simulated ones do
- [ ] later (S) re-verify parity against the kvam.4 lab drive after the design is frozen — `docs/shared-drive-parity-2026-09-10.md` is the record of the last pass

### infra
- [x] 2026-09-15 deployed the current code to the lab share by explicit-manifest
  copy (`scripts/deploy_to_share.ps1`): 61 files replaced, 10 added, previous
  `Experiment\` tree backed up to `Archive\Experiment_pre-2026-09-15` (66
  files). `Data\`, `stimuli\house_images\`, `Experiment\archive\` and the
  share-only stimulus files were excluded by name and verified untouched
  afterwards. The RA deck was deliberately NOT copied — it needs work first
- [ ] now (M) **this copy is a stopgap and recreates the divergence problem.**
  Git is not installed on the lab machine. Get it installed, clone the repo
  over the share copy, and delete `scripts/deploy_to_share.ps1` — then
  `git status` on the share becomes the parity check and
  `docs/shared-drive-parity-2026-09-10.md` stops needing to be redone by hand
- [ ] next (S) `cfg.paths.data` points inside the code tree
  (`Experiment/Data`). If the share becomes a git clone, `git clean -fdx`
  there would delete every participant. Move it to a sibling of the checkout
  before cloning, not after
- [ ] next (S) `config.m` hardcodes the OSU UNC as `projRoot`, which is why
  `demo_battery.m` has to re-point every path by hand on WSL. `STIMULI.md`
  already documents a `$DATA_ROOT` env-var convention that nothing reads.
  Make `projRoot` read an env var with the current UNC as fallback

### admin
- [ ] now (M) set up REP for the study — the OSU participant system. Named by Murray as a prerequisite for collection this semester and not started
- [ ] now (S) book lab rig time. Everything code-side is done; rig access is the physical gate on the rehearsal
- [ ] next (S) confirm IRB approval covers the design as finalised, not as originally proposed — if the conditions move, check the approval moved with them
- [x] 2026-09-11 committed the recovered stimulus pipeline and the full review fix pass — 1,205 insertions that had been sitting uncommitted since 2026-09-10
- [x] 2026-09-11 deleted the two orphaned docs from the house_jobs/housing_wages merge after verifying both byte-identical to tracked files (planner task 66)

### analysis
- [x] 2026-09-15 R pipeline in `analysis/` — reads the run CSVs, recomputes
  preference reversals from the CSV alone as a cross-check on the MATLAB-side
  scoring, prints a data-integrity report, writes ten descriptive figures.
  Verified end to end on simulated data
- [ ] next (M) MATLAB exporter for the parts of `dataMat` the CSV does not
  carry: elicited anchors and attribute ratings, AOI rects, the flip-time
  event log, and the gaze samples. Gaze analysis is blocked on this
- [ ] later (S) decide exclusion criteria for timed-out trials and how `repIdx`
  is handled — both are named as undecided in `experiment/README.md`

### comms
- [x] 2026-09-15 `docs/ra-setup-deck.html` — RA session guide covering the
  study, the rig check, intake, the five switches in `run_battery.m`, what the
  participant sees in order, the saved files, and crash recovery

### build
- [ ] next (S) `+utils/style.m` declares audio, motion and CRT blocks that are implemented nowhere — delete them or implement them, but do not leave a config surface that silently does nothing
- [ ] next (S) fix the dangling README references: `stimgen/README.md`, `utils.scoreReversals`, and the `hw.` → `utils.` renames
- [ ] later (S) `docs/review-2026-09-09.md` holds ~30 findings; Steps 1–3 are applied, but the review is the record of what was considered and worth re-reading before changing task code
