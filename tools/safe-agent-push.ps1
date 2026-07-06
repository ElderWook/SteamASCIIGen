# tools/safe-agent-push.ps1
# Automated, gate-verified git commit & push for an AI agent that has NATIVE git access
# (NOT a synced-mount/sandbox agent - those must never run git). This is the local-access
# SAVE+push path of the git lifecycle (docs/workflow/GIT-LIFECYCLE.md): it runs the checkpoints
# in order and ABORTS - never forces - on any failure or divergence, exactly as gitwalk requires.
#   C0 ARRIVE : verify-path-health + sync-repo (a STOP/non-zero exit aborts -> hand to a human)
#   C2 SAVE   : gate (exit 0 or no commit) -> git add -A -> commit -> push (current branch's upstream)
# For a panic save of a half-broken tree use checkpoint.ps1, not this. Twin: safe-agent-push.sh.
#   Usage: .\tools\safe-agent-push.ps1 ["commit message"]
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $dir '..')).Path

# Guard: this runs git, so it must NOT run through a synced/emulated mount (gitwalk: git only
# in a native shell). The Linux Cowork mount is the main hazard; a UNC path is the Windows
# analogue. sync-repo enforces this too, but fail fast and clearly here before any git runs.
if ($repo -match '[\\/]sessions[\\/][^\\/]+[\\/]mnt[\\/]' -or $repo.StartsWith('\\')) {
    Write-Error "[STOP] $repo looks like a synced/emulated mount - safe-agent-push runs git and must run in a NATIVE shell only. Aborting; no git ran."
}

Write-Host "=== Step 1/4: path health (C0) ===" -ForegroundColor Cyan
& "$dir\verify-path-health.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "Path health check failed. Aborting commit/push." }

Write-Host "=== Step 2/4: safe arrival / sync (C0 ARRIVE) ===" -ForegroundColor Cyan
& "$dir\sync-repo.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "Repository sync check failed or diverged. Aborting; hand back to a human." }

Write-Host "=== Step 3/4: the gate (C2) ===" -ForegroundColor Cyan
& "$dir\gate.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "Project gate checks failed. Aborting commit/push." }

Write-Host "=== Step 4/4: save + push (C2 SAVE) ===" -ForegroundColor Cyan
$msg = $args[0]
if (-not $msg) { $msg = "chore: agent commit (gate verified)" }
git -C $repo add -A
git -C $repo diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "[INFO] nothing staged to commit - pushing any unpushed commits."
} else {
    git -C $repo commit -m $msg
    if ($LASTEXITCODE -ne 0) { Write-Error "Commit failed. Aborting." }
}
git -C $repo push
if ($LASTEXITCODE -ne 0) { Write-Error "Push failed (diverged or offline?). Aborting - do not force; re-run after sync." }
Write-Host "=== SAFE-AGENT-PUSH COMPLETE ===" -ForegroundColor Green
exit 0
