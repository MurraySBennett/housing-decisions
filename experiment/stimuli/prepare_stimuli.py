#!/usr/bin/env python3
"""
prepare_stimuli.py -- reproducible stimulus preparation.

Reads a raw stimulus table plus a JSON config, writes a prepared stimulus
table plus a provenance record. Nothing here happens at runtime: prepare
once, commit the output and the provenance, and treat the result as frozen.

Three modes, selected in the config:

  ecological  Impute missing rows only. Natural covariance preserved.
              Attribute weights are NOT identifiable in this arm -- it is
              for out-of-sample validation of weights estimated elsewhere.

  permuted    Impute, then permute values within group to attenuate
              cross-attribute correlation to a target. Every attribute's
              marginal distribution and every group mean are preserved
              EXACTLY; only the row-wise pairing changes.

  synthetic   Generate a fully balanced feature space from scratch. Each
              attribute takes k levels, each level appears equally often,
              and the level assignment is optimised for orthogonality.
              Marginals can be matched to the source so values stay
              plausible, or spread evenly across the range.

Usage:
    python3 prepare_stimuli.py --config configs/jobs_ecological.json
    python3 prepare_stimuli.py --config configs/jobs_synthetic.json --report-only
"""

import argparse
import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd

__version__ = '1.0.0'


