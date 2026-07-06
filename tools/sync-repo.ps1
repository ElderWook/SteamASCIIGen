# OGDK - safe arrival protocol. Run at SESSION START before any work.
# Classifies the repo's relationship to its remote and either fast-forwards
# (the only conflict-impossible auto-action) or STOPS with plain-language
# instructions. It NEVER auto-merges and NEVER creates a conflict state.
# Twin: sync-repo.sh.
#
# Exit codes: 0 = safe to work ; 2 = action required before working.
$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Pass([string]$m) { Write-Host "[PASS] $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Info([string]$m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Stop2([string]$m) { Write-Host "[STOP] $m" -ForegroundColor Red }
function Note([string]$m) { Write-Host "       $m" }

if (-not $env:OGDK_BANNER) {
    Write-Host '   ___   ____ ____  _  __' -ForegroundColor Cyan
    Write-Host '  / _ \ / ___|  _ \| |/ /' -ForegroundColor Cyan
    Write-Host ' | | | | |  _| | | | '' /' -ForegroundColor Cyan
    Write-Host ' | |_| | |_| | |_| | . \' -ForegroundColor Cyan
    Write-Host '  \___/ \____|____/|_|\_\' -ForegroundColor Cyan
}
Write-Host '======================================' -ForegroundColor Cyan
Write-Host '  Sync Check - safe arrival (OGDK)    ' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan

# Guard: never run git through a synced/cloud folder (AI-PARITY SS4). The .sh twin
# refuses on a sandbox/WSL mount path; the Windows hazard is a OneDrive/Dropbox/
# Google Drive folder, a mapped network drive, or a UNC path - git there can rewrite
# the index from a stale, eventually-consistent view. Work from a native local clone.
$mountHazard = ''
if ($repoRoot -match '^\\\\') {
    $mountHazard = "a UNC network path ($repoRoot)"
} elseif ($repoRoot -match '(?i)[\\/](OneDrive|Dropbox|Google Drive|My Drive)([\\/]|$)') {
    $mountHazard = "a cloud-synced folder ($repoRoot)"
}
if ($mountHazard) {
    Stop2 "this repo is in $mountHazard - git must run from a NATIVE local clone only (e.g. C:\Dev\OGDK), never a synced/cloud folder. Move the clone to a normal disk path, or hand this to a human."
    exit 2
}

$gitDir = git rev-parse --git-dir 2>$null
if ($LASTEXITCODE -ne 0 -or -not $gitDir) { Stop2 'not a git repository'; exit 2 }

# 0. A merge/rebase is already in progress - do not dig deeper.
if (Test-Path (Join-Path $gitDir 'MERGE_HEAD')) {
    Stop2 "a MERGE is in progress (probably from an earlier 'git pull')."
    Note "Finish it:  resolve files 'git status' lists, then 'git add <file>' + 'git commit'"
    Note "Or undo it: git merge --abort   (returns to the state before the pull)"
    Note "Kit-files rule: a conflict in tools/* on a propagated file is NOT a real"
    Note "merge - take either side, then re-run propagate-tools from the kit."
    exit 2
}
if ((Test-Path (Join-Path $gitDir 'rebase-merge')) -or (Test-Path (Join-Path $gitDir 'rebase-apply'))) {
    Stop2 "a REBASE is in progress. Finish: 'git rebase --continue' - or undo: 'git rebase --abort'."
    exit 2
}

# 1. Fetch - pure information, mutates nothing.
git fetch --quiet 2>$null
if ($LASTEXITCODE -ne 0) {
    Warn 'could not reach the remote (offline? auth?). Working with local state only - re-run when connected.'
    exit 0
}

# 2. Upstream?
git rev-parse --abbrev-ref '@{upstream}' 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Warn 'current branch has no upstream - nothing to sync against (set one: git push -u origin <branch>).'
    exit 0
}

$dirty = [bool](git status --porcelain 2>$null)
$counts = git rev-list --left-right --count 'HEAD...@{upstream}' 2>$null
$ahead = 0; $behind = 0
if ($counts) {
    $parts = -split $counts
    if ($parts.Count -ge 2) { $ahead = [int]$parts[0]; $behind = [int]$parts[1] }
}

# 3. Classify - worst states first.
if ($ahead -gt 0 -and $behind -gt 0) {
    Stop2 "DIVERGED: this machine and the remote each have commits the other lacks ($ahead local, $behind remote)."
    Note 'This happens when two machines commit without pulling first.'
    Note 'Option A (usual):  git pull --no-rebase   - merges; if it conflicts, see the kit-files rule'
    Note 'Option B (linear): git pull --rebase      - replays your commits on top'
    Note "(plain 'git pull' on modern git refuses divergent branches until you pick one)"
    Note 'Kit-files rule: conflicts in tools/* on propagated files are not real merges -'
    Note "take either side ('git checkout --ours <file>', 'git add <file>'), finish the"
    Note 'merge, then re-run propagate-tools from the kit. The kit is the source of truth.'
    exit 2
}
if ($dirty -and $behind -gt 0) {
    Stop2 "uncommitted changes AND the remote is $behind commit(s) ahead. Pulling now risks tangling them."
    Note "First:  git add -A; git commit -m 'wip: <what you were doing>'   (or .\tools\checkpoint.ps1)"
    Note 'Then re-run this script - it will fast-forward cleanly.'
    exit 2
}
if ($behind -gt 0) {
    git merge --ff-only '@{upstream}' 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Pass "fast-forwarded $behind commit(s) from the remote - you are current"
    } else {
        Stop2 "fast-forward unexpectedly failed - run 'git status' and read it; do not force anything."
        exit 2
    }
} else {
    Pass 'no new remote commits'
}
if ($ahead -gt 0) {
    Info "$ahead local commit(s) not pushed yet - 'git push' when ready (or at session end)"
}
if ($dirty) {
    Warn 'uncommitted changes present. If YOU just made them: fine, carry on. If you did NOT'
    Note 'expect them: a previous session may have been interrupted - check docs/STATUS.md'
    Note "for an '## In-flight' section before touching anything (session-start step 5)."
}
$lastSubject = git log -1 --format='%s' 2>$null
if ($lastSubject -like 'wip:*') {
    Warn "last commit is a 'wip:' checkpoint - a previous session ended mid-task."
    Note 'Reconstruct from: git show --stat HEAD + docs/STATUS.md In-flight + the active plan.'
}

Write-Host '--------------------------------------' -ForegroundColor Cyan
Write-Host '  SAFE TO WORK' -ForegroundColor Green
exit 0
