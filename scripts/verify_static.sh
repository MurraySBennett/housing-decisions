#!/usr/bin/env bash
set -euo pipefail

fail=0

check_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf 'missing file: %s\n' "$path" >&2
    fail=1
  fi
}

check_grep() {
  local pattern="$1"
  local path="$2"
  local label="$3"
  if ! grep -Eq "$pattern" "$path"; then
    printf 'missing pattern (%s): %s in %s\n' "$label" "$pattern" "$path" >&2
    fail=1
  fi
}

check_absent() {
  local pattern="$1"
  local path="$2"
  local label="$3"
  if grep -Eq "$pattern" "$path"; then
    printf 'unexpected pattern (%s): %s in %s\n' "$label" "$pattern" "$path" >&2
    fail=1
  fi
}

check_file experiment/stimuli/prepare_stimuli.py
check_file experiment/stimuli/README.md
check_file experiment/stimuli/stimgen/configs/jobs_synthetic.json
check_file experiment/stimuli/stimgen/configs/jobs_ecological.json
check_file experiment/stimuli/stimgen/configs/jobs_attenuated.json
check_file experiment/stimuli/prepared/job_stimuli_synthetic.csv
check_file experiment/stimuli/prepared/job_stimuli_synthetic_provenance.json
check_file experiment/+utils/attrSlotRects.m
check_file experiment/+utils/batteryPlan.m
check_file experiment/preflight.m

check_grep 'trial\.bidRT[[:space:]]*=[[:space:]]*NaN' experiment/auction_task.m 'auction no-bid default'
check_grep 'buttons\(3\)' experiment/auction_task.m 'right-click bid cancel'
check_grep 'now[[:space:]]*=[[:space:]]*GetSecs[[:space:]]*-[[:space:]]*t0;' experiment/auction_task.m 'fresh vacancy timestamp'
check_grep 'utils\.attrSlotRects' experiment/+utils/layoutDetailAOIs.m 'fixed auction detail slots'
check_grep 'utils\.attrSlotRects' experiment/+utils/drawOptionCard.m 'fixed card slots'

check_grep "RandStream\\('twister',[[:space:]]*'Seed',[[:space:]]*run\\.seed\\)" experiment/continuous_DC_task.m 'private contdc RNG'
check_absent 'rs[[:space:]]*=[[:space:]]*RandStream\.getGlobalStream' experiment/continuous_DC_task.m 'global contdc RNG'
check_grep 'ch\(k\)\.timedOut' experiment/continuous_DC_task.m 'skip timed-out reversals'
check_grep 'isnan\(ch\(k\)\.choseMoney\)' experiment/continuous_DC_task.m 'skip NaN reversals'
check_grep 'cfg\.contdc\.nPairs\.\(lower\(domain\)\)' experiment/continuous_DC_task.m 'domain-specific pair counts'
check_grep 'cfg\.contdc\.allowCrossLevelReuse[[:space:]]*=[[:space:]]*true' experiment/+utils/config.m 'cross-level reuse defaults on for balanced contdc cells'
check_grep "error\\('hw:contdc:shortPairs'" experiment/continuous_DC_task.m 'short contdc pair generation is fatal'
check_grep 'numel\(pairsByLevel\.\(key\)\)[[:space:]]*< nPairsThisRun' experiment/continuous_DC_task.m 'contdc checks pair count per attribute level'
check_grep 'The same stimulus item may appear' experiment/README.md 'cross-level reuse docs'
check_grep 'aoiLayouts' experiment/continuous_DC_task.m 'contdc saved AOI layouts'
check_grep 'buildAoiLayouts' experiment/continuous_DC_task.m 'contdc AOI layout helper'
check_grep 'utils\.drawOptionCard\(' experiment/continuous_DC_task.m 'contdc draws through the shared card'
check_grep 'utils\.checkAOIs' experiment/continuous_DC_task.m 'contdc AOI validation'
check_grep 'utils\.batteryPlan' experiment/run_battery.m 'shared battery plan resolver'

