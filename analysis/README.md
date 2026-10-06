# analysis/

Descriptive analysis of the housing/wages battery. R, because these scripts
have to be runnable and checkable on a machine with no MATLAB.

## Block-checkpoint exports

For the new format, run MATLAB `scripts/combine_blocks.m` on the immutable local
run-kind root, writing to a separate derived directory. Point `--data` at that
derived root. Do not put attempt fragments or incomplete exports in the task CSV
directories. Discovery is nonrecursive; `blocks/`, `partial/`, and `legacy/` are
excluded. Duplicate logical runs across CSV files cause an error.

The existing behavioral columns remain available. New columns identify the block,
attempt, schema and completeness. The gaze sidecar now stores `gazeExport.blocks`
with packed numeric leaves and sample-to-trial/phase associations per block;
integer timestamps retain their original precision. Invalid sync and legacy
onset limitations are explicit. See [storage and recovery instructions](../experiment/BLOCK_CHECKPOINTS.md).
Combining/syncing never modifies raw participant files. Legacy files can be
explicitly archived with the combiner, but their exact onsets are not reconstructed.

## Run it

For participant data QC, use `analysis/R/00_participant_qc.R`. Simulation is
kept in `analysis/R/90_simulate_data.R` so the real-data path cannot rewrite
or fabricate inputs by accident.

```bash
# On a demo run produced by experiment/demo_battery.m
Rscript analysis/R/00_participant_qc.R --data experiment/Data_demo

# On real data
Rscript analysis/R/00_participant_qc.R --data '/path/to/PSY-kvam.4/housing_wages/Experiment/Data'

# On practice/staff data
Rscript analysis/R/00_participant_qc.R --data '/path/to/PSY-kvam.4/housing_wages/Experiment/Data_practice' --include-practice

# Synthetic data sandbox only
Rscript analysis/R/90_simulate_data.R

# House-photo BTL worths from preference-task pairwise choices
Rscript analysis/R/10_photo_btl.R --data analysis/output --out analysis/output
```

Output lands in `analysis/output/`: an integrity report, combined CSVs for
auction, contdc, preference, and timing rows when present, a reversals table,
house-photo BTL estimates, explicit-rating norms when `10_photo_btl.R` is run,
and figures under `figures/`. Files derived from simulated data are prefixed
`SIMULATED_`.

To pull the current lab data from the OSU share into this WSL checkout and
run the same analysis in one step:

```bash
PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
$PS -NoProfile -Command '$script = [scriptblock]::Create((Get-Content -Raw -LiteralPath "\\wsl.localhost\Ubuntu\home\msb\projects\housing-decisions\scripts\pull_data_from_share.ps1")); & $script'
```

The pull lands in ignored `data/lab/Data`, writes a manifest under
`data/lab/manifests/`, and writes analysis output to `analysis/output/lab/`.
Use `-Practice` to pull `Experiment\Data_practice` into ignored
`data/lab/Data_practice`; the script passes `--include-practice` to R.

Needs `here dplyr readr tidyr stringr purrr ggplot2 scales tibble`.

## What each file does

| file | job |
|---|---|
| `R/io.R` | find the run CSVs, tidy them, recompute reversals, print an integrity report |
| `R/plots.R` | the descriptive figures; theme and palette live here |
| `R/00_participant_qc.R` | participant/demo/practice QC entry point |
| `R/10_photo_btl.R` | image-level Bradley-Terry-Luce worths from house-photo pairwise choices, joined to direct ratings |
| `R/run_all.R` | shared load/report/export/plot functions |
| `R/simulate_demo_data.R` | fabricate CSVs in the saved schema, for testing the pipeline |
| `R/90_simulate_data.R` | explicit synthetic-data sandbox entry point |

## What it reads, and what it does not

It reads the **CSVs** `utils.saveRun` writes: one file per run under
`<data>/auction/`, `<data>/cont_dc/`, and `<data>/pref/`, long format, one row
per trial, with `participant`, `session`, `run_id`, `task`, and `run_kind` on
every row. It also reads `<data>/sessions/*_timing.csv` when present.
`run_kind == "practice"` is excluded by default unless `--include-practice` is
passed.

