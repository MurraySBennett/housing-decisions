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
check_grep 'utils\.attrSlotRects' experiment/auction_task.m 'fixed auction detail slots'
check_grep 'utils\.attrSlotRects' experiment/continuous_DC_task.m 'fixed contdc card slots'

check_grep "RandStream\\('twister',[[:space:]]*'Seed',[[:space:]]*run\\.seed\\)" experiment/continuous_DC_task.m 'private contdc RNG'
check_absent 'rs[[:space:]]*=[[:space:]]*RandStream\.getGlobalStream' experiment/continuous_DC_task.m 'global contdc RNG'
check_grep 'ch\(k\)\.timedOut' experiment/continuous_DC_task.m 'skip timed-out reversals'
check_grep 'isnan\(ch\(k\)\.choseMoney\)' experiment/continuous_DC_task.m 'skip NaN reversals'
check_grep 'cfg\.contdc\.nPairs\.\(lower\(domain\)\)' experiment/continuous_DC_task.m 'domain-specific pair counts'
check_grep 'aoiLayouts' experiment/continuous_DC_task.m 'contdc saved AOI layouts'
check_grep 'buildAoiLayouts' experiment/continuous_DC_task.m 'contdc AOI layout helper'
check_grep 'drawCard\(.*\);' experiment/continuous_DC_task.m 'contdc drawCard calls still present'
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

# --- AOI geometry duplicated between the tasks and preflight.m ----------
# preflight.m re-implements the layout functions by hand. If these drift
# apart, the AOI check silently stops describing what is actually drawn.
# These are the first automated checks on that duplication; they are worth
# keeping whether or not the restyle survives.
check_grep 'pad = 48;'  experiment/auction_task.m       'auction grid pad'
check_grep 'pad = 48;'  experiment/preflight.m          'preflight grid pad (must match auction_task)'
check_grep 'marg = 70;' experiment/continuous_DC_task.m 'contdc two-card margin'
check_grep 'marg = 70;' experiment/preflight.m          'preflight two-card margin (must match contdc)'
check_grep 'pad = 18;'  experiment/continuous_DC_task.m 'contdc card inner pad'
check_grep 'pad = 18;'  experiment/preflight.m          'preflight card inner pad (must match contdc)'
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

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