check_grep 'valid[[:space:]]*=[[:space:]]*~isnan\(values\)' experiment/+utils/sampleWindow.m 'sampleWindow original-index mask'
check_grep 'w\.idx[[:space:]]*=[[:space:]]*find\(valid[[:space:]]*&' experiment/+utils/sampleWindow.m 'sampleWindow unfiltered indices'
check_grep 'pick\.trial' experiment/+utils/incentives.m 'incentive selected trial'
check_grep 'detailAoiRects' experiment/auction_task.m 'auction detail AOI rects saved'
check_grep 'layoutDetailAOIs' experiment/auction_task.m 'auction detail AOI helper'
check_grep 'utils\.clockSync' experiment/auction_task.m 'auction clock sync'
check_grep 'utils\.clockSync' experiment/continuous_DC_task.m 'contdc clock sync'
check_grep 'actualSampleRateHz' experiment/+utils/setupEyeTracker.m 'actual sample-rate field'
check_grep 'get_gaze_output_frequency' experiment/+utils/setupEyeTracker.m 'query Tobii sample rate'
check_file experiment/+utils/clockSync.m
check_file scripts/pull_data_from_share.ps1
check_grep 'housing_wages\\Experiment\\Data' scripts/pull_data_from_share.ps1 'pulls data from share Experiment data tree'
check_absent 'housing_wages_local' experiment/+utils/config.m 'config must not use housing_wages_local'
check_absent 'housing_wages_local' scripts/pull_data_from_share.ps1 'pull script must not use housing_wages_local'
check_grep 'data\\lab\\Data' scripts/pull_data_from_share.ps1 'copies data into ignored local analysis tree'
check_grep 'analysis/R/run_all.R' scripts/pull_data_from_share.ps1 'pull script runs analysis pipeline'
check_grep 'CELL IMBALANCE' analysis/R/io.R 'analysis reports imbalanced contdc cells'
check_grep 'price_rows == 2 \* choice_rows' analysis/R/io.R 'analysis checks contdc price-choice row ratio'
check_grep 'right-click' experiment/+utils/incentives.m 'instructions mention right click'
check_grep 'runComprehensionChecks' experiment/auction_task.m 'auction comprehension checks'
check_grep 'runPracticeEpisode' experiment/auction_task.m 'auction practice episode'
check_grep 'trial\.practice' experiment/auction_task.m 'practice flag stored'
check_grep 'showMarketClosed' experiment/auction_task.m 'market closed feedback'
check_grep 'practice' experiment/auction_task.m 'practice field included'
check_grep 'bidRT' experiment/auction_task.m 'bidRT included in auction output'
check_grep 'function[[:space:]]+report[[:space:]]*=[[:space:]]*preflight' experiment/preflight.m 'preflight entrypoint'
check_grep 'utils\.batteryPlan' experiment/preflight.m 'preflight shared plan resolver'
check_grep 'utils\.verifyPaths' experiment/preflight.m 'preflight path check'
check_grep 'utils\.checkImages' experiment/preflight.m 'preflight image check'
check_grep 'utils\.checkAOIs' experiment/preflight.m 'preflight AOI check'
check_grep 'estimatedMinutes' experiment/preflight.m 'preflight duration estimate'
check_grep 'resolvedPlan' experiment/preflight.m 'preflight resolved plan'
check_grep '## Design knobs' experiment/README.md 'design knob docs'
check_grep 'cfg\.auction\.nTrials' experiment/README.md 'auction trial knob docs'
check_grep 'cfg\.contdc\.nPairs\.houses' experiment/README.md 'house pair knob docs'
check_grep 'JOBS_ARM' experiment/README.md 'jobs arm knob docs'

# --- Restyle and theme invariants ---------------------------------------
check_file experiment/+utils/roundRect.m
check_file experiment/+utils/resolveFonts.m

check_grep 'HW_THEME' experiment/+utils/style.m 'theme rollback switch'
check_grep "case 'arcade'" experiment/+utils/style.m 'arcade rollback target still present'
check_grep 'themeName' experiment/auction_task.m 'theme recorded in saved auction data'
check_grep 'themeName' experiment/continuous_DC_task.m 'theme recorded in saved contdc data'
check_grep 'utils\.resolveFonts' experiment/auction_task.m 'auction font probe wired'
check_grep 'utils\.resolveFonts' experiment/continuous_DC_task.m 'contdc font probe wired'

