---
project: housing-decisions
---

# Work — housing-decisions

## Now

**Session update 2026-09-21.** The pricing scale baseline now sits at the
inner end of the major ticks and is drawn as a solid arc rather than the old
minor-tick comb. Auction bidding and contdc pricing were changed together;
`bash scripts/verify_static.sh` passes. MATLAB/Psychtoolbox execution still
has to happen at the rig.

**Same session:** added a standalone house-photo style preference task,
`experiment/photo_preference_task.m`. It can run direct ratings, pairwise
choices, or both over individual house photos, sampling 80 photos by editable
area quotas and defaulting to 160 BTL-ready pairwise comparisons. Statically
verified only; the first image-load and click-through check needs MATLAB/PTB.

**Session update 2026-09-18.** `utils.verifyPaths(utils.config('rig','lab'))`
has run at the rig and confirmed all required paths look correct, so the
out-of-tree move no longer gates the next pilot check. Of the pilot's 21
notes, 17 are done; the active remaining pilot gate is executing the
drag-and-drop ratings (2) on the rig. The track-box guide (9) is pinned off
after the rig showed no live feedback; the 998/999 QA (20) waits on the
`dataMat` exporter; the mid-task drift flag (15) is deliberately
down-prioritised.

**In flight, on the lab machine, not here.** Murray is at the rig
converting the share into a git checkout --
`docs/lab-machine-git.md` is the runbook. Step 0 (`utils.verifyPaths`) passed
on 2026-09-18; continue with the remaining runbook steps when ready. Handoff packet:
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

**What is left of the pilot backlog:** verifying the drag-and-drop ratings
actually run (2) is the active rig-side next check; the rig diagnostic (9,
track-box property name) remains; the 998/999 data QA (20) still needs the
`dataMat` exporter before its gaze half can be done; the mid-task drift flag
(15) is not a collection gate for now.

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
- [x] 2026-09-23 **pre-sharing sweep before adding a collaborator.** Privacy
  audit came back clean: one git identity across all history, no personal
  content in any current or historical file, no AI mentions in any file.
  Comment diet across the whole codebase: MATLAB comment lines 2,569 -> 796
  (-69%), R/Python/PowerShell similarly, every change machine-verified as
  comment-only (line counts, Python AST compare, PowerShell code compare)
  and `verify_static.sh` green. Deleted rationale essays live only in git
  history now — the Lichtenstein & Slovic citation and design notes from
  buildPairs/elicitVASDrag may be wanted for the methods write-up. New
  `docs/CODE-GUIDE.md` is the grad-student orientation, linked from README.
  History scrubbed 2026-09-23: all Co-Authored-By trailers rewritten out of
  every commit, trees verified identical, force-pushed; pre-scrub bundle in
  the session scratchpad and local `refs/original` kept as backups. AGENTS.md
  stays. Cross-platform audit for the Mac collaborator: index is all-LF, no
  case-clash filenames, no bashisms, R pipeline path-portable — sound on
  Windows/Linux/macOS (experiment itself is rig-only, documented in
  CODE-GUIDE). `moontran044` invited with write access 2026-09-23, pending
  her acceptance. Portfolio-wide sweep playbook:
  `~/.agents/handoffs/HANDOFF-code-sharing-sweep.md`. No-AI-attribution is
  now policy in the daisywheel working agreement and ~/.claude/settings.json
- [x] 2026-09-23 **the preference task is now a battery task** (`pref` rows in
  `utils.batteryPlan`), renamed `photo_preference_task.m` ->
  `preference_task.m` and converted to the `(sess, run)` function form.
  Both sessions have three tasks counterbalanced over all 6 orders by
  `mod(participant, 6)`; jobs' version is pairwise-only over industry +
  job title text cards, mixed across industries, and always reads the
  ECOLOGICAL stimulus file (the synthetic arm's titles are `title_001`
  placeholders -- `buildJobPreferencePlan` errors if one reaches it).
  Every pref trial now has a jittered blank ISI (0.4-0.7 s) and a 0.5 s
  centered fixation cue, and the task records gaze through the same
  `setupEyeTracker`/`gazeBuffer`/`eventLog`/`clockSync` plumbing as the
  other tasks, with screen geometry saved once per domain as
  `dataMat.(domain).layout`. Data lands in `Data/pref` (the old
  `Data/photo_pref` on the share is untouched history). NOTE the share
  still carries the now-orphaned `photo_preference_task.m` -- the deploy
  script never deletes; it dies when the share becomes a git checkout
- [x] 2026-09-23 **component timing**: new `utils.timeline` gives every task
  a per-section wall-clock breakdown saved as `dataMat.timing`
  (elicitation / instructions / practice / trials / saving per domain),
  and `run_battery` collects them plus a per-task total into
  `Data/sessions/sub-XXXXX_ses-NN_timing.csv`, rewritten after every run
  so a crash keeps completed rows, and prints the breakdown at session
  end. `preflight`'s duration estimate covers the pref rows too
- [x] 2026-09-23 photo task revisions from the first rig run: photos are
  center-cropped to the box aspect so every photo fills the identical
  on-screen rect (no more size variation between photos); pairwise responses
  are now the Z (left) and M (right) keys with the cursor hidden for the
  section; and pairwise trials only ever compare photos of the same area
  (kitchen vs kitchen, ...), allocated across areas proportional to their
  rating quotas in `buildPhotoPreferencePlan` — at the 80/160 defaults that
  is 28 pairs each for exterior/kitchen and 26 for the rest, and the trial
  prompt now names the area ("Which kitchen do you prefer?"). All pinned in
  `verify_static.sh`; redeployed to the share
