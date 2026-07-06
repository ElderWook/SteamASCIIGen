# File integrity check (OGDK) - detects the corruption signatures we have actually seen:
#   1. NUL bytes inside tracked text files  (MSYS2/NTFS zero-filled-tail corruption)
#   2. Truncated source files               (.py checked by compile, if python present)
#   3. Git object-store corruption          (git fsck)
# Run BEFORE committing after heavy agent writes. Twin: verify-file-integrity.sh.
$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
$issues = 0

if (-not $env:OGDK_BANNER) {
    Write-Host '   ___   ____ ____  _  __' -ForegroundColor Cyan
    Write-Host '  / _ \ / ___|  _ \| |/ /' -ForegroundColor Cyan
    Write-Host ' | | | | |  _| | | | '' /' -ForegroundColor Cyan
    Write-Host ' | |_| | |_| | |_| | . \' -ForegroundColor Cyan
    Write-Host '  \___/ \____|____/|_|\_\' -ForegroundColor Cyan
}
Write-Host '======================================' -ForegroundColor Cyan
Write-Host '  File Integrity Check (OGDK)         ' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan

# Check 1: git object store
if (Test-Path '.git') {
    git fsck --no-progress 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '[PASS] git fsck: object store healthy' -ForegroundColor Green
    } else {
        Write-Host '[FAIL] git fsck reports corruption - do NOT commit; investigate .git' -ForegroundColor Red
        $issues++
    }
} else {
    Write-Host '[WARN] not a git repo - skipping fsck' -ForegroundColor Yellow
}

# Check 2: NUL bytes in tracked text files
$textExt = '\.(md|txt|py|js|ts|jsx|tsx|json|ps1|sh|bat|cs|cpp|c|h|hpp|ini|yml|yaml|toml|svelte|dart|cjs|mjs|html|css|xml|sql|uproject|uplugin|gitignore|gitattributes)$'
$tracked = git ls-files 2>$null | Where-Object { $_ -and $_ -match $textExt }
if (-not $tracked -or $tracked.Count -eq 0) {
    Write-Host '[WARN] git ls-files returned no files. Falling back to local file system scan...' -ForegroundColor Yellow
    $excludeDirs = @('.git', 'node_modules', 'dist', 'target', 'bin', 'obj', 'build', 'artifacts', '__pycache__')
    $tracked = @()
    Get-ChildItem -Path . -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $relPath = $_.FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
        $isExcluded = $false
        foreach ($d in $excludeDirs) {
            if ($relPath -like "$d/*" -or $relPath -eq $d -or $relPath -like "*/$d/*") {
                $isExcluded = $true
                break
            }
        }
        if (-not $isExcluded -and $relPath -match $textExt) {
            $tracked += $relPath
        }
    }
}
$nulHits = @()
foreach ($f in $tracked) {
    if (-not (Test-Path $f)) { continue }
    $fi = Get-Item $f
    if ($fi.Length -eq 0 -or $fi.Length -gt 5MB) { continue }
    $bytes = [System.IO.File]::ReadAllBytes($fi.FullName)
    if ($bytes -contains 0) { $nulHits += $f }
}
if ($nulHits.Count -gt 0) {
    Write-Host '[FAIL] NUL bytes found in text files (zero-fill corruption signature):' -ForegroundColor Red
    $nulHits | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
    $issues++
} else {
    Write-Host '[PASS] no NUL bytes in tracked text files' -ForegroundColor Green
}

# Check 3: Python files compile (catches mid-file truncation).
# Find a python that ACTUALLY LAUNCHES (Windows Store stubs and broken installs
# exist on PATH but fail with launcher errors - seen in the wild as 0x800702E4).
$pyCmd = $null
foreach ($cand in @('python', 'py', 'python3')) {
    $c = Get-Command $cand -ErrorAction SilentlyContinue
    if (-not $c) { continue }
    & $c.Source --version 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $pyCmd = $c.Source; break }
}
$pyFiles = @(git ls-files '*.py' 2>$null) | Where-Object { $_ }
if ($pyFiles.Count -eq 0 -and $tracked) {
    $pyFiles = @($tracked | Where-Object { $_ -match '\.py$' })
}
if ($pyFiles.Count -eq 0) {
    Write-Host '[PASS] no tracked .py files (compile check not applicable)' -ForegroundColor Green
} elseif (-not $pyCmd) {
    Write-Host '[WARN] no WORKING python found (broken install or Store stub?) - .py compile check skipped. Fix: install from python.org or `winget install Python.Python.3.12`' -ForegroundColor Yellow
} else {
    $pyBad = @()
    foreach ($f in $pyFiles) {
        if (-not (Test-Path $f)) { continue }
        & $pyCmd -m py_compile $f 2>$null
        if ($LASTEXITCODE -ne 0) { $pyBad += $f }
    }
    if ($pyBad.Count -gt 0) {
        Write-Host '[FAIL] Python files do not compile (possible truncation):' -ForegroundColor Red
        $pyBad | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
        $issues++
    } else {
        Write-Host "[PASS] all tracked .py files compile ($pyCmd)" -ForegroundColor Green
    }
}