# roundRect draws a union of overlapping primitives, so a translucent
# colour would be painted twice at the corners. The debug gaze dot is the
# only 4-element colour in the codebase and must stay a DrawDots call.
check_absent 'utils\.roundRect\(.*255 80 80 180' experiment/auction_task.m 'no translucent colour through roundRect'
check_absent 'utils\.roundRect\(.*255 80 80 180' experiment/continuous_DC_task.m 'no translucent colour through roundRect'

# The pixel font must not come back as a default: it was never installed
# by the code and Windows substitutes for it silently.
check_absent "s\.fontContent[[:space:]]*=[[:space:]]*'Press Start 2P'" experiment/+utils/style.m 'pixel font as content face'

# No hardcoded text size anywhere -- the last one lived in elicitVAS.
check_absent "Screen\('TextSize',[[:space:]]*window,[[:space:]]*[0-9]" experiment/+utils/elicitVAS.m 'hardcoded text size'

# --- AOI geometry: ONE copy, not three ----------------------------------
# preflight.m used to re-implement the card layout by hand, and it drifted
# exactly as predicted: pilot note 18 raised the identity header advance to
# s.identityTextHeightPx = 42, the tasks were updated and guarded, and
# preflight's copy kept the literal 30 -- so pfAoi.allAoiOK, the assertion
# verify_matlab.m runs first at the rig, was validating rects 12 px above
# the cells actually drawn.
#
# The card geometry now lives in +utils and every caller shares it. What
# these guards protect is that nobody re-introduces a local copy.
check_file experiment/+utils/cardAOIs.m
check_file experiment/+utils/drawOptionCard.m
check_file experiment/+utils/layoutCardAndArc.m
check_file experiment/+utils/reserveIdentityStrip.m
check_file experiment/+utils/hasTextIdentity.m
check_grep 'pad = 18;' experiment/+utils/cardAOIs.m      'card inner pad, single copy'
check_grep 'pad = 18;' experiment/+utils/drawOptionCard.m 'the draw must use the same pad'
check_grep 'cfg\.style\.identityTextHeightPx' experiment/+utils/cardAOIs.m 'AOI header advance is the named constant'
check_grep 's\.identityTextHeightPx' experiment/+utils/drawOptionCard.m 'the draw advances by the same constant'
for f in experiment/auction_task.m experiment/continuous_DC_task.m experiment/preflight.m; do
  check_absent '^function .*cardAOIs\(' "$f" "no local cardAOIs in $(basename "$f")"
  check_absent '^function .*hasTextIdentity\(' "$f" "no local hasTextIdentity in $(basename "$f")"
  check_absent '^function .*(reserveIdentityStrip|identityContentRect)\(' "$f" "no local identity-strip geometry in $(basename "$f")"
  check_absent '^function .*(identityString|valueString)\(' "$f" "no local identityString/valueString in $(basename "$f")"
done
# The grid layouts are still duplicated in preflight. Narrower than the card
# duplication was, but the same class of bug -- keep the literals pinned
# until they move to +utils too.
check_grep 'pad = 48;'  experiment/auction_task.m       'auction grid pad'
check_grep 'pad = 48;'  experiment/preflight.m          'preflight grid pad (must match auction_task)'
check_grep 'marg = 70;' experiment/continuous_DC_task.m 'contdc two-card margin'
check_grep 'marg = 70;' experiment/preflight.m          'preflight two-card margin (must match contdc)'
check_grep 's\.hud\.heightPx[[:space:]]*=[[:space:]]*64;' experiment/+utils/style.m 'HUD height feeds every AOI layout'

check_grep 'Theme' experiment/README.md 'theme knob docs'

# --- Rehearsal mode ------------------------------------------------------
# It must stay INDEPENDENT of cfg.testing: the whole point is a short run
# that is otherwise real, and cfg.testing drags windowed mode, skipped
# elicitation, skipped practice and participant 9999 along with it.
check_grep 'cfg\.rehearsal\.trialsPerCell' experiment/+utils/config.m 'rehearsal knob defined'
check_grep 'cfg\.rehearsal\.trialsPerCell' experiment/auction_task.m 'auction honours rehearsal counts'
check_grep 'cfg\.rehearsal\.trialsPerCell' experiment/continuous_DC_task.m 'contdc honours rehearsal counts'
check_grep 'cfg\.rehearsal\.trialsPerCell' experiment/preflight.m 'preflight duration honours rehearsal counts'
check_grep 'trialsPerCell' experiment/+utils/startSession.m 'rehearsal knob threaded through startSession'
check_grep 'TRIALS_PER_CELL' experiment/run_battery.m 'rehearsal knob exposed to the experimenter'
check_grep 'trialsPerCell' experiment/auction_task.m 'rehearsal flag saved with auction data'
check_grep 'trialsPerCell' experiment/continuous_DC_task.m 'rehearsal flag saved with contdc data'
check_grep 'trialsPerCell \* 2' experiment/auction_task.m 'auction cells are the 2 competition levels'
check_grep 'TRIALS_PER_CELL' experiment/README.md 'rehearsal knob docs'

