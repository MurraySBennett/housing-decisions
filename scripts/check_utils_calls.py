#!/usr/bin/env python3
"""check_utils_calls.py -- every utils.X(...) call has a +utils/X.m behind it.
MATLAB resolves package calls at call time and this machine has no MATLAB, so
this is the only pre-rig check; comments are stripped since they name utils functions."""

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    have = {
        os.path.splitext(os.path.basename(f))[0]
        for f in glob.glob(os.path.join(ROOT, 'experiment', '+utils', '*.m'))
    }
    if not have:
        print('no experiment/+utils/*.m found -- wrong root?', file=sys.stderr)
        return 1

    targets = (glob.glob(os.path.join(ROOT, 'experiment', '*.m'))
               + glob.glob(os.path.join(ROOT, 'experiment', '+utils', '*.m'))
               + glob.glob(os.path.join(ROOT, 'scripts', '*.m')))

    bad = set()
    for f in targets:
        with open(f, encoding='utf-8') as fh:
            src = fh.read()
        code = '\n'.join(re.sub(r'(^|\s)%.*$', '', ln) for ln in src.split('\n'))
        for m in re.finditer(r'\butils\.(\w+)\s*\(', code):
            if m.group(1) not in have:
                bad.add((os.path.relpath(f, ROOT), m.group(1)))

    for f, n in sorted(bad):
        print('unresolved: utils.%s called from %s' % (n, f), file=sys.stderr)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
