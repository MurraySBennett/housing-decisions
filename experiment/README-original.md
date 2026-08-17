# Stimulus preparation pipeline

Prepare once, commit the output *and* its provenance file, and treat the
result as frozen. Nothing in here should ever run during an experiment
session — the previous design imputed missing attributes inside the task
with a fixed `RandStream`, which reused the same permutation across every
attribute and every participant.

## Quick start

```bash
python3 prepare_stimuli.py --config configs/jobs_ecological.json
python3 prepare_stimuli.py --config configs/jobs_synthetic.json
python3 prepare_stimuli.py --config configs/jobs_attenuated.json --report-only
```

Requires `numpy` and `pandas`. Each run writes
`prepared/<name>.csv` plus `prepared/<name>_provenance.json`, which records
the script version, the seed, hashes of the input file / config / output,
and per-step diagnostics. Same config + same input = byte-identical output.

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
| **synthetic** | `jobs_synthetic.json` | 0.19 | Estimating attribute weights. Balanced factorial space, orthogonal by construction. |

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
`$9.98M` outlier is handled at runtime by `hw.sampleWindow` — which derives
pricing-scale bounds from the block's sampled range rather than from the
individual item, so the outlier never distorts the response scale.