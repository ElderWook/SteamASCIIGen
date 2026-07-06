# Install the OGDK git hooks for THIS clone by pointing core.hooksPath at the
# tracked tools/hooks directory. pre-commit blocks a private-marker leak (content or
# git identity) before it enters a commit; pre-push rescans commit-history identity
# before it leaves the machine. Per-clone and idempotent (core.hooksPath is local
# config, not committed). Undo: git config --unset core.hooksPath. Twin: install-hooks.sh.
$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host '======================================' -ForegroundColor Cyan
Write-Host '  Install Git Hooks (OGDK)            ' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan

$null = git rev-parse --git-dir 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host '[FAIL] not a git repository - run from inside the repo' -ForegroundColor Red
    exit 1
}
if ((-not (Test-Path 'tools/hooks/pre-push')) -and (-not (Test-Path 'tools/hooks/pre-commit'))) {
    Write-Host '[FAIL] no hooks found in tools/hooks/ - nothing to install' -ForegroundColor Red
    exit 1
}
git config core.hooksPath tools/hooks
$code = $LASTEXITCODE
if ($code -eq 0) {
    Write-Host '[PASS] core.hooksPath -> tools/hooks (pre-commit + pre-push privacy guards active)' -ForegroundColor Green
    Write-Host '       pre-commit blocks a leak before it enters a commit; pre-push rescans history.' -ForegroundColor Gray
    Write-Host '       Undo: git config --unset core.hooksPath' -ForegroundColor Gray
} else {
    Write-Host '[FAIL] could not set core.hooksPath' -ForegroundColor Red
}
exit $code
