---
project: housing-decisions
---

# Work — housing-decisions

## Now

**Session end 2026-09-16. Everything is committed, pushed and deployed;
clean at `e11fc1f`, `main` level with `origin/main`, share current.** Of the
pilot's 21 notes, 17 are done. Four remain: the track-box property name (9)
and running the drag-and-drop ratings (2) both need a rig visit; the
mid-task drift flag (15) is buildable; the 998/999 QA (20) waits on the
`dataMat` exporter.

**In flight, on the lab machine, not here.** Murray is at the rig
converting the share into a git checkout --
`docs/lab-machine-git.md` is the runbook, and **step 0 is the gate**: this
session moved 2,796 MB of participant data and 605 MB of images out of the
tree and changed `cfg.paths.*` to match, and none of it has run in MATLAB.
`utils.verifyPaths` at the rig is the first thing that can confirm the move
and the config agree. Handoff packet:
`~/.agents/handoffs/HANDOFF-housing-pilot.md`.

**Blocked on one call:** a name for a GitHub organisation. OSU has no
Enterprise instance, the repo is private on a personal account, and many
collaborators are expected -- a flat collaborator list whose access dies
with the account is the wrong container for something that will be cited.

**Both pilot decisions are settled and built.** The jobs arm stays
`synthetic`, regenerated with wage on its own 12-level geometric grid plus
within-level jitter, which takes distinct wages per anchored window from
1-3 to 10-26. Competition is now blocked: 24 trials, 4 ABBA blocks of 6,
starting level counterbalanced by participant parity. Session is ~12-15 min
longer than the measured ~45 as a result.

**Item 14 is diagnosed and fixed as a side effect:** house prices are now
fitted onto the anchor window rather than selected into it, so every
participant sees all 80 houses instead of the 7-23 a window held. That was
both the repeated-house complaint and the reason contdc reused stimuli
inside a block.

**Item 10 is done** -- the auction bid is made with the option on screen,
card left and arc right, same geometry as contdc's price trial. Doing it
surfaced a live bug: the card AOI geometry existed in three copies and
preflight's had drifted 12 px, so the assertion `verify_matlab.m` runs
first at the rig was validating the wrong rectangles. The copies are gone.

**What is left of the pilot backlog:** the rig diagnostic (9, track-box
property name), verifying the drag-and-drop ratings actually run (2), the
mid-task drift flag (15), and the 998/999 data QA (20) -- which still needs
the `dataMat` exporter before its gaze half can be done.

**Earlier changes from the same day, still unrun.** First, the
attribute rating screen no longer hides the mouse cursor on the way out.
That was the bug: elicitation runs before the instructions, nothing turned
the cursor back on, and the auction's comprehension check then asked for an
aimed click at an invisible pointer -- indistinguishable from a crash from
the participant's side. The check now calls `ShowCursor` itself rather than
trusting the screen before it, and `verify_static.sh` guards both halves.

**Second, the value attribute is now rated.** Listed price / offered wage
goes on the same importance line as the pool, in the same randomised order,
via the new `utils.elicitAttrRatings` -- and is then deliberately excluded
from `utils.selectAttributes`, because it is on every card at every
attribute level and no rating could change that. Saved as
`dataMat.<domain>.coreRatings`, for stated-versus-revealed comparison on the
one variable the pricing model turns on. **Watch the compression this
introduces:** price sits at the top of the line for most people, squeezing
the pool into the rest of it. Rank order is unaffected so selection behaves
as before, but raw pool ratings are not comparable across this change.

**Attribute counts, asked and answered.** Houses: 6 photos (identity --
always shown, never counted, never rated), listed price, and 5 rated pool
attributes (bedrooms, bathrooms, square feet, lot size, year built). Jobs:
industry, offered wage, 8 rated pool attributes, plus work arrangement held
back to the top level. Both domains show exactly 6 cells at attribute level
6, so on-screen load is already matched -- what differs is the pool the
selection draws from, 5 versus 8. A consequence worth deciding on: the
houses selection at level 6 is degenerate, showing all five pool attributes
whatever the participant said about them.

