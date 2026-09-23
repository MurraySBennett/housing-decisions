<#
    deploy_to_share.ps1 -- copy the runnable code onto the OSU lab share; stopgap until git exists there.
    Never deletes, never touches Data or house_images.
    MachinePolicy AllSigned refuses -ExecutionPolicy Bypass -File, so pipe the text in; the share is reachable from Windows, not from WSL. From Windows PowerShell:
        $PS = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
        & $PS -NoProfile -Command "Invoke-Expression (Get-Content -Raw -LiteralPath '<this file>')"
    From WSL:
        PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
        $PS -NoProfile -Command "Invoke-Expression (Get-Content -Raw -LiteralPath '\\\\wsl.localhost\\Ubuntu\\home\\msb\\projects\\housing-decisions\\scripts\\deploy_to_share.ps1')"
#>

$ErrorActionPreference = 'Stop'

$SRC = '\\wsl.localhost\Ubuntu\home\msb\projects\housing-decisions'
$HW  = '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages'
$EXP = Join-Path $HW 'Experiment'
# Timestamped so a second deploy on the same day never collides.
$BK  = Join-Path $HW ('Archive\Experiment_pre-' + (Get-Date -Format 'yyyy-MM-dd_HHmmss'))

# Directories under Experiment\ that this script must never read or write.
$NEVER = @('Data', 'stimuli\house_images')

function Assert-Path($p, $what) {
    if (-not (Test-Path -LiteralPath $p)) { throw "$what not found: $p" }
}

Assert-Path $SRC 'Source repo'
Assert-Path $HW  'Share project directory'
Assert-Path $EXP 'Share Experiment directory'

Write-Host ''
Write-Host '=== PHASE 1: back up the current share Experiment tree ===' -ForegroundColor Cyan

if (Test-Path -LiteralPath $BK) {
    throw "Backup directory already exists, refusing to overwrite it:`n  $BK"
}
New-Item -ItemType Directory -Path $BK -Force | Out-Null

$backed = 0
Get-ChildItem -LiteralPath $EXP -Recurse -File -Force | ForEach-Object {
    $rel = $_.FullName.Substring($EXP.Length + 1)
    foreach ($skip in $NEVER) {
        if ($rel -eq $skip -or $rel.StartsWith("$skip\")) { return }
    }
    $dest = Join-Path $BK $rel
    $dir  = Split-Path $dest -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
    $backed++
}
Write-Host "  backed up $backed files to $BK"
Write-Host "  (Experiment\Data and Experiment\stimuli\house_images deliberately not backed up)"

Write-Host ''
Write-Host '=== PHASE 2: copy the manifest onto the share ===' -ForegroundColor Cyan

# Each entry: source path relative to $SRC, destination directory relative to $HW.
$manifest = @()

# -- experiment root. README-original.md is history, not a runnable file.
foreach ($f in @('run_battery.m', 'demo_battery.m', 'preflight.m',
                 'auction_task.m', 'continuous_DC_task.m',
                 'preference_task.m', 'README.md')) {
    $manifest += [pscustomobject]@{ From = "experiment\$f"; ToDir = 'Experiment' }
}

# -- +utils, enumerated from the repo so a new helper is never silently missed
Get-ChildItem -LiteralPath (Join-Path $SRC 'experiment\+utils') -File -Filter '*.m' |
    ForEach-Object {
        $manifest += [pscustomobject]@{ From = "experiment\+utils\$($_.Name)"; ToDir = 'Experiment\+utils' }
    }

# -- stimulus definition files. house_images is NOT here and never will be.
foreach ($f in @('README.md', 'prepare_stimuli.py', 'house_stimuli.csv',
                 'house_stimuli_list.csv', 'job_stimuli.csv')) {
    $manifest += [pscustomobject]@{ From = "experiment\stimuli\$f"; ToDir = 'Experiment\stimuli' }
}
foreach ($f in @('job_stimuli_synthetic.csv',   'job_stimuli_synthetic_provenance.json',
                 'job_stimuli_ecological.csv',  'job_stimuli_ecological_provenance.json',
                 'job_stimuli_attenuated.csv',  'job_stimuli_attenuated_provenance.json')) {
    $manifest += [pscustomobject]@{ From = "experiment\stimuli\prepared\$f"; ToDir = 'Experiment\stimuli\prepared' }
}
foreach ($f in @('jobs_synthetic.json', 'jobs_ecological.json', 'jobs_attenuated.json')) {
    $manifest += [pscustomobject]@{ From = "experiment\stimuli\stimgen\configs\$f"; ToDir = 'Experiment\stimuli\stimgen\configs' }
}
# window_check.py goes with prepare_stimuli.py.
$manifest += [pscustomobject]@{ From = 'experiment\stimuli\stimgen\window_check.py'; ToDir = 'Experiment\stimuli\stimgen' }

# -- R analysis
$manifest += [pscustomobject]@{ From = 'analysis\README.md'; ToDir = 'analysis' }
foreach ($f in @('io.R', 'plots.R', 'run_all.R', 'simulate_demo_data.R')) {
    $manifest += [pscustomobject]@{ From = "analysis\R\$f"; ToDir = 'analysis\R' }
}

$added = 0; $replaced = 0; $failed = @()

foreach ($item in $manifest) {
    $from = Join-Path $SRC $item.From
    if (-not (Test-Path -LiteralPath $from)) { $failed += "MISSING SOURCE: $($item.From)"; continue }

    $toDir = Join-Path $HW $item.ToDir
    if (-not (Test-Path -LiteralPath $toDir)) {
        New-Item -ItemType Directory -Path $toDir -Force | Out-Null
        Write-Host "  created directory $($item.ToDir)"
    }

    $name   = Split-Path $item.From -Leaf
    $to     = Join-Path $toDir $name
    $existed = Test-Path -LiteralPath $to

    Copy-Item -LiteralPath $from -Destination $to -Force

    # Verify rather than trust: sizes must match after the copy.
    $sFrom = (Get-Item -LiteralPath $from).Length
    $sTo   = (Get-Item -LiteralPath $to).Length
    if ($sFrom -ne $sTo) { $failed += "SIZE MISMATCH: $($item.From) ($sFrom vs $sTo)"; continue }

    if ($existed) { $replaced++ } else { $added++; Write-Host "  new: $($item.ToDir)\$name" }
}

Write-Host ''
Write-Host '=== RESULT ===' -ForegroundColor Cyan
Write-Host "  replaced : $replaced"
Write-Host "  added    : $added"
Write-Host "  backup   : $BK"
if ($failed.Count -gt 0) {
    Write-Host '  PROBLEMS:' -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    exit 1
}
Write-Host '  no problems' -ForegroundColor Green
Write-Host ''
