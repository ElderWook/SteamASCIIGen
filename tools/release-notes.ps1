# Draft release notes from git history (tag-to-tag). Markdown on stdout - redirect
# where you want it; the tool never writes files. Windows twin of release-notes.sh.
#
# Usage (from a project root):
#   .\tools\release-notes.ps1                       # latest tag .. HEAD
#   .\tools\release-notes.ps1 v0.1.0                # v0.1.0 .. HEAD
#   .\tools\release-notes.ps1 v0.1.0 v0.2.0         # tag to tag
#   .\tools\release-notes.ps1 > docs\workflow\RELEASE-NOTES-v0.2.0.md   # then EDIT it
#
# Zero commit-message discipline required: subjects with a 'type:' prefix
# (feat/fix/docs/...) are grouped; everything else lands under 'Other changes'.
# This only DRAFTS - a human edits the output before it ships.
param(
    [string]$From = "",
    [string]$To = "HEAD"
)
$ErrorActionPreference = "Stop"

git rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) { Write-Error "not a git repo"; exit 1 }

if ($From -eq "") {
    $From = git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -ne 0) { $From = "" }
}
if ($From) { $Range = "$From..$To" } else { $Range = $To }

$Count = git rev-list --no-merges --count $Range 2>$null
if ($LASTEXITCODE -ne 0 -or [int]$Count -eq 0) { Write-Error "no commits in range '$Range'"; exit 1 }

$Today = Get-Date -Format "yyyy-MM-dd"
Write-Output "# Release notes - $To ($Today)"
Write-Output ""
if ($From) {
    Write-Output "_$Count commits since $From. Drafted by tools/release-notes.ps1 - edit before shipping._"
} else {
    Write-Output "_$Count commits, full history (no tags found). Drafted by tools/release-notes.ps1 - edit before shipping._"
}

$known = @("feat","fix","perf","refactor","docs","test","chore","build","ci","wip")
$label = @{
    feat="Features"; fix="Fixes"; perf="Performance"; refactor="Refactoring";
    docs="Documentation"; test="Tests"; chore="Chores"; build="Build"; ci="CI";
    wip="WIP (squash or finish before release!)"; other="Other changes"
}
$buckets = @{}

$lines = git log --no-merges --reverse --pretty=format:'%s (%h)' $Range
foreach ($line in $lines) {
    $b = "other"
    if ($line -match '^([a-z]+)(\([a-zA-Z0-9_-]+\))?!?: ') {
        $t = $Matches[1]
        if ($known -contains $t) { $b = $t }
    }
    if (-not $buckets.ContainsKey($b)) { $buckets[$b] = @() }
    $buckets[$b] += $line
}

$order = @("feat","fix","perf","refactor","docs","test","build","ci","chore","other","wip")
foreach ($b in $order) {
    if ($buckets.ContainsKey($b)) {
        Write-Output ""
        Write-Output ("## " + $label[$b])
        foreach ($entry in $buckets[$b]) { Write-Output ("- " + $entry) }
    }
}
Write-Output ""
exit 0