**The ground stays dark** (do not relitigate): a light theme would raise
relative luminance ~25x and floor the pupil, forfeiting pupillometry.

**Everything is verified statically only** -- `scripts/verify_static.sh`
passes, this machine has no MATLAB, and the first real execution of any of
it is at the rig. Run `scripts/verify_matlab.m` there *first*: it asserts
`pfAoi.allAoiOK`, the check that catches a geometry change not mirrored into
`preflight.m`.

**`run_battery.m` is now set to a full participant run** -- 2026-09-16,
`TRIALS_PER_CELL = []`, for the staff practice run. All five switches are
at real-participant settings: `RIG = 'lab'`, `TESTING = false`,
`FORCE_DOMAIN = ''`, `EYETRACKING = true`, `JOBS_ARM = 'synthetic'`. That
means session 1 is jobs (12 auction trials + 90 contdc) and session 2 is
houses (12 + 54), on separate sittings, exactly as PLAN has them.

**These practice runs are indistinguishable from real ones in the data
tree.** `dataMat.trialsPerCell` was what made a short rehearsal filterable;
at `[]` there is no marker. Use a reserved participant number for the staff
runs (9001+) and record which IDs were staff, or they will have to be
identified by memory later.

**Still gating collection, unchanged:** settle the conditions, stand up REP,
book rig time, rehearse. The bar is still that **it has to run seamlessly and
pleasantly.**

## Streams

### experiments
- [x] 2026-09-16 pilot round, decided items: attribute ratings are now
  drag-and-drop (`+utils/elicitVASDrag.m`, whole set visible, rearrangeable,
  Done gated on all placed) behind `cfg.elicit.ratingMode` with the original
  one-at-a-time version kept as `'sequential'` and both reachable only via
  `+utils/elicitRatings.m`; a WON auction item is struck from every later
  market (`retireStimulus`, floor of 6 options) while rejected/lost/expired
  ones may still return; `showValueMarker` off; house responses snap to the
  nearest $1,000; contdc timeouts 15/25 -> 25/40 s; the industry label on
  contdc cards is centred and set in body size, with the header advance now
  the single constant `s.identityTextHeightPx` read by both the draw and the
  AOI mirror; the vacancy gap keeps its 4 s mean but gains a 10 s cap so
  only the gamma tail is cut. No pixel-art job icons -- declined
- [ ] now (S) **drag-and-drop has never been executed.** It is the largest
  unrun surface in the battery and it is a mouse-interaction screen, which
  is the class of thing static checks cannot touch. Watch for: chips wider
  than the bank row, label collisions on the line, and whether dropping
  outside the band to return a chip to the bank is discoverable. Revert is
  `cfg.elicit.ratingMode = 'sequential'`
- [x] 2026-09-16 **jobs arm decided: stay on `synthetic`, regenerate it.**
  `prepare_stimuli.py` now takes `n_levels_by_column` and
  `spacing_by_column`, so the anchored attribute can differ from the rating
  ones; wage is 12 geometric levels, the five ratings stay at 4 quantile
  ones. Achieved `final_max_r` 0.143 against the 0.15 target, and the
  generator still reproduces the old 4-level arm bit-for-bit when no
  override is given, so the change is behaviour-preserving by default
- [x] 2026-09-16 **the house outcome screen is now framed as the auction it
  is.** `pricePaid = threshold` was never in question -- first-price would
  put strategic shading inside the primary DV -- but "You pay the market
  price of $Y" described a private sale in which a seller took less than an
  offer already on the table, which is what made it read wrong. It now says
  "You won the house. You offered $X. The next best offer was $Y, so that is
  what you pay." The same statement went into the houses instructions, both
  the incentivised and unincentivised branches: stating the second-price
  rule is not a leak, it is what makes truthful bidding optimal, and a
  participant who is not told it assumes first-price and shades. That
  paragraph also closes pilot note 16 -- an offer at the listed price can
  lose, because `compHigh = 1.10` puts the threshold above list by design,
  and nothing on screen had ever said so. Jobs is untouched: participants
  name their *lowest acceptable* wage, so being paid above it needs no
  explanation
