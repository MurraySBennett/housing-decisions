# Housing & Wages: Search, Pricing, and Choice

Project rundown, design decisions, and analysis plan. Read this before
touching `run_battery.m`. Last revised after the image-loading and
stimulus-reuse fixes — a lot has changed underneath this since it was
first written, including the whole package moving from `+hw` to `+utils`.
If you see `hw.` anywhere in comments or old notes, it means `utils.` now.

## Block checkpoint storage

The development checkpoint format saves verified local blocks and resumes the
first unfinished block. See [operator instructions and release checks](BLOCK_CHECKPOINTS.md)
for locations, logging, offline sync, combining, and required MATLAB/rig validation.
This format is not yet cleared for participant deployment.

## What this is

Two tasks, sharing one participant-management layer, testing three
extensions to the Price Accumulation model of dynamic pricing: attribute
weights, multiple anchors, and rejection thresholds.

- **`auction_task.m`** -- sequential search with a continuous BDM price
  response. Options arrive and expire on a market with a vacancy gap after
  each one leaves; the participant inspects, rejects, or bids. 24 trials
  (search episodes) in 4 ABBA blocks of 6, competition blocked with the
  starting level counterbalanced by participant parity, fixed at 6
  attributes. **The bid is made with the option on screen** — card left,
  price arc right, the same `utils.layoutCardAndArc` geometry contdc's
  price trial uses — so attribute re-inspection *during* pricing is in the
  gaze record and is directly comparable between the two tasks.
- **`continuous_DC_task.m`** -- pricing vs. discrete choice on the same
  option pairs, crossed with attribute count (2/4/6). Carries the
  attribute-load manipulation, because its trials are short enough to
  afford three levels where the auction's longer search episodes are not.

Both run through one participant-management layer (`+utils`) that handles
identity, counterbalancing, crash recovery, eye tracking, elicitation reuse,
and linking data across tasks and domains.

## Why two domains, and how personalization works

Houses and jobs are structurally parallel markets with a genuinely
different answer, which is the point. Each participant's own budget
(houses) or reservation wage (jobs) is elicited first and used two ways:

1. **Stimulus window.** `utils.sampleWindow` centers the shown price range
   on that anchor rather than filtering to it -- the house stimulus set
   (80 items) can't support a budget-filtered block of 12+ options, and
   filtering would also kill the price variance the anchor manipulation
   needs. See `+utils/sampleWindow.m`.
2. **Attribute selection.** A visual-analogue rating of each attribute's
   importance, collected once per domain, drives which attributes appear at
   each load level (`utils.selectAttributes`, rank-stratified by default).

**This is why different participants see different specific stimuli, and
why that's fine.** What has to be constant across participants is trial
*counts* and design *structure* -- `cfg.auction.nTrials`,
`cfg.contdc.nPairs`, the attribute levels, the competition levels -- not
which literal house or job appears. The model estimates weights and
thresholds per participant; comparability comes from every participant
facing the same number of trials at the same manipulated levels, each
constructed by the same selection rule, not from facing the same items.
This is standard practice (compare: different word lists per participant in
a memory experiment, same design) but it's worth stating explicitly because
it's easy to conflate "same design" with "same stimuli."

