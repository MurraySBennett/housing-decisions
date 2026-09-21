# analysis/

Descriptive analysis of the housing/wages battery. R, because these scripts
have to be runnable and checkable on a machine with no MATLAB.

## Run it

```bash
# On simulated data -- works anywhere, needs nothing from the lab
Rscript analysis/R/run_all.R --simulate

# On a demo run produced by experiment/demo_battery.m
Rscript analysis/R/run_all.R --data experiment/Data_demo

# On real data
Rscript analysis/R/run_all.R --data '/path/to/PSY-kvam.4/housing_wages/Experiment/Data'
```

Output lands in `analysis/output/`: an integrity report, one combined CSV per
task, a reversals table, and figures under `figures/`. Files derived from
simulated data are prefixed `SIMULATED_`.

To pull the current lab data from the OSU share into this WSL checkout and
run the same analysis in one step:

```bash
PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
$PS -NoProfile -Command '$script = [scriptblock]::Create((Get-Content -Raw -LiteralPath "\\wsl.localhost\Ubuntu\home\msb\projects\housing-decisions\scripts\pull_data_from_share.ps1")); & $script'
```

The pull lands in ignored `data/lab/Data`, writes a manifest under
`data/lab/manifests/`, and writes analysis output to `analysis/output/lab/`.

Needs `dplyr readr tidyr stringr purrr ggplot2 scales tibble`.

## What each file does

| file | job |
|---|---|
| `R/io.R` | find the run CSVs, tidy them, recompute reversals, print an integrity report |
| `R/plots.R` | the descriptive figures; theme and palette live here |
| `R/run_all.R` | the entry point — load, report, export, plot |
| `R/simulate_demo_data.R` | fabricate CSVs in the saved schema, for testing the pipeline |

## What it reads, and what it does not

It reads the **CSVs** `utils.saveRun` writes: one file per run under
`<data>/auction/` and `<data>/cont_dc/`, long format, one row per trial, with
`participant`, `session`, `run_id` and `task` on every row. That is enough for
every descriptive here.

It does **not** read the `.mat`. The `.mat` holds the rest of `dataMat`:
the elicited anchor and attribute ratings, the sampled stimulus window, AOI
rectangles, the flip-time event log, and the pointer to the gaze file. Gaze
analysis and anything anchor-related needs those, and needs a MATLAB export
step first. That step is not written yet — it is the next piece of analysis
work, not a gap in these scripts.

`anchor` is the one `dataMat` field that does reach the CSV, because the
auction task's trial table carries it per row.

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
                   "ggplot2", "scales", "tibble"))
```

**Pointing at the share.** Use forward slashes; R accepts them on Windows and
they avoid the escaping problem backslashes create in R strings.

```bash
Rscript analysis/R/run_all.R --data "//asc-files.asc.ohio-state.edu/projects/PSY-kvam.4/housing_wages/Experiment/Data"
```

Reading several hundred small CSVs over SMB is slow. Copy the `Data` tree
locally first if you are iterating on a figure.