- [ ] next (S) **the incentivised jobs instructions still tell participants
  to shade.** `utils.incentives('instructions','jobs',...)` says "it is in
  your interest to ask for the most you think the employer will agree to",
  which is the first-price advice under a mechanism that pays the threshold
  either way. Dead text today (`cfg.incentives.enabled = false`) and left
  alone deliberately, since the pilot note was about houses -- but it should
  match the houses wording before incentives are ever switched on
- [x] 2026-09-16 **the jobs wage grid did not survive anchor-centred
  windowing; fixed.** Found 2026-09-16 from the staff pilot. `synthetic` is a
  balanced orthogonal factorial: *every* attribute takes exactly 4 levels,
  wage included (15/25/34/86), which is correct for estimating attribute
  weights and is what the arm exists for. But wage does double duty as the
  advertised anchor, and `utils.sampleWindow` then slices that dimension --
  a participant anchored at $60/hr sees **one** distinct wage, at $18 or
  $40 two, at $25 three. With one value the anchor is collinear with the
  intercept and its coefficient is not identified at all; with two there is
  a slope and nothing about curvature. Houses are unaffected (22-36
  distinct prices per window, no widening). `ecological` and `attenuated`
  both give 17-33 distinct wages per window. Fixed by giving wage its own
  grid rather than by switching arms. **The level count was not the whole
  story:** at 12 quantile-spaced levels the worst window still held 2
  distinct wages at an $80 anchor, because quantile midpoints inherit the
  real wage distribution's skew and put 11 of 12 levels below $50. The
  window is a fixed *ratio* band, so the grid has to be geometric to match
  it -- 12/14/17/20/24/30/36/43/52/63/76/92 holds 4-6 distinct wages at
  every anchor from $15 to $80, where `elicitAnchor` accepts $7-$200.
  `stimgen/window_check.py` is the check, and it mirrors `sampleWindow`'s
  widening loop rather than reading the column: more levels in the file is
  not the same as more levels inside a window
- [x] 2026-09-16 **within-level jitter on the synthetic arm** (`jitter: 0.5`,
  a fraction of the half-gap to the nearest neighbouring level, so one
  number serves both a 1-5 rating scale and a $12-$92 geometric wage grid).
  A bare factorial showed every participant the same four numbers over and
  over, which no real listing set does. It costs the design nothing -- the
  level assignment is drawn first, so balance and orthogonality are
  untouched, and value-space `max |r|` actually *fell* 0.19 -> 0.17 because
  independent noise attenuates correlations. Checked by recovering every
  value back to its nearest level: per-level counts still exactly 32/32 for
  the ratings and 10-11 for wage. It also does most of the windowing work on
  its own, taking distinct wages per window from 4-6 to 10-26. Nothing
  downstream matches on exact attribute values (`buildPairs` scores
  z-scored continuous contrasts), and both tasks already render ratings as
  `%.1f / 5`
- [x] 2026-09-16 **competition is blocked**, 24 trials in 4 ABBA blocks of
  6, starting level counterbalanced by participant parity in
  `utils.trialPlan` (the same trick `utils.batteryPlan` uses for task
  order). It was trial-wise randomised before, which is why neither pilot
  participant noticed the level changing -- with nothing to form an
  expectation from, the manipulation barely operated, and
  `thresholdNoise = 0.12` already keeps the outcome uncertain while the
  regime is learnable. ABBA rather than one 12-trial run per level: it puts
  both levels at the same mean serial position, so competition is
  orthogonal to fatigue and practice *within* a participant and not just on
  average across the sample. `cfg.auction.nBlocks = 2` reverts. Two things
  that had to be got right: the break fires on a **competition change**,
  not a block index -- under ABBA blocks 2 and 3 are the same level and one
  continuous run, so announcing a new market there would be a false
  statement -- and an odd trial count now reduces the block count with a
  warning instead of erroring, because `trialsPerCell = 3` is 6 trials and
  a dress rehearsal must not be what discovers that 4 does not divide 6.
  `block` and `blockPos` are on every trial and in the CSV; practice is
  `NaN` on both
