# OGDK - PANIC SAVE. One command, zero questions: stage everything, commit as a
# 'wip:' checkpoint, push. Designed for interruptions - phone rings, battery
# dies, usage limit hits, you have to leave NOW.
# A LOCAL commit is already a successful save: if the push fails (offline,
# remote moved), your work is safe and sync-repo sorts it out next session.
# Twin: checkpoint.sh. Double-click shim: checkpoint.bat (same folder).
#
# Usage: .\tools\checkpoint.ps1 ["what I was doing"]
param([string]$Message = '')
$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host '======================================' -ForegroundColor Cyan
Write-Host '  CHECKPOINT - panic save (OGDK)      ' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan

git rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host '[FAIL] not a git repository' -ForegroundColor Red; exit 1 }

$dirty = [bool](git status --porcelain 2>$null)
if (-not $dirty) {
    $ahead = 0
    $a = git rev-list --count '@{upstream}..HEAD' 2>$null
    if ($LASTEXITCODE -eq 0 -and $a) { $ahead = [int]$a }
    if ($ahead -gt 0) {
        Write-Host "[INFO] nothing new to commit, but $ahead commit(s) unpushed - pushing those." -ForegroundColor Cyan
    } else {
        Write-Host "[PASS] nothing to save - tree clean and pushed. You're free." -ForegroundColor Green
        exit 0
    }
} else {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $subject = "wip: checkpoint $stamp"
    if ($Message -ne '') { $subject = "$subject - $Message" }
    git add -A
    # Panic save: bypass the pre-commit cheap-integrity gate (a half-broken tree
    # must still be savable). The privacy scan in the hook always runs regardless.
    $env:OGDK_SKIP_INTEGRITY = '1'
    git commit -m $subject 2>$null | Out-Null
    $commitCode = $LASTEXITCODE
    Remove-Item Env:\OGDK_SKIP_INTEGRITY -ErrorAction SilentlyContinue
    if ($commitCode -eq 0) {
        Write-Host "[PASS] committed locally: $subject" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] commit failed - run 'git status' and read it" -ForegroundColor Red; exit 1
    }
}

git push 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host '[PASS] pushed - work is safe on the remote. Go.' -ForegroundColor Green
} else {
    Write-Host '[WARN] push did not go through (offline, or the remote moved ahead).' -ForegroundColor Yellow
    Write-Host '       YOUR WORK IS SAFE - it is committed locally. Next session,'
    Write-Host '       run .\tools\sync-repo.ps1 and it will walk you through syncing.'
}
Write-Host '--------------------------------------' -ForegroundColor Cyan
Write-Host '  CHECKPOINT DONE' -ForegroundColor Green
exit 0
