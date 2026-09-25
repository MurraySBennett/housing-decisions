<#
    pull_data_from_share.ps1 -- copy lab data from the share into git-ignored data\lab\..., then run the R analysis.
    Never deletes; overwrites same-path files and writes a fresh pull manifest.
    Run from WSL; pipe the script text in because machine policy can reject unsigned -File execution:
      PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
      $PS -NoProfile -Command "Invoke-Expression (Get-Content -Raw -LiteralPath '\\wsl.localhost\Ubuntu\home\msb\projects\housing-decisions\scripts\pull_data_from_share.ps1')"
#>

param(
    [string]$SourceData = '',
    [string]$RepoWin = '\\wsl.localhost\Ubuntu\home\msb\projects\housing-decisions',
    [string]$RepoLinux = '/home/msb/projects/housing-decisions',
    [string]$RscriptLinux = '/home/msb/.nix-profile/bin/Rscript',
    [switch]$Practice,
    [switch]$IncludePractice,
    [switch]$AnalysisOnly,
    [switch]$SkipAnalysis
)

$ErrorActionPreference = 'Stop'

$runKind = if ($Practice) { 'practice' } else { 'participant' }
if ([string]::IsNullOrWhiteSpace($SourceData)) {
    if ($Practice) {
        $SourceData = '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment\Data_practice'
    } else {
        $SourceData = '\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\Experiment\Data'
    }
}

$localRoot = Join-Path $RepoWin 'data\lab'
$targetName = if ($Practice) { 'Data_practice' } else { 'Data' }
$targetData = Join-Path $localRoot $targetName
$manifestDir = Join-Path $localRoot 'manifests'
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$manifest = Join-Path $manifestDir "pull_$stamp.csv"

function Assert-Path($p, $what) {
    if (-not (Test-Path -LiteralPath $p)) { throw "$what not found: $p" }
}

Assert-Path $RepoWin 'WSL repo'

New-Item -ItemType Directory -Path $targetData -Force | Out-Null
New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null

if ($AnalysisOnly) {
    Assert-Path $targetData 'Local pulled data directory'
    Write-Host ''
    Write-Host '=== PHASE 1: copy lab data locally ===' -ForegroundColor Cyan
    Write-Host '  skipped: -AnalysisOnly'
} else {
    Assert-Path $SourceData 'Share data directory'

    Write-Host ''
    Write-Host '=== PHASE 1: copy lab data locally ===' -ForegroundColor Cyan
    Write-Host "  kind:   $runKind"
    Write-Host "  source: $SourceData"
    Write-Host "  target: $targetData"

    $copied = 0
    $bytes = [int64]0
    $records = New-Object System.Collections.Generic.List[object]

    Get-ChildItem -LiteralPath $SourceData -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($SourceData.Length + 1)
        $dest = Join-Path $targetData $rel
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force

        $srcLen = $_.Length
        $dst = Get-Item -LiteralPath $dest
        if ($dst.Length -ne $srcLen) {
            throw "Size mismatch after copy: $rel ($srcLen vs $($dst.Length))"
        }

        $copied++
        $bytes += $srcLen
        $records.Add([pscustomobject]@{
            relative_path = $rel
            run_kind = $runKind
            bytes = $srcLen
            source_last_write_utc = $_.LastWriteTimeUtc.ToString('s')
            pulled_at = (Get-Date).ToString('s')
        })
    }

    $records | Sort-Object relative_path | Export-Csv -LiteralPath $manifest -NoTypeInformation

    Write-Host "  copied:   $copied files"
    Write-Host ("  bytes:    {0:N0}" -f $bytes)
    Write-Host "  manifest: $manifest"
}

if ($SkipAnalysis) {
    Write-Host ''
    Write-Host '=== RESULT ===' -ForegroundColor Cyan
    Write-Host '  analysis skipped'
    Write-Host '  no problems' -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host '=== PHASE 2: run analysis/R/run_all.R ===' -ForegroundColor Cyan

$analysisArgs = @(
    '-d', 'Ubuntu',
    '--cd', $RepoLinux,
    '--',
    $RscriptLinux, 'analysis/R/00_participant_qc.R',
    '--data', "data/lab/$targetName",
    '--out', 'analysis/output/lab'
)
if ($IncludePractice -or $Practice) {
    $analysisArgs += '--include-practice'
}

& wsl.exe @analysisArgs
if ($LASTEXITCODE -ne 0) {
    throw "R analysis failed with exit code $LASTEXITCODE"
}

Write-Host ''
Write-Host '=== RESULT ===' -ForegroundColor Cyan
Write-Host "  data ready:      data/lab/$targetName"
Write-Host '  analysis output: analysis/output/lab'
Write-Host '  no problems' -ForegroundColor Green