# --- Post-pilot fixes ----------------------------------------------------
check_file experiment/+utils/savingScreen.m
check_file experiment/+utils/didYouKnow.m
check_file experiment/+utils/snapValue.m

# A blocking save must never happen with a stale trial screen up.
check_grep 'utils\.savingScreen' experiment/auction_task.m 'auction saving screen'
check_grep 'utils\.savingScreen' experiment/continuous_DC_task.m 'contdc saving screen'
check_grep 'utils\.snapValue' experiment/auction_task.m 'auction bid snapped to displayed resolution'
check_grep 'utils\.snapValue' experiment/continuous_DC_task.m 'contdc price snapped to displayed resolution'

# The value labels must read as ADVERTISED figures, not as the response.
check_grep "'Offered wage'" experiment/+utils/attributes.m 'jobs value label'
check_grep "'Listed price'" experiment/+utils/attributes.m 'houses value label'
check_absent "'\\\$%\\.2f/hr'" experiment/+utils/formatCurrency.m 'cents on hourly wages'

# Participants must be told about the quit key -- it always worked.
check_grep 'quitNotice' experiment/auction_task.m 'auction quit notice'
check_grep 'quitNotice' experiment/continuous_DC_task.m 'contdc quit notice'

# Rejected options reach the CSV, not just the .mat.
check_grep 'rejectedStimIdx' experiment/auction_task.m 'rejected options in the CSV'

check_grep 'showValueMarker' experiment/+utils/config.m 'value-marker knob'
check_grep 's\.marker' experiment/+utils/style.m 'scale marker colour'
check_grep 'priceScale\.minorTickPx[[:space:]]*=[[:space:]]*8;' experiment/+utils/style.m 'short pricing minor ticks'
check_grep 'priceScale\.majorTickPx[[:space:]]*=[[:space:]]*32;' experiment/+utils/style.m 'pricing major tick length'
check_grep 'priceScale\.labelSizePx[[:space:]]*=[[:space:]]*24;' experiment/+utils/style.m 'larger pricing tick labels'
check_grep 'priceScale\.readoutLiftPx[[:space:]]*=[[:space:]]*84;' experiment/+utils/style.m 'pricing readout lifted above tick labels'
check_grep 'scaleR[[:space:]]*=[[:space:]]*outerR - s\.priceScale\.majorTickPx;' experiment/auction_task.m 'auction scale baseline sits at the bottom of major ticks'
check_grep 'scaleR[[:space:]]*=[[:space:]]*outerR - s\.priceScale\.majorTickPx;' experiment/continuous_DC_task.m 'contdc scale baseline sits at the bottom of major ticks'
check_absent 'minorA[[:space:]]*=[[:space:]]*linspace\(pi,[[:space:]]*2\*pi,[[:space:]]*25\)' experiment/auction_task.m 'auction price scale must not use a dotted minor-tick comb'
check_absent 'minorA[[:space:]]*=[[:space:]]*linspace\(pi,[[:space:]]*2\*pi,[[:space:]]*25\)' experiment/continuous_DC_task.m 'contdc price scale must not use a dotted minor-tick comb'
check_absent 'SetMouse\(round\(cx \+ innerR\*cos\(pi \+ startFrac\*pi\)\)' experiment/auction_task.m 'auction pricing must not reposition mouse'
check_absent 'SetMouse\(round\(cx \+ innerR\*cos\(pi \+ startFrac\*pi\)\)' experiment/continuous_DC_task.m 'contdc pricing must not reposition mouse'
check_grep 'startFrac[[:space:]]*=[[:space:]]*NaN' experiment/auction_task.m 'auction records no forced pricing cursor start'
check_grep 'tr\.startFrac[[:space:]]*=[[:space:]]*NaN' experiment/continuous_DC_task.m 'contdc records no forced pricing cursor start'
check_grep 'The practice round is over' experiment/auction_task.m 'clear practice-to-real boundary'

