# Stimuli

The house images are roughly **605MB**. They are required to run the houses
tasks and deliberately not in git.

## What is there

| | |
|---|---|
| `house_images/` | Room images: `bath*`, `bed*`, `kit*`, `liv*`, `out*`, `ext*` |
| `stimuli/house_stimuli.csv` | The stimulus list. **Pruned in March 2026** — 19KB down to 16KB. The current version is authoritative. |
| `stimuli/job_stimuli.csv` | Wage/job stimulus list, updated April 2026 |

The CSVs are small and *are* tracked under `experiment/stimuli/`, since they
define the design. Only the images are excluded.

## Where it lives

The default lab path is:

```text
\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment\stimuli\house_images
```

Override it with `HW_ASSET_ROOT` when a machine has a local copy.

## Note

The pruned stimulus set is a deliberate design decision, not data loss. If an
older analysis refers to stimuli absent from the current list, it predates
March 2026.