- [x] 2026-09-16 **house prices are now FITTED onto the anchor window
  rather than selected into it** (`utils.fitToWindow` behind the new
  `utils.applyWindow` dispatcher, `cfg.sampling.fitToWindow.houses`).
  Measured after the trial count doubled, and the doubling turned out not
  to be the problem -- it made an existing one visible. 80 houses spanning
  126:1 in price against a 2.67:1 window left **7-23 stimuli in a window at
  every anchor except $500k**, so the same house appeared ~21 times over 24
  trials, ~5 per block. That is the pilot's repeated-house complaint and it
  is also **item 14, now diagnosed rather than guessed**: contdc needs
  `nLevels x nPairs x 2` = 36 distinct houses with cross-level reuse
  blocked, and `utils.buildPairs` was hitting its `:short` warning. Fitting
  gives all 80 at every anchor, occupancy 20/21/21/20 across four
  log-slices, reuse down to 3.6x over the whole task and under 1x per
  block. Rank order and tied prices survive exactly, so the Spearman
  correlation with the attributes is unchanged (+0.749 with square footage)
  and `buildPairs` z-scores the money dimension anyway. Widening the window
  instead does not work: it takes `[0.30 4.00]`, a 13:1 band, before every
  anchor clears 36, at which point the anchor manipulation is gone. Real
  prices are kept in `win.priceMap`, which is their only record
- [ ] now (S) **the fit means all 80 houses load photos, not a subset.**
  `utils.loadStimulusTextures` loads `nImageVars x nStimuli` = 6 x 80 = 480
  textures for houses over the lab share, where before it loaded only the
  ~35 that the plan actually used. It is a one-off up-front load with a
  progress bar, not a per-block pause, but time it on the first rig run --
  if it is painful, `cfg.auction.nOptionsPerTrial` from 12 to 8 is the
  cheapest lever
- [ ] next (S) **jobs contdc is short of distinct stimuli at high anchors.**
  It needs 3 x 10 x 2 = 60 and the window holds 40 at an $80 anchor, 53-60
  elsewhere. The same shortfall houses just had, an order of magnitude
  milder. Either drop `cfg.contdc.nPairs.jobs`, or turn
  `cfg.sampling.fitToWindow.jobs` on too -- wage is orthogonal to the
  attributes by construction in the synthetic arm, so fitting costs that
  arm nothing except the real wage marginals
- [x] 2026-09-16 **the incentive bonus scales are anchor-relative now.**
  Pre-existing and unrelated to fitting, but found next to it: a flat
  `$1 per $20k of surplus` paid a $750k-budget participant several times a
  $150k one for identical behaviour, because the window has always been
  `[0.6 1.6] x anchor`. Now `surplus / anchor` times a scale chosen to
  reproduce the old payout at a typical anchor. Dead code today
  (`cfg.incentives.enabled = false`), but it would have been a live problem
  the moment it was switched on
- [ ] next (S) **24 trials doubles auction stimulus reuse for jobs.** 288
  presentations where there were 144, from a 40-60 window, so each job is
  seen ~5 times rather than ~2.5 -- `repIdx` logs it, but memory effects
  are twice what they were. Up to 24 items can also be won and retired
  rather than 12; `minOptionsAfterRetire = 6` stops a market running empty.
  Houses is no longer affected (3.6x). Check `repIdx` and the retirement
  count on the first real run
