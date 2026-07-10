#!/usr/bin/env bash
# Draft release notes from git history (tag-to-tag). Markdown on stdout - redirect
# where you want it; the tool never writes files. Twin: release-notes.ps1.
#
# Usage (from a project root, native shell - NEVER through a sync-layer mount):
#   ./tools/release-notes.sh                  # latest tag .. HEAD
#   ./tools/release-notes.sh v0.1.0           # v0.1.0 .. HEAD
#   ./tools/release-notes.sh v0.1.0 v0.2.0    # tag to tag
#   ./tools/release-notes.sh > docs/workflow/RELEASE-NOTES-v0.2.0.md   # then EDIT it
#
# Zero commit-message discipline required: subjects with a 'type:' prefix
# (feat/fix/docs/...) are grouped; everything else lands under 'Other changes'.
# History stays in git (AI-PARITY golden rule); this only DRAFTS - a human edits
# the output before it ships. No tags yet -> full history is summarized.
set -u

FROM="${1:-}"
TO="${2:-HEAD}"

git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }

if [ -z "$FROM" ]; then
    FROM="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi
if [ -n "$FROM" ]; then RANGE="$FROM..$TO"; else RANGE="$TO"; fi

COUNT="$(git rev-list --no-merges --count $RANGE 2>/dev/null || echo 0)"
[ "$COUNT" -gt 0 ] || { echo "no commits in range '$RANGE'" >&2; exit 1; }

echo "# Release notes - $TO ($(date +%F))"
if [ -n "$FROM" ]; then
    echo
    echo "_${COUNT} commits since ${FROM}. Drafted by tools/release-notes.sh - edit before shipping._"
else
    echo
    echo "_${COUNT} commits, full history (no tags found). Drafted by tools/release-notes.sh - edit before shipping._"
fi

git log --no-merges --reverse --pretty=format:'%s (%h)' $RANGE | awk '
function bucket(line,   t, i) {
    if (match(line, /^[a-z]+(\([a-zA-Z0-9_-]+\))?!?: /)) {
        t = substr(line, 1, index(line, ":") - 1)
        sub(/\(.*/, "", t); sub(/!$/, "", t)
        for (i = 1; i <= n; i++) if (t == known[i]) return t
    }
    return "other"
}
BEGIN {
    n = split("feat fix perf refactor docs test chore build ci wip", known, " ")
    label["feat"]="Features";       label["fix"]="Fixes"
    label["perf"]="Performance";    label["refactor"]="Refactoring"
    label["docs"]="Documentation";  label["test"]="Tests"
    label["chore"]="Chores";        label["build"]="Build"
    label["ci"]="CI";               label["wip"]="WIP (squash or finish before release!)"
    label["other"]="Other changes"
}
{ b = bucket($0); out[b] = out[b] "\n- " $0 }
END {
    order = "feat fix perf refactor docs test build ci chore other wip"
    m = split(order, ord, " ")
    for (i = 1; i <= m; i++) {
        b = ord[i]
        if (b in out) printf "\n## %s\n%s\n", label[b], out[b]
    }
}'
echo
exit 0
