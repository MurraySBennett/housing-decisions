<#
    move_out_of_tree.ps1 -- move participant data and the house image set
    out of housing_wages\, so that making housing_wages\ a git working tree
    cannot put them at risk.

    WHY. Both directories are gitignored and both live inside what is about
    to become a git checkout. `git clean -fdx` removes ignored files -- that
    is the entire point of -x -- and it is the command anyone reaches for to
    reset a working tree. On that tree it deletes every participant, and git
    raises no objection, because they were ignored on purpose. The deploy
    script's Archive backups deliberately exclude both, so there is no
    second copy.

        FROM  housing_wages\Experiment\Data
              housing_wages\Experiment\stimuli\house_images
        TO    housing_wages_local\Data
              housing_wages_local\house_images

    cfg.paths.local in +utils/config.m already points at the destination.
    Run this BEFORE converting the share to a checkout, and before the next
    session -- MATLAB will look in the new place either way.

    SAFETY PROPERTIES:
      - Refuses to run if a destination already exists. It will not merge
        into, or write over, an existing directory.
      - Counts files and bytes BEFORE, moves, then counts again and
        compares. A mismatch is reported as a failure, loudly.
      - Move-Item within one volume is a rename: near-instant even for the
        605MB image set, and it never leaves a half-copied state.
      - Nothing is deleted. There is no Remove-Item anywhere in this file.
      - Idempotent: if the move is already done it says so and exits 0.

    Run from Windows PowerShell:

        $PS = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
        & $PS -NoProfile -Command "Invoke-Expression (Get-Content -Raw -LiteralPath '<this file>')"
#>

$ErrorActionPreference = 'Stop'

$HW    = '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages'
$LOCAL = '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages_local'

$moves = @(
    [pscustomobject]@{ Name = 'participant data'
                       From = (Join-Path $HW 'Experiment\Data')
                       To   = (Join-Path $LOCAL 'Data') },
    [pscustomobject]@{ Name = 'house image set'
                       From = (Join-Path $HW 'Experiment\stimuli\house_images')
                       To   = (Join-Path $LOCAL 'house_images') }
)

function Measure-Tree($path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $f = Get-ChildItem -LiteralPath $path -Recurse -File -Force
    $sum = ($f | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    return [pscustomobject]@{ Count = $f.Count; Bytes = $sum }
}

Write-Host ''
Write-Host '=== move out of the git working tree ===' -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $LOCAL)) {
    New-Item -ItemType Directory -Path $LOCAL -Force | Out-Null
    Write-Host "  created $LOCAL"
}

$problems = @()
$didWork = $false

foreach ($m in $moves) {
    Write-Host ''
    Write-Host ("-- {0}" -f $m.Name)

    $srcExists = Test-Path -LiteralPath $m.From
    $dstExists = Test-Path -LiteralPath $m.To

    if (-not $srcExists -and $dstExists) {
        Write-Host "   already moved: $($m.To)" -ForegroundColor Green
        continue
    }
    if (-not $srcExists -and -not $dstExists) {
        $problems += "$($m.Name): neither source nor destination exists. Source was $($m.From)"
        continue
    }
    if ($srcExists -and $dstExists) {
        $problems += "$($m.Name): BOTH exist. Refusing to merge. Resolve by hand:`n     src $($m.From)`n     dst $($m.To)"
        continue
    }

    $before = Measure-Tree $m.From
    Write-Host ("   before : {0:N0} files, {1:N1} MB" -f $before.Count, ($before.Bytes/1MB))
    Write-Host ("   from   : {0}" -f $m.From)
    Write-Host ("   to     : {0}" -f $m.To)

    Move-Item -LiteralPath $m.From -Destination $m.To
    $didWork = $true

    $after = Measure-Tree $m.To
    if ($null -eq $after) {
        $problems += "$($m.Name): destination missing after the move"
        continue
    }
    Write-Host ("   after  : {0:N0} files, {1:N1} MB" -f $after.Count, ($after.Bytes/1MB))

    if ($after.Count -ne $before.Count -or $after.Bytes -ne $before.Bytes) {
        $problems += ("$($m.Name): MISMATCH after move -- {0} files/{1} bytes before, {2}/{3} after" -f `
                      $before.Count, $before.Bytes, $after.Count, $after.Bytes)
    } else {
        Write-Host '   verified: file count and total bytes match' -ForegroundColor Green
    }
}

Write-Host ''
Write-Host '=== RESULT ===' -ForegroundColor Cyan
if ($problems.Count -gt 0) {
    Write-Host '  PROBLEMS:' -ForegroundColor Red
    $problems | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    exit 1
}
if ($didWork) {
    Write-Host '  moved and verified. housing_wages\ is now safe to make a checkout.' -ForegroundColor Green
} else {
    Write-Host '  nothing to do -- already moved.' -ForegroundColor Green
}
Write-Host ''
Write-Host '  Next: run utils.verifyPaths(utils.config(''rig'',''lab'')) in MATLAB'
Write-Host '  and confirm paths.local, paths.images and paths.data all read OK.'
Write-Host ''