It does **not** read the `.mat`. The `.mat` holds the rest of `dataMat`:
the elicited anchor and attribute ratings, the sampled stimulus window, AOI
rectangles, the flip-time event log, and the pointer to the gaze file. Gaze
analysis and anything anchor-related needs those, and needs a MATLAB export
step first. That step is not written yet — it is the next piece of analysis
work, not a gap in these scripts.

`anchor` is the one `dataMat` field that does reach the CSV, because the
auction task's trial table carries it per row.

## House-photo BTL estimates

`R/10_photo_btl.R` reads `pref_trials.csv` from an analysis output directory,
or raw `<data>/pref/*.csv` files from a run-data root. It fits
logistic-regression BTL models separately within `participant/session/run_id`
and house `areaVar`, because the pairwise trials compare photos only within an
area. It writes `photo_btl_estimates.csv` with centered/scaled image worths,
ratings, and win/loss/exposure counts, plus `photo_btl_summary.csv` with
area-level rating correlations and rank differences.

The same script also writes `photo_rating_norms.csv`: pooled explicit-rating
norms by `domain/areaVar/photoId`, with raw rating mean/median and
`rating_within_rater_area_z`, the average of ratings z-scored within each
participant/session/run/area. Use that normalized column for pooled
image-preference norms; raw ratings stay in the file to diagnose scale use.

`photo_btl_area_estimates.csv` and `photo_btl_area_summary.csv` are the pooled
within-area BTL estimates across raters. These stack all pairwise trials in an
area, so overlapping photo samples connect participants' information into one
area-local scale. If an area's comparison graph is disconnected, `component_id`
marks separate components; ranks are not identified across components. The
BTL/rating summary correlations use the normalized explicit-rating column.
`k_btl_01` and `rating_display_01` are min-max scaled within each area/component
for plotting only; the analytic columns remain `k_btl_z` and
`rating_within_rater_area_z`.

It also writes three diagnostic figures under `figures/`:
`30_photo_btl_vs_rating.png`, `31_photo_rank_agreement.png`, and
`32_photo_pairwise_coverage.png`. They show display-scaled BTL-vs-rating
agreement, rank agreement, and how many pairwise exposures each photo has.

## Reversal scoring is computed twice on purpose

`continuous_DC_task.m` scores preference reversals at save time into
`dataMat.<domain>.reversals`. `io.R::score_reversals()` recomputes the same
quantity from the CSV alone. Keeping both is the check that the CSV is
sufficient for the headline measure; if the two ever disagree, one of them
changed and the other did not.

## Caveats

- These are descriptives, not inference. No model fitting, no exclusions
  applied beyond dropping practice trials and timed-out responses where the
  measure requires it.
- `score_reversals` needs a non-timed-out choice **and** both prices for a
  pair. Its `n` is scorable pairs, not trials — the figure says so.
- Simulated data is a crude stand-in with the manipulations hard-coded into
  the generating lines. Nothing produced from it is a result.

## Running this on Windows

The analysis has only been run on WSL. Nothing in it is platform-specific --
every path goes through `file.path()` -- but two things need saying.

**Installing R.** The lab machine needs R and these packages. R is not required
to *run* a session, only to analyse one.

```r
install.packages(c("dplyr", "readr", "tidyr", "stringr", "purrr",
                   "ggplot2", "scales", "tibble", "here"))
```

**Pointing at the share.** Use forward slashes; R accepts them on Windows and
they avoid the escaping problem backslashes create in R strings.

```bash
Rscript analysis/R/00_participant_qc.R --data "//asc-files.asc.ohio-state.edu/projects/PSY-kvam.4/housing_wages/Experiment/Data"
```

Reading several hundred small CSVs over SMB is slow. Copy the `Data` tree
locally first if you are iterating on a figure.