# ============================================================ provenance
def file_hash(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()[:16]


def obj_hash(obj):
    return hashlib.sha256(
        json.dumps(obj, sort_keys=True).encode()).hexdigest()[:16]


# ================================================================ report
def corr_matrix(df, cols):
    return np.array(df[cols].corr().values, copy=True)


def max_offdiag_r(df, cols):
    C = corr_matrix(df, cols)
    np.fill_diagonal(C, 0.0)
    return float(np.abs(C).max())


def vif(df, cols):
    X = (df[cols] - df[cols].mean()) / df[cols].std()
    out = {}
    for c in cols:
        y = np.array(X[c].values, dtype=float, copy=True)
        Z = np.array(X[[k for k in cols if k != c]].values, dtype=float, copy=True)
        Z = np.c_[np.ones(len(Z)), Z]
        b, *_ = np.linalg.lstsq(Z, y, rcond=None)
        r2 = 1 - ((y - Z @ b) ** 2).sum() / ((y - y.mean()) ** 2).sum()
        out[c] = float(1 / max(1 - r2, 1e-12))
    return out


def report(df, cols, label):
    print(f'\n--- {label} ---')
    print(df[cols].corr().round(2).to_string())
    v = vif(df, cols)
    print('\nVIF (>10 severe, >5 worth noting):')
    for k, val in v.items():
        flag = '  <-- HIGH' if val > 10 else ('  <-- note' if val > 5 else '')
        print(f'  {k:>26}: {val:7.2f}{flag}')
    mx = max_offdiag_r(df, cols)
    print(f'\nmax |r| = {mx:.3f}   ->  {1/(1-mx**2):.1f}x trials for equal precision')
    return {'max_abs_r': mx, 'vif': v}


# ============================================================== 1 impute
def impute_hotdeck(df, cfg, rng):
    """Copy a complete row's profile from the same group, then jitter."""
    cols = cfg['attribute_columns']
    grp = cfg.get('group_column')
    missing = df[cols].isna().all(axis=1)
    n = int(missing.sum())
    if n == 0:
        print('  nothing to impute')
        return df, {'n_imputed': 0}

    print(f'  imputing {n} rows with no attribute data')
    jitter = cfg.get('impute', {}).get('jitter_sd', 0.15)
    minimum_donors = cfg.get('impute', {}).get('min_donors', 3)

    for idx in df.index[missing]:
        donors = df[~missing]
        if grp:
            same = df[(df[grp] == df.at[idx, grp]) & ~missing]
            if len(same) >= minimum_donors:
                donors = same
        donor = donors.sample(1, random_state=int(rng.integers(1e9))).iloc[0]

        for c in cols:
            lo, hi = df[c].min(), df[c].max()
            spec = cfg['attributes'].get(c, {})
            dec = spec.get('decimals', 1)
            scale = spec.get('jitter_scale', 'absolute')
            if scale == 'relative':
                val = donor[c] * rng.normal(1.0, jitter)
            else:
                val = donor[c] + rng.normal(0, jitter)
            df.at[idx, c] = round(float(np.clip(val, lo, hi)), dec)

    return df, {'n_imputed': n, 'jitter_sd': jitter}


# =========================================================== 2 attenuate
def decorrelate(df, cols, rng, target, iters, group_column=None):
    """Swap values within (group x attribute) cells to reduce correlation.

    Permutation is confined to a group-attribute cell, so the marginal
    distribution of each attribute and the group mean for each attribute
    are preserved exactly. Only which row holds which value changes.
    """
    df = df.copy()
    M = np.array(df[cols].values, dtype=float, copy=True)

    if group_column:
        codes = pd.Categorical(df[group_column]).codes
        groups = [np.where(codes == g)[0] for g in np.unique(codes)]
    else:
        groups = [np.arange(len(df))]

    def cost(mat):
        C = np.corrcoef(mat, rowvar=False).copy()
        np.fill_diagonal(C, 0.0)
        A = np.abs(C)
        return A.max() + 0.25 * A.mean(), float(A.max())

    best, worst = cost(M)
    print(f'  start  max|r| = {worst:.3f}   target {target:.2f}')

    kept = 0
    for it in range(iters):
        g = groups[rng.integers(len(groups))]
        if len(g) < 2:
            continue
        c = rng.integers(len(cols))
        i, j = rng.choice(g, size=2, replace=False)
        if M[i, c] == M[j, c]:
            continue
        M[i, c], M[j, c] = M[j, c], M[i, c]
        newcost, neww = cost(M)
        if newcost < best:
            best, worst, kept = newcost, neww, kept + 1
            if worst <= target:
                print(f'  target reached at iteration {it}')
                break
        else:
            M[i, c], M[j, c] = M[j, c], M[i, c]

    for k, c in enumerate(cols):
        df[c] = M[:, k]
    print(f'  end    max|r| = {worst:.3f}   ({kept} swaps kept)')
    return df, {'final_max_r': worst, 'swaps_kept': kept, 'iterations': it + 1}


# =========================================================== 3 synthesise
def synthesise(cfg, rng):
    """Balanced factorial-style feature space, optimised for orthogonality.

    Each attribute takes k levels; each level appears equally often; the
    assignment across attributes is optimised so that no two attributes
    are correlated above the target. Group labels carry no attribute
    signal unless group_carries_signal is set.
    """
    spec = cfg['synthetic']
    n = spec['n_rows']
    cols = cfg['attribute_columns']
    nlev = spec.get('n_levels', 4)
    target = spec.get('target_max_r', 0.15)
    iters = spec.get('iterations', 60000)

    # n_levels is the default for every attribute; n_levels_by_column
    # overrides it for named ones. This exists because an attribute that
    # ALSO serves as the advertised anchor is the only one the runtime
    # slices (utils.sampleWindow), and a 4-level grid can leave a single
    # distinct value inside a window -- collinear with the intercept, so
    # its coefficient is not identified. The rating attributes want few
    # levels; the anchored one wants enough to survive the slice.
    per_col = spec.get('n_levels_by_column', {})
    unknown = set(per_col) - set(cols)
    if unknown:
        raise SystemExit(f'n_levels_by_column names non-attribute columns: '
                         f'{sorted(unknown)}')
    nlevs = [int(per_col.get(c, nlev)) for c in cols]

    # Level SPACING, per column. 'quantile' (the default) puts levels at
    # quantile midpoints of the real data, so values look like real values
    # -- but it inherits the source's skew, and for the anchored column
    # that is the wrong shape: the window is a fixed RATIO band around the
    # anchor (0.6x to 1.6x), so a skewed grid gives plenty of levels in the
    # dense middle and almost none at the top. 'geometric' spaces levels
    # evenly in log space across the same span, which makes the number of
    # levels inside a window roughly constant at every anchor.
    spacing_by_col = spec.get('spacing_by_column', {})
    unknown = set(spacing_by_col) - set(cols)
    if unknown:
        raise SystemExit(f'spacing_by_column names non-attribute columns: '
                         f'{sorted(unknown)}')
    bad = {v for v in spacing_by_col.values()} - {'quantile', 'geometric'}
    if bad:
        raise SystemExit(f'unknown spacing(s): {sorted(bad)} '
                         f'(expected "quantile" or "geometric")')

    # Within-level jitter. A bare factorial shows every participant the same
    # four numbers over and over, which no real listing set does -- and a
    # participant who notices that every job pays one of four wages is doing
    # a different task from the one we think. Jitter buys natural-looking
    # variation without touching the design: the LEVEL assignment is already
    # fixed above, so each level still appears equally often and the
    # orthogonality that was optimised over level indices is untouched.
    #
    # The unit is a fraction of the HALF-GAP to the nearest neighbouring
    # level, not an absolute amount or a percentage of the value. That is
    # what makes one number safe across a 1-5 rating scale and a $12-$92
    # geometric wage grid at once: it is derived from the actual spacing, so
    # at any value below 1.0 a jittered value can never wander into a
    # neighbouring level's territory. 0.5 is comfortably inside.
    jitter_default = float(spec.get('jitter', 0.0))
    jitter_by_col = spec.get('jitter_by_column', {})
    unknown = set(jitter_by_col) - set(cols)
    if unknown:
        raise SystemExit(f'jitter_by_column names non-attribute columns: '
                         f'{sorted(unknown)}')
    jitters = [float(jitter_by_col.get(c, jitter_default)) for c in cols]
    if any(j < 0 or j > 1 for j in jitters):
        raise SystemExit('jitter must be between 0 (off) and 1 (up to the '
                         'midpoint between adjacent levels)')

    # --- Balanced level assignment per attribute ----------------------
    M = np.zeros((n, len(cols)))
    for k, kl in enumerate(nlevs):
        if n % kl:
            print(f'  NOTE: {cols[k]} has {kl} levels but n_rows={n} is not a '
                  f'multiple of it -- {n % kl} level(s) appear once more '
                  f'than the rest')
        base = np.tile(np.arange(kl), int(np.ceil(n / kl)))[:n]
        M[:, k] = rng.permutation(base)

    def cost(mat):
        C = np.corrcoef(mat, rowvar=False).copy()
        np.fill_diagonal(C, 0.0)
        A = np.abs(C)
        return A.max() + 0.25 * A.mean(), float(A.max())

    best, worst = cost(M)
    if len(set(nlevs)) == 1:
        print(f'  balanced grid: {n} rows x {len(cols)} attrs x {nlev} levels')
    else:
        detail = ', '.join(f'{c}={k}' for c, k in zip(cols, nlevs))
        print(f'  balanced grid: {n} rows x {len(cols)} attrs, levels: {detail}')
    print(f'  start  max|r| = {worst:.3f}   target {target:.2f}')
    for it in range(iters):
        c = rng.integers(len(cols))
        i, j = rng.choice(n, size=2, replace=False)
        if M[i, c] == M[j, c]:
            continue
        M[i, c], M[j, c] = M[j, c], M[i, c]
        newcost, neww = cost(M)
        if newcost < best:
            best, worst = newcost, neww
            if worst <= target:
                print(f'  target reached at iteration {it}')
                break
        else:
            M[i, c], M[j, c] = M[j, c], M[i, c]
    print(f'  end    max|r| = {worst:.3f}')

    # --- Map levels onto values ---------------------------------------
    df = pd.DataFrame(index=range(n))
    src = None
    if spec.get('marginals') == 'match_source':
        src = pd.read_csv(cfg['input_file'])

    for k, c in enumerate(cols):
        aspec = cfg['attributes'][c]
        dec = aspec.get('decimals', 1)
        kl = nlevs[k]
        if src is not None and c in src.columns and src[c].notna().any():
            # Level i -> the midpoint of quantile bin i of the real data,
            # so values look like real values but the design stays balanced.
            qs = np.linspace(0, 1, kl + 1)
            edges = np.nanquantile(src[c].astype(float), qs)
            mids = (edges[:-1] + edges[1:]) / 2
        else:
            lo, hi = aspec['range']
            mids = np.linspace(lo, hi, kl)
        if spacing_by_col.get(c, 'quantile') == 'geometric':
            # Same span, log-uniform inside it. Keeping the endpoints means
            # the values stay in the range the real data occupies.
            if mids[0] <= 0:
                raise SystemExit(f'geometric spacing needs a positive lower '
                                 f'endpoint; {c} starts at {mids[0]:g}')
            mids = np.geomspace(mids[0], mids[-1], kl)
        exact = mids[M[:, k].astype(int)]
        # Rounding can collapse two quantile midpoints onto one value, which
        # silently costs a level. At 4 levels it never happened; with a
        # finer grid on a skewed column it can, so say so rather than let
        # the design quietly shrink.
        if len(np.unique(np.round(exact, dec))) < kl:
            print(f'  WARNING: {c} asked for {kl} levels but rounding to '
                  f'{dec} decimal(s) leaves '
                  f'{len(np.unique(np.round(exact, dec)))} distinct values')

        if jitters[k] > 0 and kl > 1:
            # Half-gap to the NEAREST neighbour, per level. Edge levels have
            # one neighbour; interior levels take the smaller of the two, so
            # an uneven grid (quantile midpoints, or geometric, where gaps
            # differ by an order of magnitude end to end) is handled without
            # a special case.
            gaps = np.diff(mids)
            half = np.empty(kl)
            half[0] = gaps[0] / 2
            half[-1] = gaps[-1] / 2
            if kl > 2:
                half[1:-1] = np.minimum(gaps[:-1], gaps[1:]) / 2
            amp = half[M[:, k].astype(int)] * jitters[k]
            exact = exact + rng.uniform(-1, 1, n) * amp
        vals = np.round(exact, dec)
        df[c] = vals
        if dec == 0:
            df[c] = df[c].astype(int)

    # --- Group / identity labels --------------------------------------
    grp = cfg.get('group_column')
    if grp:
        levels = spec.get('group_levels')
        if levels is None and src is not None:
            levels = sorted(src[grp].dropna().unique().tolist())
        reps = int(np.ceil(n / len(levels)))
        labels = np.tile(levels, reps)[:n]
        if not spec.get('group_carries_signal', False):
            labels = rng.permutation(labels)   # group orthogonal to attributes
        df[grp] = labels

    for extra in cfg.get('id_columns', []):
        if extra != grp and extra not in df.columns:
            df[extra] = [f'{extra}_{i+1:03d}' for i in range(n)]

    return df, {'n_levels': nlev,
                'n_levels_by_column': {c: k for c, k in zip(cols, nlevs)},
                'spacing_by_column': {c: spacing_by_col.get(c, 'quantile')
                                      for c in cols},
                'jitter_by_column': {c: j for c, j in zip(cols, jitters)},
                'final_max_r': worst,
                'group_carries_signal': spec.get('group_carries_signal', False)}


# ========================================================= 4 new columns
def generate_columns(df, cfg, rng):
    """Add derived/new attributes defined in the config.

    Real-world versions of these correlate with pay and with each other.
    We deliberately do not reproduce that: correlated predictors are what
    makes attribute weights unrecoverable. Group means carry plausibility;
    within-group residuals are independent draws.
    """
    gen = cfg.get('generate', {})
    if not gen:
        return df, {}
    df = df.copy()
    grp = cfg.get('group_column')
    added = []

    for name, spec in gen.items():
        if spec['kind'] == 'numeric':
            means = spec['group_means']
            mu = df[grp].map(means).astype(float).values if grp \
                else np.full(len(df), spec['mean'])
            vals = mu + rng.normal(0, spec['sd'], len(df))
            lo, hi = spec['range']
            vals = np.clip(vals, lo, hi)
            df[name] = np.round(vals, spec.get('decimals', 0))
            if spec.get('decimals', 0) == 0:
                df[name] = df[name].astype(int)

        elif spec['kind'] == 'categorical':
            levels = spec['levels']
            mixes = spec['group_mixes'] if grp else None
            if spec.get('balanced', False) or mixes is None:
                reps = int(np.ceil(len(df) / len(levels)))
                df[name] = rng.permutation(np.tile(levels, reps)[:len(df)])
            else:
                df[name] = [rng.choice(levels, p=mixes[g]) for g in df[grp]]
        added.append(name)

    print(f'  added {", ".join(added)}')
    return df, {'generated': added}


# ================================================================== main
def resolve(path_str, base):
    """Resolve a config path relative to the SCRIPT's own directory, not
    the current working directory and not the config file's location.

    Configs live in stimgen/configs/ while the raw CSVs, this script, and
    the prepared/ output all live one level up in stimuli/ -- so paths
    written in a config as 'job_stimuli.csv' or 'prepared/foo.csv' need a
    single fixed anchor that doesn't change no matter where you run the
    script from or where the config happens to sit.
    """
    path = Path(path_str)
    return path if path.is_absolute() else (base / path)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--config', required=True, help='path to a JSON config')
    ap.add_argument('--input', default=None, help='override config input_file')
    ap.add_argument('--output', default=None, help='override config output_file')
    ap.add_argument('--seed', type=int, default=None, help='override config seed')
    ap.add_argument('--report-only', action='store_true',
                    help='print diagnostics without writing anything')
    args = ap.parse_args()

    script_dir = Path(__file__).resolve().parent
    cfg_path = Path(args.config)
    cfg = json.loads(cfg_path.read_text())
    if args.input:  cfg['input_file'] = args.input
    if args.output: cfg['output_file'] = args.output
    if args.seed is not None: cfg['seed'] = args.seed

    # Anchor to the script's directory (stimuli/), not cwd and not the
    # config file's directory (stimuli/stimgen/configs/) -- those two do
    # not match in this repo layout, which is exactly the case this needs
    # to handle correctly.
    cfg['input_file']  = str(resolve(cfg['input_file'], script_dir))
    if 'output_file' in cfg:
        cfg['output_file'] = str(resolve(cfg['output_file'], script_dir))

    mode = cfg['mode']
    seed = cfg['seed']
    rng = np.random.default_rng(seed)
    cols = cfg['attribute_columns']

    print(f'prepare_stimuli v{__version__}')
    print(f'config : {cfg_path}  ({cfg["name"]})')
    print(f'mode   : {mode}')
    print(f'seed   : {seed}')

    steps = {}

    if mode == 'synthetic':
        print('\n[1] synthesise balanced feature space')
        df, steps['synthesise'] = synthesise(cfg, rng)
    else:
        src_path = Path(cfg['input_file'])
        df = pd.read_csv(src_path)
        print(f'input  : {src_path}  ({len(df)} rows, sha256:{file_hash(src_path)})')
        print('\n[1] impute')
        df, steps['impute'] = impute_hotdeck(df, cfg, rng)
        before = report(df, cols, 'after imputation, before any attenuation')
        steps['before_attenuation'] = before

        att = cfg.get('attenuate', {})
        print('\n[2] attenuate correlations')
        if not att.get('enabled', False):
            print('  DISABLED -- natural covariance preserved.')
            print('  Attribute weights will NOT be identifiable in this arm.')
            steps['attenuate'] = {'enabled': False}
        else:
            df, steps['attenuate'] = decorrelate(
                df, cols, rng,
                target=att.get('target_max_r', 0.5),
                iters=att.get('iterations', 60000),
                group_column=cfg.get('group_column') if att.get('within_group', True) else None)
            steps['attenuate']['enabled'] = True

    print('\n[3] generate additional attributes')
    df, steps['generate'] = generate_columns(df, cfg, rng)

    final_cols = cols + [c for c in cfg.get('generate', {})
                         if cfg['generate'][c]['kind'] == 'numeric']
    steps['final'] = report(df, final_cols, 'FINAL')

    if cfg.get('column_order'):
        keep = [c for c in cfg['column_order'] if c in df.columns]
        df = df[keep + [c for c in df.columns if c not in keep]]

    if args.report_only:
        print('\n--report-only: nothing written.')
        return

    out_path = Path(cfg['output_file'])
    out_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out_path, index=False)

    prov = {
        'generated_utc': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'script': Path(__file__).name,
        'script_version': __version__,
        'python': platform.python_version(),
        'numpy': np.__version__,
        'pandas': pd.__version__,
        'config_file': str(cfg_path),
        'config_sha': obj_hash(cfg),
        'config': cfg,
        'seed': seed,
        'input_sha': file_hash(cfg['input_file']) if mode != 'synthetic' and Path(cfg['input_file']).exists() else None,
        'output_file': str(out_path),
        'output_sha': file_hash(out_path),
        'output_rows': int(len(df)),
        'output_columns': list(df.columns),
        'steps': steps,
    }
    prov_path = out_path.with_name(out_path.stem + '_provenance.json')
    prov_path.write_text(json.dumps(prov, indent=2, default=str))

    print(f'\nwrote {out_path}          ({len(df)} rows, {len(df.columns)} cols, sha256:{prov["output_sha"]})')
    print(f'wrote {prov_path}')


if __name__ == '__main__':
    sys.exit(main())
