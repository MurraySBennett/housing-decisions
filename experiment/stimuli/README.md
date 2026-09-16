# Stimulus preparation pipeline

Prepare once, commit the output *and* its provenance file, and treat the
result as frozen. Nothing in here should ever run during an experiment
session — the previous design imputed missing attributes inside the task
with a fixed `RandStream`, which reused the same permutation across every
attribute and every participant.

## Layout

```
stimuli/
  house_stimuli.csv        <- your raw data
  job_stimuli.csv          <- your raw data
  house_images/             <- your house photos
  prepare_stimuli.py        <- this script
  stimgen/
    configs/
      jobs_ecological.json
      jobs_synthetic.json
      jobs_attenuated.json
  prepared/                 <- generated, see below
    job_stimuli_synthetic.csv
    job_stimuli_synthetic_provenance.json
    ...
```

Paths inside a config (`input_file`, `output_file`) are resolved relative to
**this script's own directory** (`stimuli/`), not the current working
directory and not the config file's own directory. That's deliberate:
configs live one level down in `stimgen/configs/`, so anchoring to cwd or to
the config's own folder would break depending on where you happened to run
the command from. Anchoring to the script means it works the same whether
you run it from `stimuli/`, from `stimuli/stimgen/configs/`, or from
anywhere else, as long as you point `--config` at the right file.

## Quick start

Run from anywhere, pointing at the config:

```bash
python3 stimuli/prepare_stimuli.py --config stimuli/stimgen/configs/jobs_synthetic.json
```

or from inside `stimuli/`:

```bash
cd stimuli
python3 prepare_stimuli.py --config stimgen/configs/jobs_ecological.json
python3 prepare_stimuli.py --config stimgen/configs/jobs_synthetic.json
python3 prepare_stimuli.py --config stimgen/configs/jobs_attenuated.json --report-only
```

Requires `numpy` and `pandas`. Each run writes
`prepared/<name>.csv` plus `prepared/<name>_provenance.json`, which records
the script version, the seed, hashes of the input file / config / output,
and per-step diagnostics. Same config + same input = byte-identical output.

MATLAB (`utils.config`) reads `stimuli/prepared/job_stimuli_<arm>.csv`
directly by that naming convention -- there is no separate copy or rename
step. Set `JOBS_ARM` in `run_battery.m` to pick the arm.

## The three arms

The five subjective ratings in the raw Seek data are correlated at r = 0.72
to 0.96 (Culture–Management r = 0.96, VIF ≈ 13). That is real — a good
employer genuinely is good across the board — but it means the participant's
attribute *weights* are not identifiable: "culture 0.8 / management 0.0",
"0.0 / 0.8" and "0.4 / 0.4" all predict identical behaviour. You would need
roughly 13× the trials to separate them.

| arm | config | max \|r\| | what it's for |
|---|---|---|---|
| **ecological** | `jobs_ecological.json` | 0.95 | Out-of-sample validation. Real listings, natural covariance. Weights **not** estimable here. |
| **attenuated** | `jobs_attenuated.json` | 0.50 | Optional middle ground. Real values and group means, permuted pairing. 1.3× trial cost. |
| **synthetic** | `jobs_synthetic.json` | 0.22 | Estimating attribute weights. Balanced factorial space, orthogonal by construction. |

The intended design is **two clean arms**: estimate weights on the synthetic
arm where they're identifiable, then test whether those weights predict
out-of-sample on the ecological arm where they aren't. That validation step
is stronger than either arm alone, and it directly answers the "does this
generalise to the real world?" objection that a purely orthogonal design
invites.

The attenuated arm exists if you want a single-arm compromise, but a
reshuffled ecological set is a chimera — no longer real listings, not yet
orthogonal, and awkward to describe in a paper. Prefer two clean arms.

## Modes

**`ecological`** — hot-deck imputation of rows with no attribute data
(donor drawn from the same industry, then jittered), and nothing else.

**`permuted`** — imputation, then values are swapped *within* an
industry × attribute cell until cross-attribute correlation drops to
`target_max_r`. Because permutation never leaves a cell, every attribute's
marginal distribution and every industry's mean are preserved **exactly**;
only which row holds which value changes.