# --- Standalone house photo preference task -----------------------------
check_file experiment/photo_preference_task.m
check_file experiment/+utils/buildPhotoPreferencePlan.m
check_grep 'taskData\.photo_pref' experiment/+utils/config.m 'photo preference data directory'
check_grep "TASK_MODE[[:space:]]*=[[:space:]]*'both'" experiment/photo_preference_task.m 'photo preference can run both sections'
check_grep "case 'rating'" experiment/photo_preference_task.m 'photo preference rating mode'
check_grep "case 'pwc'" experiment/photo_preference_task.m 'photo preference pairwise mode'
check_grep 'N_RATING[[:space:]]*=[[:space:]]*80' experiment/photo_preference_task.m 'default 80 photo ratings'
check_grep 'N_PWC[[:space:]]*=[[:space:]]*160' experiment/photo_preference_task.m 'default 160 pairwise comparisons'
check_grep 'AREA_QUOTAS' experiment/photo_preference_task.m 'editable area quotas'
check_grep "utils\.readStimuli\(cfg,[[:space:]]*'houses'\)" experiment/photo_preference_task.m 'photo preference reads houses through shared loader'
for area in extPic kitPic bedPic bathPic livPic outPic; do
  check_grep "$area" experiment/+utils/buildPhotoPreferencePlan.m "photo preference planner includes $area"
done
check_grep 'chosenPhotoId' experiment/photo_preference_task.m 'pairwise CSV names chosen photo'
check_grep 'unchosenPhotoId' experiment/photo_preference_task.m 'pairwise CSV names unchosen photo'

# --- Head-position guide -------------------------------------------------
check_file experiment/+utils/positionGuide.m
check_grep 'utils\.positionGuide' experiment/+utils/setupEyeTracker.m 'position guide runs before calibration'
check_grep 'positionGuide\.tolerance' experiment/+utils/config.m 'position guide knobs'
check_grep 'positioned' experiment/auction_task.m 'head position recorded with auction data'
check_grep 'positioned' experiment/continuous_DC_task.m 'head position recorded with contdc data'
# The guide must never be able to strand a session on a setup screen.
check_grep 'timeoutSec' experiment/+utils/positionGuide.m 'position guide has an escape hatch'

# Region/Zone is out of the current design. If it comes back it must be a
# deliberate edit, not a silent reappearance.
check_grep "A\.late = struct\('var', \{\}" experiment/+utils/attributes.m 'houses late tier is empty (Region out of the design)'
check_grep 'groupDigits' experiment/+utils/elicitAnchor.m 'anchor input is thousands-grouped'

# --- Cursor on click-driven screens --------------------------------------
# elicitVAS used to hide the cursor on the way out, which left the auction's
# comprehension check asking for an aimed click at an invisible pointer.
# Pattern anchored past any comment marker: the file explains the old
# HideCursor call in prose, and that prose must not trip the check.
check_absent '^[^%]*HideCursor' experiment/+utils/elicitVAS.m 'elicitVAS must leave the cursor visible'
if ! awk '/^function choice = askComprehension/,/^s = cfg\.style;/' \
     experiment/auction_task.m | grep -q 'ShowCursor'; then
  printf 'missing: askComprehension does not show the cursor itself\n' >&2
  fail=1
fi

# --- The value attribute is rated, and excluded from selection -----------
check_file experiment/+utils/elicitAttrRatings.m
check_grep 'utils\.elicitAttrRatings' experiment/auction_task.m 'auction rates the value attribute'
check_grep 'utils\.elicitAttrRatings' experiment/continuous_DC_task.m 'contdc rates the value attribute'
check_grep 'coreRatings' experiment/auction_task.m 'auction saves the value-attribute rating'
check_grep 'coreRatings' experiment/continuous_DC_task.m 'contdc saves the value-attribute rating'
# Selection must keep taking pool ratings only -- the core attribute is
# always shown, so letting its rating in would be a silent design change.
check_absent 'coreRatings' experiment/+utils/selectAttributes.m 'selection must not read the value rating'

