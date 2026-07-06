# OGDK - RESCUE. The symmetric twin of checkpoint: checkpoint SAVES, rescue RESTORES.
# One command to get back to your last safe save without ever losing work:
#   - a half-finished merge/rebase -> cancelled (returns to the last commit)
#   - uncommitted changes          -> safely shelved (git stash), tree returns to HEAD
#   - already clean                -> nothing to do
# It NEVER force-pushes, NEVER resets --hard, NEVER deletes commits. Run it from a
# native shell when things feel tangled and you just want to be safe again.
# Twin: rescue.sh.
#
# Usage: .\tools\rescue.ps1
$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host '======================================' -ForegroundColor Cyan
Write-Host '  RESCUE - get back to safe (OGDK)    ' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan

$gitDir = git rev-parse --git-dir 2>$null
if ($LASTEXITCODE -ne 0 -or -not $gitDir) { Write-Host '[FAIL] not a git repository' -ForegroundColor Red; exit 1 }

# 1. A merge or rebase mid-flight is the scariest state for a beginner. Aborting it
#    returns the working tree to the last committed state - no committed work is lost.
if (Test-Path (Join-Path $gitDir 'MERGE_HEAD')) {
    git merge --abort 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '[OK] cancelled the in-progress merge - you are back at your last commit, safe.' -ForegroundColor Green
    } else {
        Write-Host "[WARN] could not auto-cancel the merge. Run 'git merge --abort' yourself, or ask a human." -ForegroundColor Yellow
        exit 1
    }
    Write-Host '--------------------------------------' -ForegroundColor Cyan; Write-Host '  RESCUE DONE' -ForegroundColor Green; exit 0
}
if ((Test-Path (Join-Path $gitDir 'rebase-merge')) -or (Test-Path (Join-Path $gitDir 'rebase-apply'))) {
    git rebase --abort 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '[OK] cancelled the in-progress rebase - you are back at your last commit, safe.' -ForegroundColor Green
    } else {
        Write-Host "[WARN] could not auto-cancel the rebase. Run 'git rebase --abort' yourself, or ask a human." -ForegroundColor Yellow
        exit 1
    }
    Write-Host '--------------------------------------' -ForegroundColor Cyan; Write-Host '  RESCUE DONE' -ForegroundColor Green; exit 0
}

# 2. Uncommitted changes: shelve them (tracked AND untracked) so the tree is clean at
#    your last save, but NOTHING is thrown away - stash is fully recoverable.
$dirty = [bool](git status --porcelain 2>$null)
if ($dirty) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    git stash push --include-untracked -m "rescue $stamp" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '[OK] your in-progress changes are safely shelved (nothing was deleted).' -ForegroundColor Green
        Write-Host '     Your project is now back at your last save:'
        Write-Host "       $(git log -1 --format='%h %s' 2>$null)"
        Write-Host ''
        Write-Host '     Bring the shelved work back any time:   git stash pop'
        Write-Host '     See everything you have shelved:        git stash list'
    } else {
        Write-Host "[WARN] could not shelve changes. Run 'git status' and read it, or ask a human." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host '[PASS] nothing to rescue - your project is already clean at a save point:' -ForegroundColor Green
    Write-Host "       $(git log -1 --format='%h %s' 2>$null)"
}

Write-Host '--------------------------------------' -ForegroundColor Cyan
Write-Host '  RESCUE DONE' -ForegroundColor Green
exit 0
