<#
.SYNOPSIS
    Verifies that the current shell PATH is safe (no MSYS2/WSL/Linux-emulation tools).
    Run this at the START of every AI agent session to confirm you are clean.
    Linux twin: tools/verify-path-health.sh (see tools/README.md for the parity policy).

.USAGE
    From any PowerShell:  .\tools\verify-path-health.ps1
#>

$repoRoot = Split-Path -Parent $PSScriptRoot

# First-init bootstrap: in the kit repo (where user-notes.md lives), auto-create the
# operator's PRIVATE notes file if missing. It is gitignored - personal/machine/
# project specifics go there, never into tracked files. No-op in project repos.
$sharedNotes = Join-Path $repoRoot 'user-notes.md'
$localNotes = Join-Path $repoRoot 'user-notes.local.md'
if ((Test-Path $sharedNotes) -and (-not (Test-Path $localNotes))) {
    $seed = @(
        '# user-notes.local.md - YOUR private notes (gitignored, never committed)',
        '',
        '> Auto-created on first run of verify-path-health. Personal, machine, and',
        '> project specifics live HERE: repo paths, usernames, build commands, quirks.',
        '> AI agents in this kit route personal notes to this file automatically.',
        '> The tracked user-notes.md stays generic for everyone. Make this one yours.',
        '',
        '## My repos & locations',
        '',
        '| Repo | Path | What |',
        '|------|------|------|',
        '|      |      |      |',
        '',
        '## My machine setup (auth, OS notes, identity)',
        '',
        '## My project build & run commands',
        ''
    )
    Set-Content -Path $localNotes -Value $seed
    Write-Host "[INIT] created user-notes.local.md (your private, gitignored notes file)" -ForegroundColor Cyan
}

if (-not $env:OGDK_BANNER) {
    Write-Host '   ___   ____ ____  _  __' -ForegroundColor Cyan
    Write-Host '  / _ \ / ___|  _ \| |/ /' -ForegroundColor Cyan
    Write-Host ' | | | | |  _| | | | '' /' -ForegroundColor Cyan
    Write-Host ' | |_| | |_| | |_| | . \' -ForegroundColor Cyan
    Write-Host '  \___/ \____|____/|_|\_\' -ForegroundColor Cyan
}
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  PATH Health Check (OGDK)            " -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

$issues = @()

# Check 1: MSYS2/WSL/Cygwin in PATH
$badPaths = ($env:PATH -split ';') | Where-Object {
    $_ -match 'msys|ucrt64|mingw|cygwin|/usr/|/opt/|\\wsl\\|wslpath' -and $_ -ne ''
}
if ($badPaths) {
    Write-Host "[FAIL] Linux-emulation paths found in PATH:" -ForegroundColor Red
    $badPaths | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
    $issues += "MSYS2/WSL in PATH"
} else {
    Write-Host "[PASS] No MSYS2/WSL/Cygwin in PATH" -ForegroundColor Green
}

# Check 2: git resolves to Windows Git
$gitPath = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $gitPath) {
    Write-Host "[WARN] git not found in PATH" -ForegroundColor Yellow
} elseif ($gitPath -match 'msys|ucrt|mingw|cygwin') {
    Write-Host "[FAIL] git resolves to MSYS2: $gitPath" -ForegroundColor Red
    $issues += "git -> MSYS2"
} else {
    Write-Host "[PASS] git -> $gitPath" -ForegroundColor Green
    
    $gitEmail = (git config user.email)
    if (-not $gitEmail) {
        Write-Host "[FAIL] git identity not set (git config --global user.name / user.email)" -ForegroundColor Red
        $issues += "git identity not set"
    } else {
        Write-Host "[PASS] git identity: $gitEmail" -ForegroundColor Green
        if ($gitEmail -notmatch 'noreply') {
            Write-Host "[WARN] git email is a public/personal address ($gitEmail). Consider using a GitHub noreply email to protect your privacy." -ForegroundColor Yellow
        }
    }
}