# --- 2026-09-16 pilot round ----------------------------------------------
# Rating mode is a revert switch, so BOTH implementations must stay present
# and every caller must go through the dispatcher rather than pick one.
check_file experiment/+utils/elicitVASDrag.m
check_file experiment/+utils/elicitRatings.m
check_file experiment/+utils/elicitVAS.m
check_grep 'ratingMode' experiment/+utils/config.m 'rating mode switch exists'
check_absent 'utils\.elicitVAS\(' experiment/auction_task.m 'auction must call utils.elicitRatings'
check_absent 'utils\.elicitVAS\(' experiment/continuous_DC_task.m 'contdc must call utils.elicitRatings'
check_absent 'utils\.elicitVAS\(' experiment/+utils/elicitAttrRatings.m 'attr ratings must call utils.elicitRatings'

# The identity header advance is drawn in one place and mirrored in the AOI
# layout in another. A literal in either is how recorded AOIs drift off the
# drawn cells without anything failing.
check_grep 'identityTextHeightPx' experiment/+utils/style.m 'identity header height is a named constant'
check_absent 'y0 = y0 \+ 30;' experiment/continuous_DC_task.m 'no literal identity header advance'

check_grep 'vacancyGapMax' experiment/+utils/config.m 'vacancy tail is capped'
check_grep 'vacancyGapMax' experiment/auction_task.m 'the cap is actually applied'
check_grep 'retireStimulus' experiment/auction_task.m 'won items leave the market'
check_grep 'round\(v / 1000\)' experiment/+utils/snapValue.m 'house prices snap to the nearest thousand'

# --- Post-pilot: second-price wording, wage grid, blocked competition ----
# The outcome screen must describe the auction it is. "market price" was
# the private-sale framing the pilot objected to.
check_absent 'market price' experiment/auction_task.m 'houses outcome must not read as a private sale'
check_grep 'next best offer' experiment/auction_task.m 'houses outcome names the second-price rule'
check_grep 'next best offer' experiment/+utils/incentives.m 'houses instructions state the second-price rule'

# Wage is the anchored attribute and needs its own grid, or sampleWindow
# leaves a single distinct value inside a window. window_check.py is the
# check that catches it; it must not be deleted along with a regeneration.
check_file experiment/stimuli/stimgen/window_check.py
check_grep 'n_levels_by_column' experiment/stimuli/prepare_stimuli.py 'per-column level counts'
check_grep 'spacing_by_column' experiment/stimuli/prepare_stimuli.py 'per-column level spacing'
check_grep '"wage": 12' experiment/stimuli/stimgen/configs/jobs_synthetic.json 'wage keeps its own level count'
check_grep '"wage": "geometric"' experiment/stimuli/stimgen/configs/jobs_synthetic.json 'wage keeps geometric spacing'

# Competition is blocked, and the block order is counterbalanced by
# participant. Passing the participant is the whole counterbalancing -- a
# trialPlan call that drops it silently randomises instead.
check_grep 'cfg\.auction\.nBlocks' experiment/+utils/config.m 'block count is a named knob'
check_grep 'utils\.trialPlan\(planCfg, win\.n, rs, sess\.participant\)' experiment/auction_task.m 'block order is counterbalanced by participant'
# The break must fire on a COMPETITION change, not a block index: under
# ABBA, blocks 2 and 3 are the same level, and announcing a new market
# there would be a false statement to the participant.
check_grep 'levelChange' experiment/auction_task.m 'breaks fire at competition changes'
check_absent 'plan\(t\)\.block ~= plan\(t-1\)\.block' experiment/auction_task.m 'breaks must not fire on block index'
check_absent 'randperm\(rngStream, nTrials\)' experiment/+utils/trialPlan.m 'competition must not be re-rolled per trial'

