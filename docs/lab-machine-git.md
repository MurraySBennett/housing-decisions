# Lab machine Git workflow

GitHub is the code update path. The shared drive is still where the study saves data and finds the
house images.

## Student workflow

This is all an RA should need during a session:

1. Open GitHub Desktop.
2. Click **Fetch origin**. If it changes to **Pull origin**, click that too.
3. If GitHub Desktop shows changed files, stop and ask Murray before running.
4. Open MATLAB from the local clone's `experiment/` folder.
5. In `run_battery.m`, leave `RUN_KIND = 'participant'` for real participants.
6. Click Run.

For RA/practice runs only:

```matlab
RUN_KIND = 'practice';
```

Do not clone into or edit code under:

```text
\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages
```

That shared-drive folder is for data, images, and older share-side history, not the working code
checkout.

## One-time setup

Do this once per lab computer, not before every session:

1. Install Git and GitHub Desktop.
2. Sign into GitHub Desktop with a named GitHub account that has repo access.
3. Clone the repo to a local folder, for example:

```text
C:\Users\<lab-user>\Documents\GitHub\housing-decisions
```

4. In MATLAB, add the clone's `experiment/` directory to the path.
5. Run:

```matlab
utils.verifyPaths(utils.config('rig','lab'))
```

The code and stimulus CSVs should resolve inside the clone. Data, images, and the Tobii SDK should
resolve to the shared-drive roots below.

## System shape

Every machine gets a normal clone of the GitHub repo. The clone should look like the repo:

```
housing-decisions/
  experiment/
  analysis/
  docs/
  scripts/
  WORK.md
```

Large/runtime material lives outside the checkout:

| material            | default OSU share location                                                                         | git?  |
| ------------------- | -------------------------------------------------------------------------------------------------- | ----- |
| House images        | `\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment\stimuli\house_images` | no    |
| Participant data    | `\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment\Data`                 | never |
| Practice/staff data | `\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment\Data_practice`        | never |
| Tobii SDK           | `\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\TobiiPro.SDK.Matlab_1.9.0.59`                  | no    |

Those defaults are already built into `utils.config`. Override them only if a
machine has a nonstandard local copy:

```powershell
setx HW_ASSET_ROOT "\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment\stimuli\house_images"
setx HW_DATA_ROOT "\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment\Data"
setx HW_PRACTICE_DATA_ROOT "\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment\Data_practice"
setx HW_TOBII_ROOT "\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\TobiiPro.SDK.Matlab_1.9.0.59"
```

Restart MATLAB after changing environment variables.

## Pushing changes

Push only code, docs, configs, and tracked stimulus-definition files. Never commit participant data, practice data, gaze files, house images, generated analysis output, or MATLAB `.mat` run files.

If GitHub Desktop shows data or generated files as changes, stop and fix the path/ignore issue
before committing. A clean clone should stay clean after a session except for deliberate code/doc
edits.

## Analysis data snapshots

`scripts/pull_data_from_share.ps1` is still useful, but only for pulling data from the share into
ignored local `data/lab/...` analysis snapshots. It is not a deployment script.

Participant data:

```powershell
$PS = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
& $PS -NoProfile -Command '$script = [scriptblock]::Create((Get-Content -Raw -LiteralPath "\\wsl.localhost\Ubuntu\home\msb\projects\housing-decisions\scripts\pull_data_from_share.ps1")); & $script'
```

Practice data:

```powershell
$PS = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
& $PS -NoProfile -Command '$script = [scriptblock]::Create((Get-Content -Raw -LiteralPath "\\wsl.localhost\Ubuntu\home\msb\projects\housing-decisions\scripts\pull_data_from_share.ps1")); & $script -Practice'
```

## Known rough edges

- GitHub Desktop credentials are per named account. Sign out on shared machines when appropriate.
- Git over the network share can be slow; clone to the lab computer when possible.
- `Experiment\Data` and `Experiment\Data_practice` on the share are storage locations, not a second
  code copy to edit.
