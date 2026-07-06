# Launches Claude Code from a guaranteed-clean PATH (no MSYS2, WSL, or Cygwin injection).
#
# WHY: MSYS2 coreutils (sed, cp, mv, git) injected into PATH use POSIX file APIs against
# NTFS, producing zero-filled tails and truncation during rapid in-place writes - the
# corruption class this kit guards against. This script rebuilds PATH from Windows-native
# tools only, verifies the result, then launches claude.
#
# USAGE: .\tools\launch-claude-clean.ps1   (from a plain PowerShell terminal)
# Twin: launch-claude-clean.sh (Linux runs the health gate then launches; no PATH surgery needed).
$ErrorActionPreference = 'Continue'

# -- 1. Build a clean PATH from Windows-native locations that exist on this machine ----
$candidates = @(
    "$env:SystemRoot\system32",
    "$env:SystemRoot",
    "$env:SystemRoot\System32\Wbem",
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0",
    "$env:SystemRoot\System32\OpenSSH",
    "$env:ProgramFiles\Git\cmd",
    "$env:ProgramFiles\Git\usr\bin",       # git's bundled Unix tools (safe on Windows)
    "$env:ProgramFiles\nodejs",
    "$env:ProgramFiles\PowerShell\7",
    "$env:USERPROFILE\.local\bin",          # claude.exe default install location
    "$env:USERPROFILE\.cargo\bin",
    "$env:USERPROFILE\.dotnet\tools",
    "$env:APPDATA\npm",
    "$env:LOCALAPPDATA\Microsoft\WindowsApps",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
)
$env:PATH = ($candidates | Where-Object { $_ -and (Test-Path $_) }) -join ';'

# -- 2. Sanity-check: confirm MSYS2/WSL/Cygwin are gone --------------------------------
$bad = ($env:PATH -split ';') | Where-Object { $_ -match 'msys|ucrt|mingw|cygwin|\\wsl' }
if ($bad) {
    Write-Warning 'Linux-emulation paths still present after cleanup - aborting!'
    $bad | ForEach-Object { Write-Warning "  $_" }
    exit 1
}

# -- 3. Verify git resolves to Windows Git ---------------------------------------------
$gitPath = (Get-Command git -ErrorAction SilentlyContinue).Source
if ($gitPath -and $gitPath -notmatch 'Program Files\\Git') {
    Write-Warning "git resolves to '$gitPath' - not Windows Git! Check your PATH."
} elseif ($gitPath) {
    Write-Host "[OK] git -> $gitPath" -ForegroundColor Green
} else {
    Write-Warning 'git not found on the clean PATH'
}

# -- 3b. Health gate on the CLEANED PATH (twin parity: the .sh runs the gate before
#        launch). Running it here, after the PATH surgery above, is the Windows
#        equivalent - the ambient PATH may have been poisoned, which is why you are
#        using this launcher; the rebuilt PATH is what we verify. ----------------------
$health = Join-Path $PSScriptRoot 'verify-path-health.ps1'
if (Test-Path $health) {
    & $health
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'verify-path-health reported issues even after PATH cleanup - aborting launch. Fix the issues above, then retry.'
        exit 1
    }
}

# -- 4. Locate claude -------------------------------------------------------------------
$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) {
    $fallback = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path $fallback) { $claude = $fallback }
}
if (-not $claude) {
    Write-Error 'claude not found on the clean PATH (expected in %USERPROFILE%\.local\bin). Install Claude Code or add its location to the candidates list in this script.'
    exit 1
}

# -- 5. Launch ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Launching claude from clean Windows-native PATH...' -ForegroundColor Cyan
Write-Host "claude: $claude" -ForegroundColor DarkGray
Write-Host "Working directory: $PWD" -ForegroundColor DarkGray
Write-Host ''
& $claude @args
exit $LASTEXITCODE
