#!/usr/bin/env bash
# Reference coverage check (OGDK) - makes the documentation graduation rule mechanical.
# Reads docs/reference/COVERAGE.md and verifies, per row:
#   1. status=current/stale rows: the page file exists
#   2. staleness: last commit touching source path(s) vs last commit touching the page
#      (source newer than page -> STALE)
#   3. missing rows are counted as backlog (warn, not fail)
# Run at session end alongside verify-file-integrity. Twin: check-reference-coverage.ps1.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
MANIFEST="docs/reference/COVERAGE.md"
issues=0; backlog=0; stale=0
pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; issues=$((issues+1)); }

if [ -z "${OGDK_BANNER:-}" ]; then
cat <<'OGDKART'
   ___   ____ ____  _  __
  / _ \ / ___|  _ \| |/ /
 | | | | |  _| | | | ' /
 | |_| | |_| | |_| | . \
  \___/ \____|____/|_|\_\
OGDKART
fi
echo "======================================"
echo "  Reference Coverage Check (OGDK)     "
echo "======================================"

[ -f "$MANIFEST" ] || { fail "no $MANIFEST - reference tier not initialized"; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 && HAVE_GIT=1 || HAVE_GIT=0
[ "$HAVE_GIT" = 1 ] || warn "not a git repo - staleness checks skipped"

# Parse manifest table rows: | Component | sources | page | status |
while IFS='|' read -r _ comp src page status _; do
    comp="$(echo "$comp" | xargs)"; src="$(echo "$src" | xargs)"
    page="$(echo "$page" | xargs)"; status="$(echo "$status" | xargs | tr 'A-Z' 'a-z')"
    case "$comp" in ""|Component|_none*|---*|:---*) continue ;; esac
    # status may carry a trailing note, e.g. "planned (spec ahead)"; match the leading
    # keyword only so a human annotation doesn't hard-fail the gate (2026-06-22 lesson).
    status_kw="${status%%[^a-z]*}"
    case "$status_kw" in
        planned) continue ;;
        missing) backlog=$((backlog+1)); continue ;;
        current|stale) ;;
        *) fail "$comp: unknown status '$status' in COVERAGE.md"; continue ;;
    esac
    pagefile="docs/reference/$page"
    if [ ! -f "$pagefile" ]; then
        fail "$comp: page $page listed as $status but file does not exist"
        continue
    fi
    if [ "$HAVE_GIT" = 1 ]; then
        page_ts=$(git log -1 --format=%ct -- "$pagefile" 2>/dev/null || echo 0)
        src_ts=0
        IFS=';' read -ra paths <<< "$src"
        for sp in "${paths[@]}"; do
            sp="$(echo "$sp" | xargs)"; [ -n "$sp" ] || continue
            t=$(git log -1 --format=%ct -- "$sp" 2>/dev/null || echo 0)
            [ "$t" -gt "$src_ts" ] && src_ts=$t
        done
        if [ "$src_ts" -gt "${page_ts:-0}" ] && [ "${page_ts:-0}" != 0 ]; then
            stale=$((stale+1))
            warn "STALE: $comp - source committed after page $page (update page or justify)"
        else
            pass "$comp -> $page"
        fi
    else
        pass "$comp -> $page (existence only)"
    fi
done < "$MANIFEST"

[ "$backlog" -gt 0 ] && warn "backlog: $backlog component(s) lack reference pages - see docs/reference/COVERAGE.md"

# Learning-loop nudge: count OPEN lessons (the kit-retro trigger, now mechanical)
if [ -f "docs/LESSONS.md" ]; then
    open_lessons=$(grep -c 'Status:.*OPEN' docs/LESSONS.md 2>/dev/null || true)  # no '|| echo 0': grep -c prints 0 AND exits 1 on no match (2026-06-11 lesson)
    open_lessons=${open_lessons:-0}
    if [ "$open_lessons" -ge 5 ]; then
        warn "$open_lessons OPEN lesson(s) in docs/LESSONS.md - run the kit-retro skill (threshold: 5)"
    elif [ "$open_lessons" -gt 0 ]; then
        printf '[INFO] %s OPEN lesson(s) in docs/LESSONS.md (kit-retro at 5)\n' "$open_lessons"
    fi
fi

# Handoff freshness: STATUS.md trailing HEAD by >3 days means sessions are
# committing without updating the handoff (session-end step 5 skipped)
if [ "$HAVE_GIT" = 1 ] && [ -f "docs/STATUS.md" ]; then
    status_ts=$(git log -1 --format=%ct -- docs/STATUS.md 2>/dev/null || echo 0)
    head_ts=$(git log -1 --format=%ct 2>/dev/null || echo 0)
    if [ "$status_ts" != 0 ] && [ "$head_ts" != 0 ] && [ $((head_ts - status_ts)) -gt 259200 ]; then
        warn "docs/STATUS.md last committed >3 days before HEAD - handoff may be stale (session-end step 5)"
    fi
fi

echo "--------------------------------------"
echo "  backlog (missing pages): $backlog   stale: $stale   hard issues: $issues"
if [ "$issues" -eq 0 ]; then
    echo "  COVERAGE OK$( [ $((backlog+stale)) -gt 0 ] && echo ' (with warnings - see above)')"
else
    echo "  FIX COVERAGE before archiving any plan"
fi
exit "$issues"