- [x] 2026-09-16 **the auction bid is now made with the option on screen**
  (item 10). Bidding was a separate full screen with nothing on it but the
  arc, so for the whole pricing response there was nothing to look at --
  and the reversal prediction is specifically that pricing pulls attention
  onto the monetary dimension while choosing pulls it onto the qualitative
  ones. That was testable in contdc, whose price trial already had the card
  beside the scale, and not in the auction. Both screens now come from the
  same `utils.layoutCardAndArc` and carry AOIs from the same
  `utils.cardAOIs`, so gaze on the two is directly comparable. Saved as
  `bidAoiRects` / `bidAoiNames` / `bidAoiReport`, and `preflight` checks
  them so `allAoiOK` covers the screen
- [x] 2026-09-16 **found and fixed a live AOI bug while doing item 10.**
  The card geometry existed in three copies -- `continuous_DC_task`,
  `preflight`, and in spirit `auction_task` -- and they had drifted exactly
  as `verify_static.sh` predicted. Pilot note 18 raised the identity header
  advance to `s.identityTextHeightPx = 42` and guarded the task copy;
  preflight's copy kept the literal `30`. So every contdc choice and price
  AOI rect that `pfAoi.allAoiOK` validated sat **12 px above the cells
  actually drawn** -- and that assertion is the first thing
  `verify_matlab.m` runs at the rig. Fixed by deleting the duplicates
  rather than adding a third guard: `utils.cardAOIs`,
  `utils.drawOptionCard`, `utils.layoutCardAndArc`, `utils.layoutDetailAOIs`,
  `utils.identityString`, `utils.valueString`, `utils.hasTextIdentity`,
  `utils.reserveIdentityStrip`. The detail view's own advance is now
  `s.detailTextHeightPx` too. Both tasks lost ~7 local functions each
- [ ] next (S) **the grid layouts are still duplicated in `preflight`.**
  `auctionAOIs` and the two-card half of `contdcAOIs` still restate
  `layoutGrid` and `layoutTwoCards` by hand. Narrower than the card
  duplication was and still pinned by literal guards in
  `verify_static.sh`, but it is the same class of bug and the same fix
- [ ] next (S) **orthogonality is optimised over all 128 rows, but nobody
  ever sees all 128.** `window_check.py --attrs` reports within-window
  `max |r|` at 0.19-0.32 for the synthetic arm, which is roughly what
  finite-sample noise gives at n = 40-66, so this is probably nothing. Worth
  one deliberate look before collection rather than a shrug. It also kills
  the `attenuated` fallback for good: in-window it runs 0.43-0.76, far worse
  than the r = 0.5 its config advertises
- [x] 2026-09-16 set `TRIALS_PER_CELL = []` in `run_battery.m` for the
  staff practice run -- full trial counts, everything else already real.
  Note this locks in the *current* config as the baseline while the
  conditions task below is still open: `nTrials = 12`, `nPairs` 6 houses /
  10 jobs, `attrLevels = [2 4 6]`, `JOBS_ARM = 'synthetic'`. If any of
  those move afterwards, the practice run does not describe the real one
- [x] 2026-09-16 fixed the invisible cursor on the auction's comprehension
  check. `utils.elicitVAS` ended with `HideCursor`, elicitation runs before
  the instructions, and nothing showed it again -- so the two-box check was
  an aimed click with no pointer. Removed the hide (every gaze trial
  re-shows the cursor at `awaitFixationStart` anyway, so it bought nothing)
  and made `askComprehension` show its own. Also switched that screen off
  raw `GetMouse(window)` onto `utils.getMouse`: it runs right after the
  window opens, which is exactly when the raw call has been seen to return
  NaN on Windows without throwing, straight into a `Screen('DrawLine')`
- [x] 2026-09-16 listed price / offered wage is now rated alongside the pool
  attributes (`+utils/elicitAttrRatings.m`) and excluded from selection --
  it is always shown, so its rating decides nothing. Stored as
  `coreRatings` / `coreRatingRTs` / `coreLabels` per domain; the session
  elicitation cache normalises the field so a session straddling this change
  still runs
