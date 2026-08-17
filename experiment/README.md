# Housing & Wages: Search, Pricing, and Choice

Project rundown, design decisions, and analysis plan. Read this before
touching `run_battery.m`.

## What this is

Two tasks, sharing one participant-management layer, testing three
extensions to the Price Accumulation model of dynamic pricing: attribute
weights, multiple anchors, and rejection thresholds.

- **`auction_task.m`** -- sequential search with a continuous BDM price
  response. Options arrive and expire on a market; the participant inspects,
  rejects, or bids. 12 trials (search episodes), competition crossed
  low/high, fixed at 6 attributes.
- **`continuous_DC_task.m`** -- pricing vs. discrete choice on the same
  option pairs, crossed with attribute count (2/4/6). Carries the
  attribute-load manipulation, because its trials are short enough to
  afford three levels where the auction's 12 trials are not.

Both run through one participant-management layer (`+utils`) that handles
identity, counterbalancing, crash recovery, eye tracking, and linking data
across tasks and domains.

## Why two domains, and how personalization works

Houses and jobs are structurally parallel markets with a genuinely
different answer, which is the point. Each participant's own budget
(houses) or reservation wage (jobs) is elicited first and used two ways:

1. **Stimulus window.** `utils.sampleWindow` centers the shown price range
   on that anchor rather than filtering to it -- the house stimulus set
   (80 items) can't support a budget-filtered block of 12+ options, and
   filtering would also kill the price variance the anchor manipulation
   needs. See `utils/sampleWindow.m`.
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
shared across participants.

## Task/domain independence

`run_battery.m` dispatches from a `PLAN`: a list of `(task, domains,
session)` rows. This is deliberately decoupled from the participant-level
domain question, so any of the following is just a different `PLAN`, with
no change to task code:

- Jobs only, one task
- Houses only, one task
- Jobs, both tasks, one sitting
- Houses, both tasks, one sitting
- Everything, split across two sessions (call the script again on a
  different day with the same participant ID; `hw.startSession` resumes
  from that participant's manifest)

Every run's saved filename and manifest entry carries both its task AND its
domain set (`sub-00012_ses-01_task-auction_dom-jobs_...`), so a participant
who does jobs-auction today and houses-contdc next week is fully
reconstructable from the manifest alone, and two runs of the same task over
different domains never collide.

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

Off by default (`cfg.incentives.enabled = false`). See `utils/incentives.m`
for the BDM-based payment scheme and both the paid/unpaid instruction text.
Turning this on almost certainly needs an IRB amendment -- see the earlier
discussion in this thread for the reasoning behind the payment structure
(random-incentivized-trial, threshold pricing, not first-price).

## Stimulus preparation

See `stimgen/README.md`. Three arms for the jobs domain (`synthetic`,
`ecological`, `attenuated`), selected at runtime via `JOBS_ARM` in
`run_battery.m` -- never by copying/renaming output files, which severs the
link to the provenance record. Houses need no preparation.

## Known technical notes worth keeping in mind

- **`utils.getMouse(window)`** wraps `GetMouse` because the window-relative
  form has a real Windows/PTB reliability issue (fails under certain
  display-scaling / multi-monitor / windowed-mode conditions). It tries the
  window form first and falls back to the global cursor position with a
  manual offset correction. Use it everywhere `GetMouse(window)` would
  otherwise appear -- both task files already do.
- **Gaze data** saves to its own file per domain, separate from the
  behavioural `.mat` -- it's orders of magnitude larger and doesn't belong
  in the same file.
- **Media mode** (`cfg.et.mediaMode` + `cfg.et.showGaze`) is for screen
  recording only. Any run with the gaze dot visible is tagged
  non-analyzable in the saved data so it can't quietly end up in a real
  dataset.

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

## Verify paths before you run anything

Every path bug so far has been found by crashing mid-task rather than by
checking up front. Run this once on any new machine:

```matlab
utils.verifyPaths(utils.config('rig', 'lab'))
```

It prints every configured path and whether it exists -- no PTB dependency,
takes about a second. `cfg.paths.experiment` (`housing_wages/Experiment`) is
now confirmed correct against a real error message. `cfg.paths.tobii` and
everything under `cfg.paths.data` (sessions/auction/cont_dc/gaze/crashed)
are still unverified guesses from the original pass -- check them with this
tool before you trust them, rather than waiting to find the next one by
crashing.

## Open items

- Confirm `lab` rig geometry (diagonal, viewing distance) against the
  actual monitor before any real data collection -- every AOI threshold in
  the dataset derives from these two numbers.
- `hw.style`'s audio hooks (`blip_click.wav` etc.) reference files that
  don't exist yet.
- `Press Start 2P` needs installing on the lab machine or the HUD silently
  falls back to Courier.
- Trial/block counts (`cfg.auction.nTrials`, `cfg.contdc.nPairs`) are best
  guesses from the 45-minute budget, not yet piloted.