# Check 3b: PowerShell scripts parse (catches mid-file truncation of .ps1 - the
# 2026-06-12 hardware-project verify-path-health lesson: a truncated .ps1 sat committed
# and undetected because nothing parsed project scripts).
# Platform difference (documented): the .sh twin validates *.sh via bash -n instead;
# each platform parses what it can execute.
$psFiles = @(git ls-files '*.ps1' 2>$null) | Where-Object { $_ }
if ($psFiles.Count -eq 0 -and $tracked) {
    $psFiles = @($tracked | Where-Object { $_ -match '\.ps1$' })
}
$psBad = @()
foreach ($f in $psFiles) {
    if (-not (Test-Path $f)) { continue }
    $tokens = $null; $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f).Path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) { $psBad += "$f : $($parseErrors[0].Message)" }
}
if ($psFiles.Count -eq 0) {
    Write-Host '[PASS] no tracked .ps1 files (parse check not applicable)' -ForegroundColor Green
} elseif ($psBad.Count -gt 0) {
    Write-Host '[FAIL] PowerShell files do not parse (possible truncation):' -ForegroundColor Red
    $psBad | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
    $issues++
} else {
    Write-Host '[PASS] all tracked .ps1 files parse' -ForegroundColor Green
}

# Check 4b: EOF sentinel on tools scripts. A truncated script can PASS syntax
# checks if the cut lands inside a comment (2026-06-12 lesson - bash -n approved
# a script missing its last 30 lines). Every tools script must therefore END
# with an explicit final statement: a line starting with 'exit' or '# EOF'.
$sentBad = @()
$sentFiles = @(git ls-files 'tools/*.ps1' 'tools/*.sh' 2>$null) | Where-Object { $_ }
if ($sentFiles.Count -eq 0 -and $tracked) {
    $sentFiles = @($tracked | Where-Object { $_ -match '^tools/[^/]+\.(ps1|sh)$' })
}
foreach ($f in $sentFiles) {
    if (-not (Test-Path $f)) { continue }
    $lines = @(Get-Content $f -Encoding UTF8 | Where-Object { $_.Trim() -ne '' })
    if ($lines.Count -eq 0) { $sentBad += $f; continue }
    $last = $lines[$lines.Count - 1].Trim()
    if ($last -notmatch '^(exit($|\s)|# EOF$)') { $sentBad += $f }
}
if ($sentFiles.Count -eq 0) {
    Write-Host '[PASS] no tools scripts tracked (EOF sentinel not applicable)' -ForegroundColor Green
} elseif ($sentBad.Count -gt 0) {
    Write-Host "[FAIL] tools script(s) missing EOF sentinel - last non-blank line must start with 'exit' or be '# EOF' (truncation guard):" -ForegroundColor Red
    $sentBad | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
    $issues++
} else {
    Write-Host '[PASS] all tools scripts end with an EOF sentinel' -ForegroundColor Green
}

# Check 4: trailing-newline smell test on source/docs
$noEol = @()
$eolFiles = @(git ls-files 2>$null | Where-Object { $_ -match '\.(py|sh|md)$' }) | Where-Object { $_ }
if ($eolFiles.Count -eq 0 -and $tracked) {
    $eolFiles = @($tracked | Where-Object { $_ -match '\.(py|sh|md)$' })
}
foreach ($f in $eolFiles) {
    if (-not (Test-Path $f)) { continue }
    $fi = Get-Item $f
    if ($fi.Length -eq 0) { continue }
    $fs = [System.IO.File]::Open($fi.FullName, 'Open', 'Read')
    $fs.Seek(-1, 'End') | Out-Null
    $last = $fs.ReadByte()
    $fs.Close()
    if ($last -ne 10) { $noEol += $f }
}
if ($noEol.Count -gt 0) {
    Write-Host '[WARN] files lacking trailing newline (verify they are complete):' -ForegroundColor Yellow
    $noEol | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
} else {
    Write-Host '[PASS] all checked files end with newline' -ForegroundColor Green
}

Write-Host '--------------------------------------' -ForegroundColor Cyan
if ($issues -eq 0) {
    Write-Host '  INTEGRITY OK - safe to commit' -ForegroundColor Green
} else {
    Write-Host "  $issues ISSUE(S) - do NOT commit until resolved" -ForegroundColor Red
}
exit $issues