- [ ] next (S) **decide whether `A.late` should be rated too.** Work
  arrangement is jobs' only late attribute, is shown at the top level, and
  has no stated weight -- the same gap price had until today. It is not
  rating-selected either, so this is purely about having the number
- [ ] next (S) **houses' stratified selection is degenerate at level 6** --
  5 pool attributes and 5 slots, so every participant sees the same five
  regardless of what they rated. Jobs picks 4 of 8 there. Either accept it
  or fold it into the attribute-data task below
- [x] 2026-09-16 dropped Region (the Zone column) from the house attributes
  -- not part of the current design. Houses now has no late tier, which means
  its max level is exactly 6 (price + all 5 pool attributes), so every
  attribute a participant rates can actually appear. Definition kept
  commented in `attributes.m` and the column stays in the CSV, so restoring
  it is one edit
- [x] 2026-09-16 anchor input now groups thousands as you type (350000 shows
  as $350,000). This is the field where an order-of-magnitude typo silently
  rescales every stimulus the participant then sees, via `sampleWindow`
- [ ] next (M) **houses has only 5 rated attributes to jobs' 8**, and the
  stimulus CSV has no unused columns to promote. If the two domains need to
  be comparable in information load, houses needs new attribute data
  (garage, HOA, school rating, days on market...) generated with the same
  correlation control as the jobs arms
- [x] 2026-09-16 added `+utils/positionGuide.m`: a head-position screen before
  calibration showing where the tracker sees the participant's eyes against a
  target zone, with a depth bar and one instruction at a time. Uses Tobii
  track-box coordinates only (gaze point is uncalibrated at that stage and
  would be meaningless). Skippable by click, times out at 90s, every SDK
  access wrapped -- a positioning aid must never be why a session cannot run.
  Whether the participant got in position is saved as
  `dataMat.eyeTracking.positioned`
- [ ] now (S) **verify the track-box property name against this SDK build.**
  `positionGuide` tries `in_track_box_coordinate_system` then
  `position_in_track_box_coordinate_system`; if neither matches, the screen
  says "Looking for your eyes..." forever until the timeout. First rig run
  will show this immediately
- [x] 2026-09-16 post-pilot round: saving screens with a real staged progress
  bar and a neutral "Did you know..." panel around both blocking writes (the
  end-of-block freeze); value labels now "Offered wage" / "Listed price";
  hourly wages in whole dollars with the response snapped to match; fewer and
  thinner scale ticks; live price moved above the arc instead of inside it;
  advertised-value marker on the pricing scale; rejected stimulus indices
  added to the auction CSV; quit key announced on every instruction screen
- [x] 2026-09-16 randomised the pricing-arc start position in both tasks and
  recorded it (`bidStartFrac` / `startFrac`). The cursor used to begin at the
  scale midpoint every trial, which is a constant nuisance anchor; starting it
  at the advertised value would have been worse, since the anchor would then
  covary with the main predictor of the response. Random is the only start
  that cannot bias an estimate, and logging it keeps residual anchoring
  testable rather than baked in
- [ ] now (S) **decide whether to keep `cfg.display.showValueMarker`.** It was
  asked for and it is on, but marking the listed price on the response scale
  is an anchor on the dependent variable under BDM. Worth a deliberate call
  before participant 1, not a default
- [x] 2026-09-16 added `TRIALS_PER_CELL` to `run_battery.m`: a dress-rehearsal
  knob that shortens counts and changes nothing else. `[]` = full study. Set
  to 2 currently. Deliberately separate from `cfg.testing`, which also forces
  windowed mode, skips elicitation/instructions/practice and pins participant
  9999 -- none of which a rehearsal wants. Saved as `dataMat.trialsPerCell`
  so a short run is filterable out of analysis later
- [x] 2026-09-15 fixed three task-design problems found before the pilot:
  dropped the job title from the card header (the `synthetic` arm renders it
  as `title_001`), reserved the late tier inside `nAttrs` so attribute level 6
  is 6 cells and not 7, and stopped colour-emphasising wage/price inside the
  attribute grid
