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
assert count == 38, f'Found {count} checkpoint tests; update the explicit runner count from 38 if intentionally changed.'
print(f'{count} MATLAB cases follow functiontests naming; runtime discovery still requires MATLAB.')
