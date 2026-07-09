# THE GATE - one command answers "did I break it?". Copied into each project by
# new-project; fill in the project section. Twin: gate.sh.
# Exit 0 = safe to commit. Anything else = fix first.
# NOTE (2026-07-09): authored on Linux mirroring the tested gate.sh; the .sh side
# is verified, this .ps1 twin is PENDING first-run verification on Windows.
$ErrorActionPreference = 'Continue'
$dir = $PSScriptRoot
$total = 0
function Step([string]$name) { Write-Host ''; Write-Host "=== GATE: $name ===" -ForegroundColor Cyan }
if (-not $env:OGDK_BANNER) {
    Write-Host '   ___   ____ ____  _  __' -ForegroundColor Cyan
    Write-Host '  / _ \ / ___|  _ \| |/ /' -ForegroundColor Cyan
    Write-Host ' | | | | |  _| | | | '' /' -ForegroundColor Cyan
    Write-Host ' | |_| | |_| | |_| | . \' -ForegroundColor Cyan
    Write-Host '  \___/ \____|____/|_|\_\' -ForegroundColor Cyan
}
$env:OGDK_BANNER = '1'

Step 'file integrity'
& "$dir\verify-file-integrity.ps1"; $total += $LASTEXITCODE

Step 'reference coverage'
& "$dir\check-reference-coverage.ps1"; $total += $LASTEXITCODE

Step 'git identity'
& "$dir\check-git-identity.ps1"; $total += $LASTEXITCODE

Step 'project checks'
# Vite/Svelte app: a clean production build is the smoke test (no unit tests yet).
npm run build; $total += $LASTEXITCODE

Write-Host ''
Write-Host '======================================'
if ($total -eq 0) { Write-Host '  GATE PASSED - safe to commit' -ForegroundColor Green }
else { Write-Host "  GATE FAILED ($total) - do not commit" -ForegroundColor Red }
Remove-Item Env:\OGDK_BANNER -ErrorAction SilentlyContinue
exit $total