# Check 2b: privacy guard - hooks installed + markers present (the leak backstop)
$hooksPath = (git config core.hooksPath 2>$null)
if ($hooksPath -eq 'tools/hooks') {
    Write-Host "[PASS] git hooks active (core.hooksPath -> tools/hooks: pre-commit + pre-push)" -ForegroundColor Green
} else {
    Write-Host "[WARN] git hooks not installed (optional - the privacy guard for repos you will share publicly). Arm any time: .\tools\install-hooks.ps1" -ForegroundColor Yellow
}
if (Test-Path (Join-Path $repoRoot 'tools/PRIVATE-MARKERS.list')) {
    Write-Host "[PASS] PRIVATE-MARKERS.list present (privacy scan armed)" -ForegroundColor Green
} else {
    Write-Host "[WARN] tools/PRIVATE-MARKERS.list not set up (optional - only needed before you make a repo public; see tools/README.md)" -ForegroundColor Yellow
}

# Check 3: sed -- warn if it is MSYS2 sed
$sedPath = (Get-Command sed -ErrorAction SilentlyContinue).Source
if ($sedPath -and $sedPath -match 'msys|ucrt|mingw') {
    Write-Host "[FAIL] sed resolves to MSYS2: $sedPath" -ForegroundColor Red
    $issues += "sed -> MSYS2"
} elseif ($sedPath) {
    Write-Host "[WARN] sed found (non-MSYS2): $sedPath" -ForegroundColor Yellow
} else {
    Write-Host "[PASS] sed not in PATH (MSYS2 absent)" -ForegroundColor Green
}

# Check 4: node resolves to Windows nodejs
$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if ($nodePath -match 'msys|ucrt|mingw|nvm\\versions') {
    Write-Host "[WARN] node via NVM/MSYS: $nodePath" -ForegroundColor Yellow
} elseif ($nodePath) {
    Write-Host "[PASS] node -> $nodePath" -ForegroundColor Green
} else {
    Write-Host "[WARN] node not found in PATH" -ForegroundColor Yellow
}

# Check 5: No .exe entries in PATH (malformed entries)
$exeInPath = ($env:PATH -split ';') | Where-Object { $_ -match '\.exe$' }
if ($exeInPath) {
    Write-Host "[FAIL] Malformed PATH entries (file paths, not directories):" -ForegroundColor Red
    $exeInPath | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
    $issues += "Malformed .exe PATH entries"
} else {
    Write-Host "[PASS] No malformed .exe entries in PATH" -ForegroundColor Green
}

# Check 6: repo dir not cloud-synced (OneDrive/Dropbox overlays corrupt rapid writes)
$attr = (attrib $repoRoot 2>&1)
if ($attr -match '\bP\b|\bO\b') {
    Write-Host "[WARN] $repoRoot may have cloud-sync attributes: $attr" -ForegroundColor Yellow
    $issues += "Cloud sync on project dir"
} else {
    Write-Host "[PASS] $repoRoot has no cloud-sync overlay attributes" -ForegroundColor Green
}

# Check 7 (app track only): JAVA_HOME, needed for Android/Capacitor builds
$javaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
if (-not $javaHome) {
    $javaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
}
if (-not $javaHome) {
    Write-Host "[WARN] JAVA_HOME not set (only matters for app-track Android builds)" -ForegroundColor Yellow
} elseif (-not (Test-Path (Join-Path $javaHome "bin\java.exe"))) {
    Write-Host "[WARN] JAVA_HOME points to missing JDK: $javaHome" -ForegroundColor Yellow
} else {
    Write-Host "[PASS] JAVA_HOME -> $javaHome" -ForegroundColor Green
}

# Provenance: which kit commit this repo's tools came from (projects only;
# stamped by new-project/propagate-tools - absent in the kit itself and in
# repos that have not re-propagated yet).
$kvFile = Join-Path $repoRoot 'tools\KIT-VERSION'
if (Test-Path $kvFile) {
    $kv = (Get-Content $kvFile -Encoding UTF8 | Select-Object -First 1)
    Write-Host "[INFO] tools provenance: $kv" -ForegroundColor Cyan
}

# Summary
Write-Host ""
Write-Host "--------------------------------------" -ForegroundColor Cyan
if ($issues.Count -eq 0) {
    Write-Host "  ALL CHECKS PASSED -- safe to run AI agents" -ForegroundColor Green
} else {
    Write-Host "  $($issues.Count) ISSUE(S) FOUND:" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "  DO NOT run Claude Code or agy until resolved." -ForegroundColor Red
    Write-Host "  Use: .\tools\launch-claude-clean.ps1 instead" -ForegroundColor Cyan
}
Write-Host "--------------------------------------" -ForegroundColor Cyan
exit $issues.Count