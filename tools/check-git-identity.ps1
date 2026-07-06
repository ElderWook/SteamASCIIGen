# Git identity history check (OGDK). Scans author + committer name/email across
# ALL commit objects in history against the gitignored tools/PRIVATE-MARKERS.list
# and FAILS if any marker appears. This closes the gap content scans cannot see:
# check-kit-docs (check 8) scans tracked FILE CONTENT, but author/committer metadata
# travels in every commit object and is invisible to it (the "personal email leaked
# via commit author identity" lesson). Output reports marker INDEX only, never text.
# Graceful skip (exit 0) when git or the markers list is absent. Twin: check-git-identity.sh.
$ErrorActionPreference = 'Continue'
$kit = Split-Path -Parent $PSScriptRoot
Set-Location $kit
$issues = 0

if (-not $env:OGDK_BANNER) {
    Write-Host '   ___   ____ ____  _  __' -ForegroundColor Cyan
    Write-Host '  / _ \ / ___|  _ \| |/ /' -ForegroundColor Cyan
    Write-Host ' | | | | |  _| | | | '' /' -ForegroundColor Cyan
    Write-Host ' | |_| | |_| | |_| | . \' -ForegroundColor Cyan
    Write-Host '  \___/ \____|____/|_|\_\' -ForegroundColor Cyan
}
Write-Host '======================================' -ForegroundColor Cyan
Write-Host '  Git Identity History Check (OGDK)   ' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan

# Preconditions: git present and inside a work tree. Skip (not fail) otherwise so
# fresh clones / non-git copies do not block on a check they cannot run.
$gitPath = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $gitPath) {
    Write-Host '[WARN] git not found - identity history scan skipped' -ForegroundColor Yellow
    exit 0
}
$null = git rev-parse --git-dir 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host '[WARN] not a git repo - identity history scan skipped' -ForegroundColor Yellow
    exit 0
}

# Markers: gitignored, per-owner. Absent = skip (same posture as check-kit-docs 8).
$markFile = 'tools/PRIVATE-MARKERS.list'
if (-not (Test-Path $markFile)) {
    Write-Host '[WARN] tools/PRIVATE-MARKERS.list not found - identity scan skipped (seed yours: see tools/README.md)' -ForegroundColor Yellow
    exit 0
}
$markers = @()
foreach ($line in (Get-Content $markFile -Encoding UTF8)) {
    $t = $line.Trim()
    if ($t -ne '' -and -not $t.StartsWith('#')) { $markers += $t.ToLower() }
}
if ($markers.Count -eq 0) {
    Write-Host '[WARN] PRIVATE-MARKERS.list has no markers - identity scan skipped' -ForegroundColor Yellow
    exit 0
}

# One line per commit across ALL refs: <shorthash>|<author name>|<author email>|<committer name>|<committer email>.
# Emails/names never contain '|', so split on the first '|' isolates the hash; the
# remainder is the identity blob we scan. --all covers every local ref, not just HEAD.
$identOk = $true
$commitCount = 0
$log = git log --all --format='%h|%an|%ae|%cn|%cE' 2>$null
foreach ($entry in $log) {
    if (-not $entry) { continue }
    $commitCount++
    $sep = $entry.IndexOf('|')
    if ($sep -lt 0) { continue }
    $hash = $entry.Substring(0, $sep)
    $blob = $entry.Substring($sep + 1).ToLower()
    $mIdx = 0
    foreach ($m in $markers) {
        $mIdx++
        if ($blob.Contains($m)) {
            Write-Host "[FAIL] commit $hash author/committer identity contains private marker #$mIdx (text withheld - marker #$mIdx in your PRIVATE-MARKERS.list)" -ForegroundColor Red
            $issues++; $identOk = $false
            break
        }
    }
}
if ($identOk) {
    Write-Host "[PASS] no private markers in author/committer identity ($commitCount commit(s), $($markers.Count) marker(s) checked)" -ForegroundColor Green
}

Write-Host '--------------------------------------' -ForegroundColor Cyan
if ($issues -eq 0) {
    Write-Host '  GIT IDENTITY OK' -ForegroundColor Green
} else {
    Write-Host "  $issues COMMIT(S) WITH LEAKED IDENTITY" -ForegroundColor Red
    Write-Host '  Rewrite author/committer metadata before pushing to a public remote.' -ForegroundColor Yellow
    Write-Host '  (git rebase --committer-date-is-author-date / filter-repo --mailmap; re-tag; force-push in an unlinked window.)' -ForegroundColor Yellow
}
Write-Host '--------------------------------------' -ForegroundColor Cyan
exit $issues
