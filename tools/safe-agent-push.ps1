# tools/safe-agent-push.ps1
# Automated, gate-verified git commit & push for an AI agent that has NATIVE git access
# (NOT a synced-mount/sandbox agent - those must never run git). This is the local-access
# SAVE+push path of the git lifecycle (docs/workflow/GIT-LIFECYCLE.md): it runs the checkpoints
# in order and ABORTS - never forces - on any failure or divergence, exactly as gitwalk requires.
#   C0 ARRIVE : verify-path-health + sync-repo (a STOP/non-zero exit aborts -> hand to a human)
#   C2 SAVE   : gate (exit 0 or no commit) -> git add -A -> commit -> push (current branch's upstream)
# For a panic save of a half-broken tree use checkpoint.ps1, not this. Twin: safe-agent-push.sh.
#   Usage: .\tools\safe-agent-push.ps1 ["commit message"] [path1] [path2]...
#          .\tools\safe-agent-push.ps1 -PushOnly
# -PushOnly: sync-guard + push ONLY (skips the gate + add/commit) - for pushing commits that
# were already gate-verified when created, when THIS env's gate now fails for orthogonal reasons
# (a missing optional dep, a heavy project build, an already-public historical identity leak).
# It still runs path-health + sync-repo and still honors the pre-push hook: it REFUSES, never
# forces, never --no-verify.
param(
    [Parameter(Position=0)]
    [string]$Message = "chore: agent commit (gate verified)",
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Paths,
    [switch]$PushOnly
)
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $dir '..')).Path

# Guard: this runs git, so it must NOT run through a synced/emulated mount (gitwalk: git only
# in a native shell). The Linux Cowork mount is the main hazard; a UNC path is the Windows
# analogue. sync-repo enforces this too, but fail fast and clearly here before any git runs.
if ($repo -match '[\\/]sessions[\\/][^\\/]+[\\/]mnt[\\/]' -or $repo.StartsWith('\\')) {
    Write-Error "[STOP] $repo looks like a synced/emulated mount - safe-agent-push runs git and must run in a NATIVE shell only. Aborting; no git ran."
}

$stepN = if ($PushOnly) { 3 } else { 4 }
Write-Host "=== Step 1/${stepN}: path health (C0) ===" -ForegroundColor Cyan
& "$dir\verify-path-health.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "Path health check failed. Aborting commit/push." }

Write-Host "=== Step 2/${stepN}: safe arrival / sync (C0 ARRIVE) ===" -ForegroundColor Cyan
& "$dir\sync-repo.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "Repository sync check failed or diverged. Aborting; hand back to a human." }

if ($PushOnly) {
    # PUSH-ONLY: the commits were gate-verified when created; skip the gate + add/commit and
    # just push already-committed history. For when THIS env's gate fails for orthogonal reasons
    # (a missing dep, a heavy project build, an already-public historical identity). The pre-push
    # hook still runs, so a genuine identity leak is REFUSED here - never forced, never bypassed.
    if ($Paths.Count -gt 0) { Write-Host "[INFO] -PushOnly neither stages nor commits; ignoring path args: $($Paths -join ', ')" -ForegroundColor Yellow }
    Write-Host "=== Step 3/${stepN}: push only (gate + add/commit skipped) ===" -ForegroundColor Cyan
    $ahead = (git -C $repo rev-list --count '@{upstream}..HEAD' 2>$null)
    if (-not $ahead) { $ahead = '0' }
    if ($ahead -eq '0') {
        Write-Host "[INFO] no local commits ahead of upstream - nothing to push." -ForegroundColor Yellow
        exit 0
    }
    git -C $repo diff --quiet
    if ($LASTEXITCODE -ne 0) { Write-Host "[NOTE] uncommitted working-tree changes are NOT pushed (push-only pushes committed history)." -ForegroundColor Yellow }
    git -C $repo push
    if ($LASTEXITCODE -ne 0) { Write-Error "Push failed (diverged, offline, or the pre-push hook refused a leaked identity). Aborting - do not force." }
    Write-Host "=== SAFE-AGENT-PUSH (push-only) COMPLETE - pushed $ahead commit(s) ===" -ForegroundColor Green
    exit 0
}

Write-Host "=== Step 3/${stepN}: the gate (C2) ===" -ForegroundColor Cyan
& "$dir\gate.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "Project gate checks failed. Aborting commit/push." }

Write-Host "=== Step 4/${stepN}: save + push (C2 SAVE) ===" -ForegroundColor Cyan
if ($Paths.Count -gt 0) {
    git -C $repo add $Paths
} else {
    $untrackedSum = 0
    $untracked = git -C $repo ls-files --others --exclude-standard
    foreach ($f in $untracked) {
        $p = Join-Path $repo $f
        if (Test-Path $p) { $untrackedSum += (Get-Item $p).Length }
    }
    if ($untrackedSum -gt 100MB) {
        Write-Error "[STOP] Untracked files exceed 100MB. Unsafe for a blanket 'git add -A'. Stage selectively, then pass paths to safe-agent-push."
    }
    git -C $repo add -A
}
git -C $repo diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "[INFO] nothing staged to commit - pushing any unpushed commits."
} else {
    git -C $repo commit -m $Message
    if ($LASTEXITCODE -ne 0) { Write-Error "Commit failed. Aborting." }
}
git -C $repo push
if ($LASTEXITCODE -ne 0) { Write-Error "Push failed (diverged or offline?). Aborting - do not force; re-run after sync." }
Write-Host "=== SAFE-AGENT-PUSH COMPLETE ===" -ForegroundColor Green
exit 0