- [x] 2026-09-23 fixed the photo task's rig crash at the `Screen('Preference')`
  line: `skipSyncTests` is a logical in `rigProfiles` and Screen rejects
  logicals, so it now casts to double like the battery tasks. The same display
  block was also missing `PsychDefaultSetup(2)` (style colors are 0-1, so
  every panel would have rendered near-black) and the alpha blend function;
  both added, and all three are now pinned by `verify_static.sh`. Redeployed
  to the share. Still needs its first full click-through at the rig
- [x] 2026-09-21 standalone house-photo preference task added:
  `photo_preference_task.m` writes its own `photo_pref` run, samples
  individual photos from all six house areas with editable quotas, supports
  `rating`, `pwc`, or `both`, and emits BTL-ready chosen/unchosen columns.
  Needs first MATLAB/PTB execution at the rig or a machine with the house
  images present
- [x] 2026-09-21 pricing scale baseline moved to the bottom/inner edge of
  the major ticks in both auction bidding and contdc pricing, with the old
  dense minor-tick comb removed so the scale reads as one solid line.
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
- [ ] now (S) **execute the drag-and-drop ratings at the rig.** It is the largest
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
  is also **item 14, now diagnosed rather than guessed**: under the old
  cross-level reuse block, contdc needed `nLevels x nPairs x 2` = 36
  distinct houses and `utils.buildPairs` was hitting its `:short` warning. Fitting
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
- [ ] next (S) **diagnose the track-box property name against this SDK build.**
  `positionGuide` stayed on "Looking for your eyes..." at the rig on
  2026-09-18, so `cfg.et.positionGuide.enabled` is now false and calibration
  proceeds without that participant screen. Run `utils.diagnoseTrackBox` at
  the rig, update the field access, then turn the guide back on only after it
  shows live dots
- [x] 2026-09-16 post-pilot round: saving screens with a real staged progress
  bar and a neutral "Did you know..." panel around both blocking writes (the
  end-of-block freeze); value labels now "Offered wage" / "Listed price";
  hourly wages in whole dollars with the response snapped to match; fewer and
  thinner scale ticks; live price moved above the arc instead of inside it;
  advertised-value marker on the pricing scale; rejected stimulus indices
  added to the auction CSV; quit key announced on every instruction screen
- [x] 2026-09-18 removed forced pricing-arc cursor starts in both tasks. The
  2026-09-16 random start was understandable as an anti-anchor move, but in
  practice it read as another unexplained task feature. The mouse now stays
  wherever it already is at pricing onset, and `bidStartFrac` / `startFrac`
  are `NaN` to mark that nothing was forced
- [x] 2026-09-18 pricing scale adjusted from the rig: minor ticks shortened,
  major tick labels enlarged, the live updating price lifted above the major
  tick labels, and the post-practice auction screen now explicitly says the
  practice round is over and invites questions before real markets begin
- [x] 2026-09-18 continuous-DC cross-level reuse is now allowed by default
  (`cfg.contdc.allowCrossLevelReuse = true`) so 2/4/6-attribute cells keep
  balanced trial counts. Any remaining short pair generation is fatal before
  the task starts rather than silently shortening one attribute condition
- [x] 2026-09-18 added a share-to-local data pull path:
  `scripts/pull_data_from_share.ps1` copies `Experiment\Data` into ignored
  `data/lab/Data`, writes a pull manifest, and runs `analysis/R/run_all.R`;
  the R integrity report now flags continuous-DC cells where price rows are
  not exactly 2x choice rows
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
- [ ] next (S) first real execution of all of the above, at the rig:
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
- [x] 2026-09-18 deployed the runnable manifest to the lab share for rig
  testing: 108 files backed up to
  `Archive\Experiment_pre-2026-09-18_112856`, 91 replaced, 0 added, no
  problems reported. `Experiment\Data` and `Experiment\stimuli\house_images`
  were deliberately untouched
- [x] 2026-09-18 redeployed with the broken head-position guide pinned off:
  108 files backed up to `Archive\Experiment_pre-2026-09-18_113316`, 91
  replaced, 1 added (`Experiment\+utils\diagnoseTrackBox.m`), no problems
  reported
- [x] 2026-09-18 redeployed the pricing-scale and practice-boundary updates:
  109 files backed up to `Archive\Experiment_pre-2026-09-18_113740`, 92
  replaced, 0 added, no problems reported
- [x] 2026-09-18 redeployed the balanced continuous-DC reuse policy: 92 files
  backed up to `Archive\Experiment_pre-2026-09-18_114559`, 92 replaced, 0
  added, no problems reported
- [x] 2026-09-23 redeployed to the lab share: 93 files backed up to
  `Archive\Experiment_pre-2026-09-23_140213`, 93 replaced, 1 added
  (`photo_preference_task.m`, which was missing from the deploy manifest —
  now added). The share's `+utils\config.m` was stale and still pointed at
  `housing_wages_local` (confirmed in the backup), which is why the rig was
  saving there; the deployed copy is verified clean
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
- [x] 2026-09-18 **reverted the sibling-directory path strategy.**
  Participant data and house images stay in `Experiment\Data` and
  `Experiment\stimuli\house_images`; `.gitignore` is the protection. The
  task config and pull script point back at the in-tree ignored locations,
  and the old mover script is removed so it cannot be run again
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
