# Scaffold a reference page from COMPONENT-TEMPLATE.md and register it in COVERAGE.md.
# Windows twin of new-reference-page.sh - same args, same behavior, same exit semantics.
#
# Usage (from the PROJECT root):
#   .\tools\new-reference-page.ps1 -Name <page-slug> -Component "<Component Title>" -Source "<source/path[;more/paths]>"
# Example:
#   .\tools\new-reference-page.ps1 -Name vote -Component "Voting detector" -Source "shared/logic/vote.py"
#
# Multiple source paths are ';'-separated (matches the COVERAGE.md parser).
# The page is created with status 'current' - FILL IT IN before committing;
# page and manifest row belong in the same commit as the component (AGENTS.md).
param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Component,
    [Parameter(Mandatory=$true)][string]$Source
)
$ErrorActionPreference = "Stop"

if (-not $env:OGDK_BANNER) {
    Write-Host '   ___   ____ ____  _  __' -ForegroundColor Cyan
    Write-Host '  / _ \ / ___|  _ \| |/ /' -ForegroundColor Cyan
    Write-Host ' | | | | |  _| | | | '' /' -ForegroundColor Cyan
    Write-Host ' | |_| | |_| | |_| | . \' -ForegroundColor Cyan
    Write-Host '  \___/ \____|____/|_|\_\' -ForegroundColor Cyan
}

if ($Name -notmatch '^[a-z0-9-]+$') {
    Write-Error "page-slug must be lowercase letters, digits, hyphens: '$Name'"; exit 1
}

$Ref  = "docs/reference"
$Tpl  = Join-Path $Ref "COMPONENT-TEMPLATE.md"
$Man  = Join-Path $Ref "COVERAGE.md"
$Page = Join-Path $Ref ($Name + ".md")

if (-not (Test-Path $Tpl)) { Write-Error "Missing $Tpl - run from the project root (docs chain must exist)"; exit 1 }
if (-not (Test-Path $Man)) { Write-Error "Missing $Man - reference tier not initialized"; exit 1 }
if (Test-Path $Page)       { Write-Error "$Page already exists - refusing to overwrite"; exit 1 }

$Today = Get-Date -Format "yyyy-MM-dd"

# 1. Page from template: stamp title, source path, and changelog date
$content = Get-Content $Tpl -Raw -Encoding UTF8
$content = $content.Replace("<Component Name>", $Component)
$content = $content.Replace('`<path/to/module>`', ('`' + $Source + '`'))
$content = $content.Replace("<date>", $Today)
Set-Content -Path $Page -Value $content -Encoding UTF8 -NoNewline

# 2. Manifest row (replace the '_none yet_' placeholder if it is still there)
$Row = "| $Component | $Source | $Name.md | current |"
$lines = Get-Content $Man -Encoding UTF8
$replaced = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\| _none yet_') { $lines[$i] = $Row; $replaced = $true; break }
}
if (-not $replaced) { $lines = $lines + $Row }
Set-Content -Path $Man -Value $lines -Encoding UTF8

Write-Host "Created  $Page"
Write-Host "Tracked  ${Man}: $Row"
Write-Host ""
Write-Host "Next: fill in the page sections, then commit page + manifest + component together."
Write-Host "Verify: .\tools\check-reference-coverage.ps1"
exit 0
