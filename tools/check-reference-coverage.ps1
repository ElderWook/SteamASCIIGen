# Reference coverage check (OGDK) - makes the documentation graduation rule mechanical.
# Reads docs/reference/COVERAGE.md and verifies pages exist + staleness vs git history.
# Twin: check-reference-coverage.sh (keep behavior identical).
$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
$manifest = 'docs/reference/COVERAGE.md'
$issues = 0; $backlog = 0; $stale = 0

if (-not $env:OGDK_BANNER) {
    Write-Host '   ___   ____ ____  _  __' -ForegroundColor Cyan
    Write-Host '  / _ \ / ___|  _ \| |/ /' -ForegroundColor Cyan
    Write-Host ' | | | | |  _| | | | '' /' -ForegroundColor Cyan
    Write-Host ' | |_| | |_| | |_| | . \' -ForegroundColor Cyan
    Write-Host '  \___/ \____|____/|_|\_\' -ForegroundColor Cyan
}
Write-Host '======================================' -ForegroundColor Cyan
Write-Host '  Reference Coverage Check (OGDK)     ' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan

if (-not (Test-Path $manifest)) {
    Write-Host "[FAIL] no $manifest - reference tier not initialized" -ForegroundColor Red
    exit 1
}
git rev-parse --git-dir 2>&1 | Out-Null
$haveGit = ($LASTEXITCODE -eq 0)
if (-not $haveGit) { Write-Host '[WARN] not a git repo - staleness checks skipped' -ForegroundColor Yellow }

function Get-LastCommitTime([string]$p) {
    $t = git log -1 --format=%ct -- $p 2>$null
    if ($t) { return [long]$t } else { return 0 }
}

foreach ($line in (Get-Content $manifest -Encoding UTF8)) {
    if ($line -notmatch '^\|') { continue }
    $cells = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
    if ($cells.Count -lt 4) { continue }
    $comp = $cells[0]; $src = $cells[1]; $page = $cells[2]; $status = $cells[3].ToLower()
    if ($comp -eq '' -or $comp -eq 'Component' -or $comp -like '_none*' -or $comp -like ':---*' -or $comp -like '---*') { continue }
    # status may carry a trailing note, e.g. "planned (spec ahead)"; match the leading
    # keyword only so a human annotation doesn't hard-fail the gate (2026-06-22 lesson).
    $statusKw = if ($status -match '^([a-z]+)') { $matches[1] } else { $status }
    if ($statusKw -eq 'planned') { continue }
    if ($statusKw -eq 'missing') {
        $backlog++
        continue
    }
    if ($statusKw -ne 'current' -and $statusKw -ne 'stale') {
        Write-Host "[FAIL] ${comp}: unknown status '$status' in COVERAGE.md" -ForegroundColor Red
        $issues++; continue
    }
    $pageFile = "docs/reference/$page"
    if (-not (Test-Path $pageFile)) {
        Write-Host "[FAIL] ${comp}: page $page listed as $status but file does not exist" -ForegroundColor Red
        $issues++; continue
    }
    if ($haveGit) {
        $pageTs = Get-LastCommitTime $pageFile
        $srcTs = 0
        foreach ($sp in $src.Split(';')) {
            $sp = $sp.Trim(); if ($sp -eq '') { continue }
            $t = Get-LastCommitTime $sp
            if ($t -gt $srcTs) { $srcTs = $t }
        }
        if ($srcTs -gt $pageTs -and $pageTs -ne 0) {
            $stale++
            Write-Host "[WARN] STALE: $comp - source committed after page $page (update page or justify)" -ForegroundColor Yellow
        } else {
            Write-Host "[PASS] $comp -> $page" -ForegroundColor Green
        }
    } else {
        Write-Host "[PASS] $comp -> $page (existence only)" -ForegroundColor Green
    }
}

if ($backlog -gt 0) {
    Write-Host "[WARN] backlog: $backlog component(s) lack reference pages - see docs/reference/COVERAGE.md" -ForegroundColor Yellow
}
# Learning-loop nudge: count OPEN lessons (the kit-retro trigger, now mechanical)
if (Test-Path 'docs/LESSONS.md') {
    $openLessons = @(Get-Content 'docs/LESSONS.md' -Encoding UTF8 | Where-Object { $_ -cmatch 'Status:.*OPEN' }).Count
    if ($openLessons -ge 5) {
        Write-Host "[WARN] $openLessons OPEN lesson(s) in docs/LESSONS.md - run the kit-retro skill (threshold: 5)" -ForegroundColor Yellow
    } elseif ($openLessons -gt 0) {
        Write-Host "[INFO] $openLessons OPEN lesson(s) in docs/LESSONS.md (kit-retro at 5)" -ForegroundColor Cyan
    }
}

# Handoff freshness: STATUS.md trailing HEAD by >3 days means sessions are
# committing without updating the handoff (session-end step 5 skipped)
if ($haveGit -and (Test-Path 'docs/STATUS.md')) {
    $statusTs = Get-LastCommitTime 'docs/STATUS.md'
    $tHead = git log -1 --format=%ct 2>$null
    $headTs = 0; if ($tHead) { $headTs = [long]$tHead }
    if ($statusTs -ne 0 -and $headTs -ne 0 -and ($headTs - $statusTs) -gt 259200) {
        Write-Host '[WARN] docs/STATUS.md last committed >3 days before HEAD - handoff may be stale (session-end step 5)' -ForegroundColor Yellow
    }
}

Write-Host '--------------------------------------' -ForegroundColor Cyan
Write-Host "  backlog (missing pages): $backlog   stale: $stale   hard issues: $issues"
if ($issues -eq 0) {
    $suffix = ''
    if (($backlog + $stale) -gt 0) { $suffix = ' (with warnings - see above)' }
    Write-Host "  COVERAGE OK$suffix" -ForegroundColor Green
} else {
    Write-Host '  FIX COVERAGE before archiving any plan' -ForegroundColor Red
}
exit $issues
