#!/usr/bin/env python3
"""Guard MATLAB functiontests discovery, even on machines without MATLAB."""
import pathlib
import re
import sys
root = pathlib.Path(__file__).resolve().parent / 'tests'
count = 0
errors = []
for path in sorted(root.glob('test_*.m')):
    for name in re.findall(r'^function\s+(\w+)\(testCase\)', path.read_text(), re.M):
        if name in {'setup', 'teardown', 'setupOnce', 'teardownOnce'}:
            continue
        count += 1
        if not (name.lower().startswith('test') or name.lower().endswith('test')):
            errors.append(f'{path.name}: undiscoverable case {name}')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
# A floor, not an equality. An exact count means every added test case is a
# two-file edit, and forgetting either turns the suite red for everyone but the
# author -- which is exactly how 136a3f2 broke the rig check. Adding coverage
# must never break the rig; raise this deliberately when cases are removed.
MINIMUM = 52
assert count >= MINIMUM, f'Found {count} checkpoint tests, expected at least {MINIMUM}; a test case was removed or stopped being discoverable.'
print(f'{count} MATLAB cases follow functiontests naming; runtime discovery still requires MATLAB.')