- [x] 2026-09-15 restyled the battery: warm dark theme, rounded panels via a
  new `+utils/roundRect.m`, run-time font probing via `+utils/resolveFonts.m`,
  and `+utils/style.m` restructured as an `HW_THEME` switch with the original
  look kept verbatim as `arcade`. Statically verified only
- [ ] now (S) first real execution of all of the above, at the rig:
  `scripts/verify_matlab.m` (asserts `allAoiOK`), then `preflight`, then
  `demo_battery` -- budget 20 minutes for the demo, not 6. Look hardest at
  the price arc and the VAS line, which are where the softer palette was most
  likely to have gone too far
- [ ] now (M) settle the conditions and design — which PLAN rows, which `JOBS_ARM` (three are prepared and committed: `attenuated`, `ecological`, `synthetic`), `attrLevels`, `nTrials`/`nPairs`. The knob table is in review section D. Check the choice against `docs/grant/Wage_and_House_Pricing_Model_Grant_Proposal.pdf` — the proposal may already commit to conditions, and diverging from it silently is worse than diverging deliberately. **This gates everything downstream**
- [ ] now (S) write down what "runs seamlessly and pleasantly" means as checkable criteria *before* the rehearsal, so the dress run has a pass/fail bar rather than a vibe. Candidates: no visible stutter between trials, no dead time a participant would read as a crash, every instruction understood without asking, a mis-click always recoverable, and the participant always able to tell where they are and how much is left
- [ ] next (S) run `preflight.m` against the finalised design and check the block schedule and estimated duration are tolerable to sit through — it prints both
- [ ] next (L) dress rehearsal on the lab rig, once conditions are settled: confirm monitor diagonal and viewing distance in `rigProfiles`, then one full TESTING run **and** one full real-mode run as a throwaway participant. Open the saved `.mat`, `.csv` and gaze files afterwards and check every field before participant 1
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
- [x] 2026-09-16 deployed to the lab share (6 commits; 97 files backed up to
  `Archive\Experiment_pre-2026-09-16_181240`, 80 replaced, 3 added) and
  pushed 30 commits to GitHub, which had been stale since 2026-08-18. The
  repo already existed and was simply not being pushed to
- [ ] now (M) **put the lab machine on git** -- steps written up in
  `docs/lab-machine-git.md`, needs a keyboard at the rig. Plan is to make
  the share's `housing_wages/` itself the working tree: `utils.config`
  defaults `projRoot` to the share root, and Windows does not distinguish
  the repo's `experiment/` from the share's `Experiment/`, so it lines up
  with no config changes. Read-only deploy key so a shared machine never
  holds a credential that can push. Delete `deploy_to_share.ps1` in the
  same commit that finishes it -- two live mechanisms is worse than either
- [ ] next (S) **decide how collaborators get access.** The repo is private
  on a personal account. Check whether OSU runs GitHub Enterprise first: an
  org-owned repo outlives an individual account, which matters for
  something that will be cited. A clone gives code, stimulus definitions,
  `WORK.md` and `docs/` -- not the 605MB image set, the Tobii SDK, or
  participant data, so it is enough to read the project and run the
  analysis on exported CSVs but not to run a session
- [x] 2026-09-16 **participant data and the image set are out of the git
  tree.** Both were gitignored and inside what is about to become the
  working tree, so `git clean -fdx` would have deleted every participant
  with git raising no objection -- and the deploy script's `Archive/`
  backups exclude both, so there was no second copy.
  `scripts/move_out_of_tree.ps1` moved them to `housing_wages_local/`
  (41 files / 2,796 MB of data, 485 files / 605 MB of images), verifying
  counts and bytes on both sides. `cfg.paths.local` is the new root and
  `utils.verifyPaths` lists it under MUST ALREADY EXIST, so a restored old
  layout is reported rather than discovered mid-session. The clone is no
  longer blocked
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