Pairs in `continuous_DC_task` are constructed once per participant per
attribute level (`utils.buildPairs`), then used for BOTH the choice block
and the pricing block at that level -- that identity is what makes a
preference reversal measurable at all. It is not built once globally and
shared across participants. See **Stimulus reuse** below for how far that
sharing extends (and doesn't) across attribute levels.

## House attributes: photos are identity, not pool

Worth calling out on its own because it changed after the design first
shipped, and it fixed two separate bugs at once (see **Known gotchas**).
All six house photos (exterior, kitchen, bedroom, bathroom, living room,
outdoor) are **identity** attributes: always shown, at every attribute-count
level, never counted toward it. The attribute-count pool for houses is now
purely the five numeric attributes (bedrooms, bathrooms, sqft, lot size,
year built) -- `cfg.attrLevels = [2 4 6]` still means core-price plus
1/3/5 of those.

Two consequences worth knowing. First, this is *why* the attribute pool is
guaranteed to have a usable quality dimension at every level now --
`utils.buildPairs` needs at least one numeric non-price attribute to build
a money-vs-quality contrast, and before this change a low attribute level
could land on a photo-only pool selection with nothing numeric to work
with. Second, `A.maxLevel` (core + pool) is now exactly 6 for houses,
matching `cfg.attrLevels`'s top value precisely -- no orphaned pool
attributes that attribute level 6 never reaches.

Jobs have no image identity attributes at all, so none of this applies
there; industry/title are the only identity fields and stay text-only.

## The value attribute is rated, and then ignored by the selection

`utils.elicitAttrRatings` puts the core attribute -- listed price for
houses, offered wage for jobs -- on the same importance line as the pool,
in the same randomised order. Its rating goes to
`dataMat.<domain>.coreRatings` and **nothing reads it at run time**:
`utils.selectAttributes` still receives pool ratings only, because the core
attribute is on every card at every attribute level and no rating could
change that. The point of collecting it is the analysis -- it is the one
attribute for which there was no stated weight on the same scale as the
others, which made stated-versus-revealed comparison impossible for
precisely the variable the pricing model turns on.

The cost is real and is written up in the function's header: price sits at
the top of the line for most people, which compresses the pool attributes
into the remainder of the scale. Rank order (all `utils.selectAttributes`
reads) is unaffected; the raw pool values are not comparable to pool values
collected before this change.

## Image loading

Rebuilt entirely after images turned out not to be rendering at all in an
earlier version. Two separate problems, both fixed:

**Scope and timing.** Textures used to be loaded for every stimulus in the
*sampled window* (which can hold several times more candidates than any
trial ever shows -- e.g. 96 sampled but only ~50 ever displayed), and in
`continuous_DC_task` that reload happened *every block*, not once per
domain. `utils.loadStimulusTextures` now takes the union of stimulus
indices that will actually appear (computed from the trial plan or the
built pairs, before any loading starts) and loads exactly that set, once,
with a "FETCHING PHOTOS..." progress screen -- this is the load screen
that existed in an earlier version of the task and was reinstated here.
Verified: roughly an order-of-magnitude fewer texture loads than the old
per-block, whole-window approach.

**Path mismatches.** The stimulus CSV can contain image filenames with a
leftover path prefix from an old folder layout (e.g.
`.\Stimuli\Images\ext1.png`) while the actual files sit flat in
`cfg.paths.images` as bare names (`ext1.png`). `utils.readStimuli` now
strips every image-kind column down to its bare filename once, at load
time, regardless of what prefix the CSV happens to contain -- so this
can't recur even if the CSV changes again. If images still don't render,
run:

```matlab
utils.checkImages(utils.config('rig','lab'), 'houses')
```

No PTB or running task needed -- it samples stimulus rows, checks whether
the exact expected file exists in `cfg.paths.images`, and if not, looks for
a near-match on disk (case, extension, stray whitespace) so the actual
mismatch is visible instead of a silent blank image.

## Task/domain independence

`run_battery.m` dispatches from a `PLAN`: three task rows for one assigned
domain. Real collection is between-subjects: odd participant IDs run jobs /
wages, even participant IDs run houses. At startup, `utils.startSession`
proposes the next participant ID, assigned domain, and task-order slot; the
experimenter presses Enter to accept or `e` to edit for crash/data recovery.

Every run's saved filename and manifest entry carries both its task AND its
domain set (`sub-00012_ses-01_task-auction_dom-jobs_...`), so a participant
who does jobs-auction today and houses-contdc next week is fully
reconstructable from the manifest alone, and two runs of the same task over
different domains never collide.

**`FORCE_DOMAIN`** in `run_battery.m` overrides the parity-assigned domain
for quick manual testing. Leave it `''` for real sessions; if recovery needs
a real override, use the startup edit path so the manifest and saved `dataMat`
record `assignmentOverride`.

## Elicitation is cached within a session, re-asked across sessions

If a participant runs both tasks on the same domain in one sitting (e.g.
auction then contdc on jobs), the second task reuses the first's budget/
reservation-wage anchor and attribute ratings rather than asking again --
`utils.elicitationCache`, keyed on (participant, session, domain), stored
on disk. A **new session number is a deliberate cache miss**: if there's a
real day-break between sessions, re-eliciting gives a fresh, consistent
measurement rather than reusing a stated preference that may no longer
hold. This works whether the two tasks run back-to-back inside one
`run_battery` call or as separate MATLAB invocations later the same day,
as long as the session number matches.

## Eye tracking and trial structure

**Fixation-start gate.** Every trial (each auction search episode, each
choice trial, each price trial) begins with a click on a central crosshair
target (`utils.awaitFixationStart`) before the stimulus appears. Two jobs
in one screen: it's a self-paced "ready" signal, and it sets a known GAZE
START POINT -- you usually look at what you're about to click, so this
anchors gaze to a known location and time immediately before the trial's
first saccade, which matters for interpreting first-fixation latency and
direction. The click has to land within the target's hit region (~1 deg);
an off-target click is ignored rather than silently accepted. The
auction's market clock and each trial's RT timer both start from this
click's actual flip time, not from whenever the function happened to be
entered -- so an option's on-market window is never silently eaten by a
participant still reading the fixation screen.

**Pricing screens show the option.** The auction's bid screen and contdc's
price trial both put the option card beside the scale rather than replacing
it. This is a measurement requirement, not a layout preference: the
reversal prediction is that pricing pulls attention to the monetary
dimension while choosing pulls it to the qualitative ones, and that is
untestable if the attributes are off screen while the price is being set.
Both screens carry `bid_<attr>` / `price_<attr>` AOIs from the same
`utils.cardAOIs`.

**Trial screens stay clean.** Progress and condition info (trial number,
competition level, attribute count) show ONLY on the fixation-start screen
and at block boundaries (`showBlockIntro`) -- never during the actual
search grid, detail view, bid screen, choice cards, or price scale. Nothing
there should compete with the stimuli for gaze during the response itself.

**Cursor stays visible throughout** (`ShowCursor('Arrow', window)` at task
start, not `HideCursor`) -- almost every screen is click-driven.

## Auction market dynamics

- **Vacancy gap.** Removing an option (right-click reject, expiry, or a
  rejected bid) no longer allows instant replacement -- a box stays empty
  for a real gap (`cfg.auction.vacancyGapMean`, gamma-distributed like
  arrival timing) before it's eligible to receive the next queued option.
  Without this, a box that frees up while there's an arrival backlog
  refilled in the same frame, which didn't read as a market, just an
  infinite shuffle.
- **Competition timing is NOT scaled by testing mode.** `cfg.testing.enabled`
  never touches `cfg.auction.onMarketMean`/`dwellFactor` -- what you see in
  a dev/testing run is exactly what a real participant sees. If it feels
  too fast or slow, that's `cfg.auction`, tune it there; it isn't a
  testing-only artifact.
- **BDM pricing, not first-price.** A cleared bid pays/earns at the market
  THRESHOLD, not at the participant's own bid -- this is what makes
  truthful bidding optimal, unlike first-price where the recorded numbers
  would be strategically shaded rather than valuations.
- **Stochastic threshold.** The accept/reject threshold has noise around
  it (`cfg.auction.thresholdNoise`), so high competition changes the odds
  of a favourable outcome rather than making one impossible -- a
  deterministic threshold under high competition made surplus always
  negative by construction, which is an earnings manipulation disguised as
  a search-difficulty manipulation.

## Rig profiles: lab vs. dev

`utils.rigProfiles` supplies two named hardware configurations. AOI spacing
thresholds are defined in **degrees of visual angle**, not pixels, so
switching profiles automatically rescales what counts as "too close" for
whatever screen is actually in use -- there's one set of spacing rules, not
two.

| | `lab` | `dev` |
|---|---|---|
| Screen geometry | your actual monitor, confirm before data collection | generic 13" laptop, update if yours differs |
| Eye tracking | on by default | off by default |
| AOI spacing failures | warnings (fix before data collection) | informational only |
| `SkipSyncTests` | on for both (see gotchas below) | on for both |

Set `RIG = 'lab'` or `'dev'` at the top of `run_battery.m`. `lab` is the
only profile that should ever produce data that goes in the dataset.

## Calibration: two different things

The desktop calibration utility (if your lab uses the Tobii Pro Eye Tracker
Manager or similar) is a **hardware** step -- lens angle, lighting, display
profile -- done once when the rig is set up, independent of any participant.

`utils.calibrate` (a five-point `ScreenBasedCalibration`) is the
**per-participant, per-session** calibration every eye tracker needs
regardless of how the hardware itself was set up. This runs automatically
at the start of each task when `cfg.et.enabled` is true and
`cfg.testing.enabled` is false. Keep both: the desktop tool doesn't replace
per-participant calibration, and vice versa. `cfg.et.useBuiltInCalibration`
exists to turn the in-task version off only if calibration is being driven
by some other harness entirely.

## Incentives

Off by default (`cfg.incentives.enabled = false`). See `+utils/incentives.m`
for the BDM-based payment scheme and both the paid/unpaid instruction text.
Turning this on almost certainly needs an IRB amendment -- see the earlier
project discussion for the reasoning behind the payment structure
(random-incentivized-trial, threshold pricing, not first-price).

## Stimulus preparation

See `stimuli/README.md`. Three arms for the jobs domain (`synthetic`,
`ecological`, `attenuated`), selected at runtime via `JOBS_ARM` in
`run_battery.m` -- never by copying/renaming output files, which severs the
link to the provenance record. Houses need no preparation beyond the image
filename normalization described above.

## Design knobs

These are the participant-facing decision points worth checking before data
collection. `preflight.m` prints the resolved values for a specific
participant and session, including the counterbalanced task order and
estimated duration.

| knob | current value | where to change | why it matters |
|---|---:|---|---|
| Schedule | Odd IDs jobs/wages; even IDs houses; one session with auction+contdc+pref | `+utils/batteryPlan.m`, startup confirmation in `+utils/startSession.m` | Defines which task/domain rows a participant sees. |
| Task order counterbalance | Six task orders cycle within each domain via `ceil(participant/2)` | `+utils/batteryPlan.m` | Keeps jobs and houses separately balanced while IDs run sequentially. |
| `JOBS_ARM` | `synthetic` | `run_battery.m` | Selects the prepared job-stimulus arm and provenance file. |
| `FORCE_DOMAIN` | `''` | `run_battery.m` | Quick testing override; use startup edit for real recovery overrides. |
| `cfg.auction.nTrials` | 24 | `+utils/config.m` | Twelve trials per competition level. Must divide evenly by `nBlocks`. |
| `cfg.auction.nBlocks` | 4 | `+utils/config.m` | Competition is **blocked**, not re-rolled per trial: ABBA over 4 blocks, starting level counterbalanced by participant parity in `utils.trialPlan`. ABBA puts both levels at the same mean serial position, so competition is orthogonal to fatigue and practice within a participant. `2` is one long run per level -- more learnable, but confounded with session half. |
| `cfg.auction.nOptionsPerTrial` | 12 | `+utils/config.m` | Search-set size per auction episode; repeats are planned/logged if needed. |
| `cfg.sampling.fitToWindow` | houses `true`, jobs `false` | `+utils/config.m` | How the anchor window is filled. `false` selects the stimuli already priced inside it (`utils.sampleWindow`); `true` keeps every stimulus and fits its value onto the window by rank (`utils.fitToWindow`). Houses need it: 80 listings spanning 126:1 against a 2.67:1 window left 7–23 per window, short of the 36 contdc requires. Both tasks must go through `utils.applyWindow`. |
| `cfg.auction.trialTimeoutSec` | 90 | `+utils/config.m` | Main driver of auction duration. |
| Auction practice | 1 saved practice episode before real trials | `auction_task.m` | Keeps practice analyzable/excludable via `practice=true`. |
| `cfg.attrLevels` | `[2 4 6]` | `+utils/config.m` | Continuous/DC information-load manipulation. Counts include both the core attribute and, at the top level, the late-tier one, so a level of 6 renders exactly 6 cells. |
| `cfg.contdc.nPairs.houses` | 20 | `+utils/config.m` | Twenty choice pairs per attribute level; pricing gives two rows per pair. |
| `cfg.contdc.nPairs.jobs` | 20 | `+utils/config.m` | Twenty choice pairs per attribute level; pricing gives two rows per pair. |
| `cfg.contdc.allowCrossLevelReuse` | `true` | `+utils/config.m` | Allows the same item appearing at multiple attribute levels so 2/4/6-attribute cells stay balanced. |
| `TRIALS_PER_CELL` | `2` | `run_battery.m` | Dress-rehearsal knob. `[]` = the full study; an integer = that many trials in every design cell and **nothing else changes** (full screen, real pacing, real elicitation, instructions and practice, real participant number). Auction cells are the two competition levels, so N per cell means 2N trials; contdc cells are attribute level x task type, so it maps straight onto `nPairs`. Not the same as `cfg.testing.nTrialsPerType`, which sets the auction's *total* and only applies in developer mode. Saved as `dataMat.trialsPerCell`. |
| `cfg.display.showValueMarker` | `true` | `+utils/config.m` | Draws the advertised figure (listed price / offered wage) on the pricing scale. **Not cosmetic:** under BDM the optimal bid is the participant's own valuation, and a salient reference point on the response scale pulls stated values toward it. Expect reduced bid variance. Set `false` for an unanchored scale. |
| `cfg.et.positionGuide.*` | disabled, tol `0.12`, hold `1.0s` | `+utils/config.m` | Live head-position feedback before calibration, using Tobii track-box coordinates. Disabled after the rig showed no track-box samples on 2026-09-18; run `utils.diagnoseTrackBox` at the rig before turning it back on. Always skippable by click and times out after 10s. |
| Theme | `warm` | `+utils/style.m`, or `setenv('HW_THEME','arcade')` | Warm/rounded vs. the original dark arcade look. Geometry is identical between themes -- only colour, radius, stroke and font differ -- so switching cannot move an AOI. Recorded as `dataMat.theme` on every run. |

## Debugging tools

Standalone checks, none of which need a running task or (in most cases) PTB
at all:

```matlab
preflight(12, 1, 'rig', 'lab')                    % resolved plan, duration, paths/images/AOIs
utils.verifyPaths(utils.config('rig', 'lab'))       % every configured path, exists or not
utils.checkImages(utils.config('rig', 'lab'), 'houses')  % samples files, finds mismatches
```

`utils.trace` prints a timestamped line at major checkpoints (window open,
stimuli loaded, each block/trial) when turned on. Toggle with `TRACE =
true` at the top of `run_battery.m` -- off by default, console-only, never
saved to any data file. Turn it on first when debugging a crash; it tells
you exactly which checkpoint was reached before narrowing further.

## Known gotchas (PTB/Windows-specific, already fixed, worth knowing about)

- **Colors must be normalized 0.0-1.0, not 0-255.** `PsychDefaultSetup(2)`
  switches the window's color interpretation to normalized floats; a
  0-255 color clamps to solid white on every channel. This was the actual
  cause of an earlier "screen goes white almost immediately, can't see the
  cursor" report -- white text/cursor on a white background is invisible,
  not absent. `+utils/style.m` normalizes the whole palette at the source
  now; if you ever add a new hardcoded color anywhere, divide by 255.
- **`GetMouse(window)` and `GetClicks(window)` are unreliable on Windows** --
  observed to return non-finite coordinates or throw outright, especially
  in windowed mode or with certain display-scaling/multi-monitor setups.
  `utils.getMouse` wraps the former (validates the result, not just
  whether it threw, then falls back to the global cursor query with an
  offset correction). `utils.waitForClick` replaces `GetClicks` entirely,
  since `GetClicks` calls PTB's raw `GetMouse` internally and has zero of
  this protection. Use these, never the raw PTB calls, anywhere new code
  needs a click.
- **`clear PsychImaging` alongside `sca`, always.** `sca` (`Screen('CloseAll')`)
  resets Screen-level window state but not PsychImaging's own persistent
  configuration-phase variables, which live inside the psychimaging.m
  function itself. A crashed `OpenWindow` that only calls `sca` can leave
  the *next* task's `OpenWindow` call returning a handle that looks valid
  but isn't fully initialized -- shows up as a generic Screen "Usage:"
  error on the first real draw call, not at `OpenWindow` itself. Both task
  files now call `clear PsychImaging` in every cleanup path and
  defensively right before every `OpenWindow`.
- **`SkipSyncTests` is a machine property, not a testing-mode property.**
  Windows 10/11 with the DWM compositor active routinely fails PTB's sync
  test outright (a hard `OpenWindow` error, not a warning), independent of
  whether you're piloting or collecting real data. `cfg.display.skipSyncTests`
  is its own setting now, not tied to `cfg.testing.enabled`.

## Analysis plan (living section -- update as this firms up)

1. **Attribute weights.** Estimated from the `synthetic` jobs arm and the
   (already well-conditioned) houses domain, where attributes are
   near-orthogonal by construction. Validated out-of-sample against the
   `ecological` arm.
2. **Preference reversal.** `utils.scoreReversals` in `continuous_DC_task`
   flags, per pair, whether the chosen option was also priced higher --
   computed at save time so it's in the data file rather than reconstructed
   later from raw trials.
3. **Rejection thresholds.** Right-click rejections in the auction task,
   plus accept/reject outcomes against the stochastic market threshold in
   `utils.marketThreshold`.
4. **Multiple anchors.** Each participant's own budget/reservation wage
   (`dataMat.(domain).anchor`) vs. the market price/wage they see, as
   competing anchors in the pricing model.

_Not yet decided: formal model-fitting pipeline, exclusion criteria for
timed-out trials, how `repIdx` (stimulus repetition within the auction
task) will be handled in the model -- as a covariate or an exclusion._

## Stimulus reuse: what's allowed, and why

Three different kinds of reuse, with different answers:

**Within a level, within a pair -- REQUIRED.** The same pair is both chosen
between and priced (each option separately). That identity is the entire
basis of the preference-reversal measure; without it there's nothing to
compare.

**Across attribute levels -- ALLOWED by default**
(`cfg.contdc.allowCrossLevelReuse = true`). The same stimulus item may appear
at more than one attribute level, because balanced 2/4/6-attribute cells are
more important than avoiding every repeated item. This is especially relevant
for houses, where no anchor-centred window has enough distinct stimuli to
support every level without reuse.

Note the level ORDER is randomised per participant, so reuse is not
systematically confounded with level. The remaining risk is recognition and
consistency pressure, which should be watched in pilot testing rather than
handled by silently shortening later cells.

**Across tasks (auction and contdc) -- currently unconstrained.** Worth
deciding on if you run both in one session, especially for houses where
photos make an item much more recognisable than a job's numeric ratings.

### The supply constraint

Each level needs `nPairs x 2` stimuli. If cross-level reuse is blocked, that
becomes `nLevels x nPairs x 2` distinct stimuli per domain.

| budget anchor | houses in window |
|---|---|
| $250k | 23 |
| $400k | 38 |
| $600k | 39 |
| $900k | 28 |

At 3 levels, 20 pairs would need **120 distinct items** if reuse were blocked.
Houses only have 80 listings total, so cross-level reuse is on by default.
Any remaining shortfall is a fatal setup error rather than an imbalanced run.

`cfg.contdc.nPairs` is 20 per level for both domains. That is the minimum
worth collecting for reversal estimates; the cost is duration and repeated
house recognition, which should be judged in rig practice data rather than by
silently shortening cells.

## Verify paths before you run anything

Every path bug so far has been found by crashing mid-task rather than by
checking up front. Run this once on any new machine:

```matlab
utils.verifyPaths(utils.config('rig', 'lab'))
```

It prints every configured path and whether it exists -- no PTB dependency,
takes about a second. `cfg.paths.experiment` (`housing_wages/Experiment`)
and `cfg.paths.stimuli` (`housing_wages/Experiment/stimuli`) are confirmed
correct against real error messages. `cfg.paths.tobii` and everything under
`cfg.paths.data` (sessions/auction/cont_dc/gaze/crashed) are still
unverified guesses from the original pass -- check them with this tool
before you trust them.

## Open items

- Confirm `lab` rig geometry (diagonal, viewing distance) against the
  actual monitor before any real data collection -- every AOI threshold in
  the dataset derives from these two numbers.
- `+utils/style.m`'s audio hooks (`blip_click.wav` etc.) reference files
  that don't exist yet.
- Fonts are now probed at run time by `+utils/resolveFonts.m`, which picks
  the first family in `s.fontContentPref` / `s.fontChromePref` that is
  genuinely installed, and prints what it resolved to via `utils.trace`.
  The `warm` theme's defaults (`Segoe UI`) ship with every Windows, so no
  manual font install is required any more. The probe detects substitution
  by measuring a probe string, since Windows GDI substitutes silently and
  `Screen('TextFont', window)` echoes back what you asked for rather than
  what you got.
- Trial/block counts (`cfg.auction.nTrials`, `cfg.contdc.nPairs`) are best
  guesses, not yet piloted -- and the fixation-start gate on every trial
  adds real time per trial that wasn't in the original 45-minute budget
  arithmetic. Worth re-timing a few pilot sessions rather than trusting
  the original estimate.
- Cross-task stimulus reuse (auction vs. contdc, same domain, same
  session) is unconstrained -- decide whether that matters, especially
  for houses.
- `cfg.contdc.nPairs = 20` per level is the current full-run setting for
  both domains; re-time the task at the rig before participant collection.

## Diagnosing a freeze near task completion

Task progress logging is automatic, including when `TRACE = false`. Each run
prints `Local progress log: ...` before starting. Logs are append-only text
files under `fullfile(tempdir, 'housing-wages-logs')` on the computer running
MATLAB, independent of the experiment's shared data drive. Each entry closes
its file immediately so it can survive force-closing MATLAB (not a guarantee
against power loss). Copy the logs before temporary-folder cleanup.

For a rehearsal, use `RUN_KIND = 'practice'` in `run_battery.m`. Keep the usual
trial counts if reproducing a freeze that might depend on accumulated gaze data.
After a freeze, reopen MATLAB on the same computer/account. On Windows:

```matlab
winopen(fullfile(tempdir, 'housing-wages-logs'))
```

Send the newest `.log` files. They identify the run, source location, code
version, save destinations, and timestamps around gaze collection, tracker
stop, gaze assembly, MAT/CSV writes, and manifest updates. An unmatched `BEGIN`
narrows down the interrupted operation; it does not prove that operation caused
the freeze. Caught errors are logged before cleanup. Logging is best-effort,
outside trial timing, and does not implement task or trial resumption.
