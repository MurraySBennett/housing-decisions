#!/usr/bin/env python3
"""window_check.py -- distinct anchor values inside an anchor-centred window.

Mirrors +utils/sampleWindow.m exactly, including the widening loop, because
the failure this exists to catch is invisible in the full stimulus set: a
column can hold plenty of distinct values and still collapse to one or two
once the window slices it, and at one value the anchor is collinear with
the intercept and its coefficient is not identified at all.

More levels in the file is NOT the same as more levels inside a window.
That is the whole point -- check the window, never the column.

    python3 window_check.py prepared/job_stimuli_synthetic.csv wage
    python3 window_check.py ../house_stimuli.csv listPrice --anchors 250000 350000
"""

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd

SPREAD = (0.6, 1.6)     # cfg.sampling.spread
MIN_N = 12              # cfg.sampling.minN
MAX_WIDEN = 6.0


def sample_window(values, anchor, spread=SPREAD, min_n=MIN_N):
    """Port of utils.sampleWindow's widening loop. Returns (lo, hi, idx, widen)."""
    v = np.asarray(values, dtype=float)
    usable = v[~np.isnan(v)]
    widen = 1.0
    while True:
        lo = anchor * (1 - (1 - spread[0]) * widen)
        hi = anchor * (1 + (spread[1] - 1) * widen)
        n = int(((usable >= lo) & (usable <= hi)).sum())
        if n >= min_n or widen >= MAX_WIDEN:
            break
        widen *= 1.25
    idx = np.where(~np.isnan(v) & (v >= lo) & (v <= hi))[0]
    return lo, hi, idx, widen


def fit_to_window(values, anchor, spread=SPREAD):
    """Port of +utils/fitToWindow.m -- rank, averaging ties, then lay the
    set out geometrically across [lo, hi]. Every stimulus lands inside."""
    v = np.asarray(values, dtype=float)
    idx = np.where(~np.isnan(v))[0]
    n = len(idx)
    lo, hi = anchor * spread[0], anchor * spread[1]
    sub = v[idx]
    order = np.argsort(sub, kind='stable')
    r = np.zeros(n)
    k = 0
    while k < n:
        j = k
        while j < n - 1 and sub[order[j + 1]] == sub[order[k]]:
            j += 1
        r[order[k:j + 1]] = (k + j) / 2 + 1      # mean rank, 1-based
        k = j + 1
    frac = np.zeros(n) + 0.5 if n == 1 else (r - 1) / (n - 1)
    fitted = np.exp(np.log(lo) + frac * (np.log(hi) - np.log(lo)))
    out = np.full_like(v, np.nan)
    out[idx] = fitted
    return lo, hi, idx, out


