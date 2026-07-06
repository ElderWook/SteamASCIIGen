#!/usr/bin/env bash
# OGDK - turn a snag into a ready-to-paste LESSONS.md entry. The kit's whole premise
# is that friction the system did not prevent should be captured - but writing a
# LESSONS entry by hand is exactly the chore a beginner skips. This makes it a
# 10-second job: describe what went wrong, and it prints a formatted draft (plus
# harmless environment context) you can drop straight into LESSONS.md.
# Writes nothing itself (the draft goes to stdout - redirect or copy it). Twin: report-snag.ps1.
#
# Usage: ./tools/report-snag.sh "the gate failed after I edited app.py"
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DESC="${*:-<describe what you were doing and what went wrong>}"
today="$(date +%Y-%m-%d)"
os="$(uname -s -r 2>/dev/null || echo unknown)"
gitver="$(git --version 2>/dev/null || echo 'git not found')"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo n/a)"
lastcommit="$(git log -1 --format='%h %s' 2>/dev/null || echo n/a)"
kitver="n/a"
[ -f tools/KIT-VERSION ] && kitver="$(head -1 tools/KIT-VERSION)"

# Guidance to stderr so stdout stays a clean, redirectable draft (release-notes pattern).
echo "Paste the block below into docs/LESSONS.md (a project) or LESSONS.md (the kit)." 1>&2
echo "Fill the <bits>; the retro will turn it into a permanent fix. ----------------" 1>&2

printf '## %s <one-line title for the snag>\n' "$today"
printf '**What happened:** %s\n' "$DESC"
printf '**Environment:** %s | %s | branch: %s | last commit: %s | KIT-VERSION: %s\n' "$os" "$gitver" "$branch" "$lastcommit" "$kitver"
printf '**Root cause:** <fill in if known - or leave it for the retro>\n'
printf '**Proposed fix:** <what would have prevented this?>\n'
printf '**Status:** OPEN\n'
exit 0