**`synthetic`** — a balanced factorial-style space built from scratch. Each
attribute takes `n_levels` levels, each level appears equally often, and the
assignment is optimised for orthogonality. Levels map onto quantile
midpoints of the real data, so values stay plausible. Set
`group_carries_signal: true` if you want industry to predict attributes.

`n_levels_by_column` and `spacing_by_column` override the default for named
attributes. Both exist for one reason: **the anchored attribute is not like
the others.** Wage doubles as the advertised anchor, so it is the only
column `utils.sampleWindow` slices, and the window is a fixed *ratio* band
around the participant's anchor (0.6× to 1.6×). A 4-level grid left a
participant anchored at $60/hr seeing a single distinct wage — collinear
with the intercept, so the anchor coefficient is not identified at all — and
quantile midpoints made it worse at the top, because they inherit the real
wage distribution's skew and put 11 of 12 levels below $50. Wage is
therefore generated at 12 levels, spaced geometrically, which holds 4–6
distinct values in every window from a $15 anchor to an $80 one. The five
rating attributes stay at 4 quantile-spaced levels, which is what they want.

**Check the window, never the column.** More levels in the file is not the
same as more levels inside a window, and the full set looks fine in both
cases. After regenerating anything:

```bash
python3 stimgen/window_check.py prepared/job_stimuli_synthetic.csv wage \
        --attrs workLife culture compensationBenefits management \
                jobSecurityAdvancement wage
```

It mirrors `sampleWindow`'s widening loop, prints distinct anchored values
per window, and — with `--attrs` — the within-window `max |r|`. That second
number is worth knowing: orthogonality is optimised over all 128 rows, but
no participant ever sees all 128. In the synthetic arm the in-window figure
runs 0.19–0.32, which is about what finite-sample noise gives at n ≈ 40–66.
In `attenuated` it runs 0.43–0.76 — the arm's own r = 0.5 understates what
windowing does to it, which is a further reason not to use it as the
weight-estimating arm.

## Editing a config

Attribute definitions, industry means for the generated columns, and the
work-arrangement mixes all live in the JSON — no code changes needed.

Two things worth knowing before you edit:

- Under the realistic work-arrangement mix, `workArrangement` has **zero
  variance** in Agriculture, Construction and Retail. Ecologically correct,
  but if a participant's top-4 industries are all onsite-dominated, that
  attribute contributes nothing to their data. Set `"balanced": true` on
  that entry to vary it within every industry.
- The generated columns (commute, PTO, hours) are deliberately *not* given
  their real-world correlations with pay. Correlated predictors are the
  thing that makes weights unrecoverable, which is the whole problem the
  synthetic arm exists to solve. Industry means carry the plausibility;
  within-industry residuals are independent draws.

## Houses

No preparation needed. The house attributes are already well conditioned
(max VIF 6.0, condition number 5.2), there is no missing data, and the
`$9.98M` outlier is handled at runtime by `utils.sampleWindow` — which
derives pricing-scale bounds from the block's sampled range rather than
from the individual item, so the outlier never distorts the response
scale.

House photo filenames are normalized at load time (`utils.readStimuli`
strips any leftover directory prefix down to the bare filename), so it
doesn't matter whether this CSV's image columns hold `ext1.png` or
`.\Stimuli\Images\ext1.png` -- either works. If images still don't render,
`utils.checkImages` diagnoses the mismatch without needing PTB or a
running task.

## Selecting an arm at runtime

Don't copy or rename the output files. `utils.config` reads
`prepared/job_stimuli_<arm>.csv` directly by convention, and loads the
matching `_provenance.json` alongside it into `cfg.stimuli.jobsProvenance`
-- so every saved participant file can be traced back to exactly which
script version, seed, and config produced their stimuli.

Set the arm in `run_battery.m`:

```matlab
JOBS_ARM = 'synthetic';   % or 'ecological' / 'attenuated'
```

A manual copy-and-rename (e.g. cp job_stimuli_synthetic.csv job_stimuli_v2.csv)
breaks that link silently -- the file loads fine, but there is no longer any
record of which config or seed produced it. If you want a fixed set for a
specific data collection wave, keep it under its arm name and note the arm
plus the seed in your lab notebook; don't rename it to something generic.

Note `cfg.contdc.nPairs` is per-domain now (`.houses` and `.jobs` are set
separately) -- see the main project README's "Stimulus reuse" section for
why, and for how that interacts with how many industries/attributes a
given arm supplies.
