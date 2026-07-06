#!/usr/bin/env bash
# OGDK - safe arrival protocol. Run at SESSION START before any work.
# Classifies the repo's relationship to its remote and either fast-forwards
# (the only conflict-impossible auto-action) or STOPS with plain-language
# instructions. It NEVER auto-merges and NEVER creates a conflict state.
# Twin: sync-repo.ps1.
#
# Exit codes: 0 = safe to work · 2 = action required before working.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
info() { printf '[INFO] %s\n' "$1"; }
stop() { printf '[STOP] %s\n' "$1"; }

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
echo "  Sync Check - safe arrival (OGDK)    "
echo "======================================"

# Guard: never run git through a synced mount (AI-PARITY SS4) - sandboxed
# sessions see this repo at a mount path; git here can corrupt the index.
case "$PWD" in
    /sessions/*/mnt/*|/mnt/c/*|/mnt/d/*)
        stop "this looks like a synced/emulated mount ($PWD) - git must run in a NATIVE shell only. Ask the human, or use a host-shell MCP server (docs/workflow/MCP.md SS3)."
        exit 2 ;;
esac

GIT_DIR="$(git rev-parse --git-dir 2>/dev/null)" || { stop "not a git repository"; exit 2; }

# 0. A merge/rebase is already in progress - do not dig deeper.
if [ -f "$GIT_DIR/MERGE_HEAD" ]; then
    stop "a MERGE is in progress (probably from an earlier 'git pull')."
    echo "       Finish it:  resolve files 'git status' lists, then 'git add <file>' + 'git commit'"
    echo "       Or undo it: git merge --abort   (returns to the state before the pull)"
    echo "       Kit-files rule: a conflict in tools/* on a propagated file is NOT a real"
    echo "       merge - take either side, then re-run propagate-tools from the kit."
    exit 2
fi
if [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ]; then
    stop "a REBASE is in progress. Finish: 'git rebase --continue' - or undo: 'git rebase --abort'."
    exit 2
fi

# 1. Fetch - pure information, mutates nothing.
if ! git fetch --quiet 2>/dev/null; then
    warn "could not reach the remote (offline? auth?). Working with local state only - re-run when connected."
    exit 0
fi

# 2. Upstream?
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    warn "current branch has no upstream - nothing to sync against (set one: git push -u origin <branch>)."
    exit 0
fi

dirty=0
[ -n "$(git status --porcelain 2>/dev/null)" ] && dirty=1
counts="$(git rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null || echo '0	0')"
ahead="$(printf '%s' "$counts" | awk '{print $1}')"
behind="$(printf '%s' "$counts" | awk '{print $2}')"

# 3. Classify - worst states first.
if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
    stop "DIVERGED: this machine and the remote each have commits the other lacks ($ahead local, $behind remote)."
    echo "       This happens when two machines commit without pulling first."
    echo "       Option A (usual):  git pull --no-rebase   - merges; if it conflicts, see the kit-files rule"
    echo "       Option B (linear): git pull --rebase      - replays your commits on top"
    echo "       (plain 'git pull' on modern git refuses divergent branches until you pick one)"
    echo "       Kit-files rule: conflicts in tools/* on propagated files are not real merges -"
    echo "       take either side ('git checkout --ours <file>', 'git add <file>'), finish the"
    echo "       merge, then re-run propagate-tools from the kit. The kit is the source of truth."
    exit 2
fi
if [ "$dirty" -eq 1 ] && [ "$behind" -gt 0 ]; then
    stop "uncommitted changes AND the remote is $behind commit(s) ahead. Pulling now risks tangling them."
    echo "       First:  git add -A && git commit -m 'wip: <what you were doing>'   (or ./tools/checkpoint.sh)"
    echo "       Then re-run this script - it will fast-forward cleanly."
    exit 2
fi
if [ "$behind" -gt 0 ]; then
    if git merge --ff-only '@{upstream}' >/dev/null 2>&1; then
        pass "fast-forwarded $behind commit(s) from the remote - you are current"
    else
        stop "fast-forward unexpectedly failed - run 'git status' and read it; do not force anything."
        exit 2
    fi
else
    pass "no new remote commits"
fi
if [ "$ahead" -gt 0 ]; then
    info "$ahead local commit(s) not pushed yet - 'git push' when ready (or at session end)"
fi
if [ "$dirty" -eq 1 ]; then
    warn "uncommitted changes present. If YOU just made them: fine, carry on. If you did NOT"
    echo "       expect them: a previous session may have been interrupted - check docs/STATUS.md"
    echo "       for an '## In-flight' section before touching anything (session-start step 5)."
fi
last_subject="$(git log -1 --format='%s' 2>/dev/null)"
case "$last_subject" in
    wip:*)
        warn "last commit is a 'wip:' checkpoint - a previous session ended mid-task."
        echo "       Reconstruct from: git show --stat HEAD + docs/STATUS.md In-flight + the active plan."
        ;;
esac

echo "--------------------------------------"
echo "  SAFE TO WORK"
exit 0
