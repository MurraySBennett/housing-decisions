# Stimuli

`experiment/stimuli/` is roughly **605MB** — 501 files of house images plus the
stimulus lists. Required to run the experiment, deliberately not in git.

## What is there

| | |
|---|---|
| `stimuli/house_images/` | Room images: `bath*`, `bed*`, `kit*`, `liv*`, `out*`, `ext*` |
| `stimuli/house_stimuli.csv` | The stimulus list. **Pruned in March 2026** — 19KB down to 16KB. The current version is authoritative. |
| `stimuli/job_stimuli.csv` | Wage/job stimulus list, updated April 2026 |

The two CSVs are small and *are* tracked, since they define the design. Only the
images are excluded.

## Where it lives

Referenced through `$DATA_ROOT` so no path here names a machine:

```matlab
data_root = getenv('DATA_ROOT');
stim_dir  = fullfile(data_root, 'housing-decisions', 'stimuli');
```

## Note

The pruned stimulus set is a deliberate design decision, not data loss. If an
older analysis refers to stimuli absent from the current list, it predates
March 2026.
