#!/usr/bin/env python3
"""Read a housing-wages crash .mat off-rig, without MATLAB.

    python3 scripts/read_crash_dump.py ~/downloads/sub-*_crash.mat

The dumps are MATLAB v7, so scipy.io.loadmat opens them and `sess`, `run`
and `dataMat` come back as ordinary structs. The MException does not: it is
an MCOS object and loadmat returns only a reference stub. Its char fields
survive verbatim in the MAT subsystem, which scipy hands back under the
undocumented `__function_workspace__` key, so the identifier, message and
stack file paths can be recovered by scraping printable runs out of it.

Stack *line numbers* are stored numerically and do not survive this. For
those, read the progress log: %LOCALAPPDATA%\\Temp\\housing-wages-logs\\<runId>.log
"""
import re
import sys

from scipy.io import loadmat

IDENTIFIER = re.compile(r"^[A-Za-z][\w-]*(:[\w-]+)+$")


def field(st, name):
    if st is None or st.dtype.names is None or name not in st.dtype.names:
        return "?"
    v = st[name][0, 0]
    return str(v[0]) if v.size else "?"


def subsystem_strings(mat):
    fw = mat.get("__function_workspace__")
    if fw is None:
        return []
    out, seen = [], set()
    for run in re.findall(rb"[\x20-\x7e]{6,}", fw.tobytes()):
        s = run.decode("ascii")
        if s not in seen:
            seen.add(s)
            out.append(s)
    return out


def report(path):
    mat = loadmat(path)
    run = mat.get("run")
    strings = subsystem_strings(mat)

    identifiers = [s for s in strings if IDENTIFIER.match(s) and "\\" not in s]
    messages = [s for s in strings if s.endswith(".") and " " in s and "\\" not in s]
    frames = [s for s in strings if s.endswith(".m")]
    matlabroot = [s for s in strings if re.match(r"^[A-Z]:\\.*MATLAB\\R20", s)]

    print("=" * 78)
    print(path)
    print(f"  runId      : {field(run, 'runId')}")
    print(f"  startedAt  : {field(run, 'startedAt')}")
    if matlabroot:
        print(f"  matlabroot : {matlabroot[0]}")
    print(f"  identifier : {', '.join(identifiers) or '<none found>'}")
    for m in messages:
        print(f"  message    : {m}")
    # Caveat: this list is every .m path in the subsystem, which includes the
    # source file of any function handle the dump happens to carry (geom.m,
    # via cfg's deg2px anonymous handle) as well as the real stack frames.
    print("  .m files referenced (stack frames + any stored function handles):")
    for f in frames:
        print(f"    {f}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for p in sys.argv[1:]:
        report(p)