# --- House prices are FITTED onto the window, not selected --------------
# 80 houses spanning 126:1 against a 2.67:1 window left 7-23 in a window,
# which is both the repeated-house complaint and why buildPairs ran short
# of the 36 distinct contdc needs. Both tasks must go through the single
# dispatcher: fitting rewrites the value column, and doing that by hand in
# two places is how they drift apart.
check_file experiment/+utils/fitToWindow.m
check_file experiment/+utils/applyWindow.m
check_grep 'cfg\.sampling\.fitToWindow\.houses' experiment/+utils/config.m 'fit switch exists'
check_grep 'utils\.applyWindow' experiment/auction_task.m 'auction goes through the dispatcher'
check_grep 'utils\.applyWindow' experiment/continuous_DC_task.m 'contdc goes through the dispatcher'
check_absent 'utils\.sampleWindow' experiment/auction_task.m 'auction must not call sampleWindow directly'
check_absent 'utils\.sampleWindow' experiment/continuous_DC_task.m 'contdc must not call sampleWindow directly'
# priceMap is the only record of what each house really listed for.
check_grep 'priceMap' experiment/+utils/fitToWindow.m 'fitted prices keep the original alongside'
check_grep 'priceMap' experiment/+utils/applyWindow.m 'the selection path fills priceMap too'
# Surplus is only interpretable against the participant's own anchor.
check_grep 'out\.surplus / base' experiment/+utils/incentives.m 'bonus scale is anchor-relative'
check_grep 'w\.anchor' experiment/+utils/collectWins.m 'wins carry the anchor'

# --- The auction bid screen shows the option it is pricing --------------
# Bidding used to be a separate full screen with nothing on it but the arc,
# so gaze during the pricing response could not say which attributes were
# being weighed. That is the measurement the reversal hypothesis turns on,
# and contdc's price trial already had it. Same layout function, same AOI
# function, so gaze on the two pricing screens is comparable.
check_grep 'utils\.layoutCardAndArc' experiment/auction_task.m 'bid screen uses the shared card+arc layout'
check_grep 'utils\.layoutCardAndArc' experiment/continuous_DC_task.m 'contdc price trial uses the same one'
check_grep 'utils\.drawOptionCard' experiment/auction_task.m 'the bid screen actually draws the option'
check_grep "utils\.cardAOIs\(cfg, bidL\.cardRect, sel, 'bid'\)" experiment/auction_task.m 'bid AOIs recorded'
check_grep 'bidAoiRects' experiment/auction_task.m 'bid AOIs saved with the data'
# preflight must check them too, or allAoiOK stops covering a whole screen.
check_grep "utils\.cardAOIs\(cfg, bidL\.cardRect, sel, 'bid'\)" experiment/preflight.m 'preflight computes the bid AOIs'
check_grep 'auctionBid' experiment/preflight.m 'preflight reports on the bid screen'
check_grep "isfield\(r, 'auctionBid'\)" experiment/preflight.m 'allAoiOK includes the bid screen'

# --- Every utils.X(...) call resolves to a +utils/X.m --------------------
# MATLAB resolves package functions at call time, so a rename leaves a file
# that looks fine and throws the first time that branch runs -- mid-session,
# at the rig, on a screen reached once per trial. Nothing else catches it
# here: this machine has no MATLAB.
# --- Data and images stay in Experiment and are gitignored ---------------
check_grep "experiment/Data/" .gitignore 'participant data is ignored'
check_grep "\*\*/stimuli/house_images/" .gitignore 'house images are ignored'
check_grep "cfg\.paths\.local[[:space:]]*=[[:space:]]*cfg\.paths\.experiment" experiment/+utils/config.m 'local root is Experiment'
check_grep "cfg\.paths\.data[[:space:]]*=[[:space:]]*fullfile\(cfg\.paths\.experiment,[[:space:]]*'Data'\)" experiment/+utils/config.m 'participant data stays inside Experiment'
check_grep "cfg\.paths\.images[[:space:]]*=[[:space:]]*fullfile\(cfg\.paths\.stimuli,[[:space:]]*'house_images'\)" experiment/+utils/config.m 'house images stay inside stimuli'

# --- photo_preference_task display setup matches the battery tasks -------
# Screen('Preference') rejects MATLAB logicals -- rigProfiles stores
# skipSyncTests as one, so the cast is load-bearing. And style.m colors are
# 0-1: without PsychDefaultSetup(2) every panel renders near-black.
check_grep "SkipSyncTests', double\(cfg\.display\.skipSyncTests\)" experiment/photo_preference_task.m 'photo task casts SkipSyncTests to double'
check_grep 'PsychDefaultSetup\(2\)' experiment/photo_preference_task.m 'photo task normalizes 0-1 color range'
check_grep "BlendFunction" experiment/photo_preference_task.m 'photo task enables alpha blending'

if ! python3 scripts/check_utils_calls.py; then
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