def report_fit(df, column, anchors, label, need, presentations):
    v = df[column].astype(float).values
    print(f'{label}: {len(v)} rows, fitted onto the window by rank')
    print(f'  {"anchor":>10}  {"window":>23}  {"n":>4}  {"occupancy":>15}  '
          f'{"reuse":>6}  need {need}')
    for a in anchors:
        lo, hi, idx, fitted = fit_to_window(v, a)
        f = fitted[idx]
        # occupancy across four equal log-slices of the window
        edges = np.exp(np.linspace(np.log(lo), np.log(hi), 5))
        occ = [int(((f >= edges[i]) & (f <= edges[i + 1])).sum()) for i in range(4)]
        flag = '' if len(idx) >= need else '   <-- short'
        print(f'  {a:10.0f}  {lo:10.0f} to {hi:10.0f}  {len(idx):4d}  '
              f'{"/".join(str(o) for o in occ):>15}  '
              f'{presentations/len(idx):5.1f}x{flag}')
    # rank order and ties must survive exactly
    lo, hi, idx, fitted = fit_to_window(v, anchors[len(anchors)//2])
    raw, fit = v[idx], fitted[idx]
    rank_ok = np.array_equal(np.argsort(np.argsort(raw, kind='stable'), kind='stable'),
                             np.argsort(np.argsort(fit, kind='stable'), kind='stable'))
    ties_ok = all(len(np.unique(fit[raw == u])) == 1 for u in np.unique(raw))
    print(f'  rank order preserved: {rank_ok}   tied prices stay tied: {ties_ok}')
    return rank_ok and ties_ok


def max_abs_r(df, cols):
    """Largest |r| between any two attribute columns. NaN if degenerate."""
    use = [c for c in cols if c in df.columns and df[c].nunique() > 1]
    if len(use) < 2:
        return float('nan')
    C = np.corrcoef(df[use].astype(float).values, rowvar=False).copy()
    np.fill_diagonal(C, 0.0)
    return float(np.nanmax(np.abs(C)))


def report(df, column, anchors, label, min_distinct=4, attr_cols=None):
    v = np.asarray(df[column], dtype=float)
    print(f'{label}: {len(v)} rows, {len(np.unique(v[~np.isnan(v)]))} distinct overall')
    head = f'  {"anchor":>10}  {"window":>21}  {"n":>4}  {"widen":>5}  {"distinct":>8}'
    if attr_cols:
        head += f'  {"max|r|":>7}'
    print(head)
    worst = None
    worst_r = 0.0
    for a in anchors:
        lo, hi, idx, widen = sample_window(v, a)
        d = len(np.unique(v[idx]))
        worst = d if worst is None else min(worst, d)
        flag = '' if d >= min_distinct else '   <-- too few'
        line = (f'  {a:10.0f}  {lo:9.0f} to {hi:9.0f}  {len(idx):4d}  '
                f'{widen:5.2f}  {d:8d}')
        if attr_cols:
            # Orthogonality is optimised over the FULL set, but the
            # participant only ever sees a window. Selecting on the anchored
            # column truncates its range, so the design has to be checked
            # where it is actually used.
            r = max_abs_r(df.iloc[idx], attr_cols)
            worst_r = max(worst_r, 0.0 if np.isnan(r) else r)
            line += f'  {r:7.3f}'
        print(line + flag)
    tail = f'  worst case: {worst} distinct'
    if attr_cols:
        tail += f', max|r| {worst_r:.3f} in window'
    print(tail + '\n')
    return worst


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('csv', help='prepared stimulus CSV')
    ap.add_argument('column', help='the anchored value column (wage / listPrice)')
    ap.add_argument('--anchors', type=float, nargs='+', default=None,
                    help='anchors to test (default: plausible wage anchors)')
    ap.add_argument('--min-distinct', type=int, default=4,
                    help='flag windows below this many distinct values')
    ap.add_argument('--attrs', nargs='*', default=None,
                    help='attribute columns to report within-window max|r| over')
    ap.add_argument('--fit', action='store_true',
                    help='report utils.fitToWindow instead of utils.sampleWindow')
    ap.add_argument('--need', type=int, default=36,
                    help='distinct stimuli the design needs in a window')
    ap.add_argument('--presentations', type=int, default=288,
                    help='total option presentations (nTrials x nOptionsPerTrial)')
    args = ap.parse_args()

    # Take the path as given if it resolves from the current directory, and
    # only then fall back to the script's own directory -- this gets run
    # both from the repo root and from stimgen/.
    path = Path(args.csv)
    if not path.exists():
        path = Path(__file__).resolve().parent / args.csv

    df = pd.read_csv(path)
    if args.column not in df.columns:
        sys.exit(f'no column "{args.column}" in {path.name}')

    anchors = args.anchors or [18, 25, 40, 60]
    if args.fit:
        ok = report_fit(df, args.column, anchors, f'{path.name}:{args.column}',
                        args.need, args.presentations)
        return 0 if ok else 1
    worst = report(df, args.column, anchors, f'{path.name}:{args.column}',
                   args.min_distinct, attr_cols=args.attrs)
    return 0 if worst >= args.min_distinct else 1


if __name__ == '__main__':
    sys.exit(main())
