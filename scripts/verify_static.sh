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

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
