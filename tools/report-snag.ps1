# OGDK - turn a snag into a ready-to-paste LESSONS.md entry. The kit's whole premise
# is that friction the system did not prevent should be captured - but writing a
# LESSONS entry by hand is exactly the chore a beginner skips. This makes it a
# 10-second job: describe what went wrong, and it prints a formatted draft (plus
# harmless environment context) you can drop straight into LESSONS.md.
# Writes nothing itself (the draft goes to stdout - redirect or copy it). Twin: report-snag.sh.
#
# Usage: .\tools\report-snag.ps1 "the gate failed after I edited app.py"
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$desc = if ($args.Count -gt 0) { ($args -join ' ') } else { '<describe what you were doing and what went wrong>' }
$today = Get-Date -Format 'yyyy-MM-dd'
$os = [System.Environment]::OSVersion.VersionString
$gitver = (git --version 2>$null); if (-not $gitver) { $gitver = 'git not found' }
$branch = (git rev-parse --abbrev-ref HEAD 2>$null); if (-not $branch) { $branch = 'n/a' }
$lastcommit = (git log -1 --format='%h %s' 2>$null); if (-not $lastcommit) { $lastcommit = 'n/a' }
$kitver = 'n/a'
$kvf = Join-Path $root 'tools\KIT-VERSION'
if (Test-Path $kvf) { $kitver = (Get-Content $kvf -Encoding UTF8 | Select-Object -First 1) }

# Guidance via Write-Host (console only) so stdout stays a clean, redirectable draft.
Write-Host 'Paste the block below into docs/LESSONS.md (a project) or LESSONS.md (the kit).' -ForegroundColor Cyan
Write-Host 'Fill the <bits>; the retro will turn it into a permanent fix. ----------------' -ForegroundColor Cyan

$draft = @(
    "## $today <one-line title for the snag>",
    "**What happened:** $desc",
    "**Environment:** $os | $gitver | branch: $branch | last commit: $lastcommit | KIT-VERSION: $kitver",
    "**Root cause:** <fill in if known - or leave it for the retro>",
    "**Proposed fix:** <what would have prevented this?>",
    "**Status:** OPEN"
)
$draft -join "`n" | Write-Output
exit 0
