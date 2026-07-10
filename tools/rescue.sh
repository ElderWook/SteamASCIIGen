#!/usr/bin/env bash
# OGDK - RESCUE. The symmetric twin of checkpoint: checkpoint SAVES, rescue RESTORES.
# One command to get back to your last safe save without ever losing work:
#   - a half-finished merge/rebase -> cancelled (returns to the last commit)
#   - uncommitted changes          -> safely shelved (git stash), tree returns to HEAD
#   - already clean                -> nothing to do
# It NEVER force-pushes, NEVER resets --hard, NEVER deletes commits. Run it from a
# native shell when things feel tangled and you just want to be safe again.
# Twin: rescue.ps1.
#
# Usage: ./tools/rescue.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "======================================"
echo "  RESCUE - get back to safe (OGDK)    "
echo "======================================"

GIT_DIR="$(git rev-parse --git-dir 2>/dev/null)" || { echo "[FAIL] not a git repository"; exit 1; }

# 1. A merge or rebase mid-flight is the scariest state for a beginner. Aborting it
#    returns the working tree to the last committed state - no committed work is lost.
if [ -f "$GIT_DIR/MERGE_HEAD" ]; then
    if git merge --abort 2>/dev/null; then
        echo "[OK] cancelled the in-progress merge - you are back at your last commit, safe."
    else
        echo "[WARN] could not auto-cancel the merge. Run 'git merge --abort' yourself, or ask a human."
        exit 1
    fi
    echo "--------------------------------------"; echo "  RESCUE DONE"; exit 0
fi
if [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ]; then
    if git rebase --abort 2>/dev/null; then
        echo "[OK] cancelled the in-progress rebase - you are back at your last commit, safe."
    else
        echo "[WARN] could not auto-cancel the rebase. Run 'git rebase --abort' yourself, or ask a human."
        exit 1
    fi
    echo "--------------------------------------"; echo "  RESCUE DONE"; exit 0
fi

# 2. Uncommitted changes: shelve them (tracked AND untracked) so the tree is clean at
#    your last save, but NOTHING is thrown away - stash is fully recoverable.
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    stamp="$(date '+%Y-%m-%d %H:%M')"
    if git stash push --include-untracked -m "rescue $stamp" >/dev/null 2>&1; then
        echo "[OK] your in-progress changes are safely shelved (nothing was deleted)."
        echo "     Your project is now back at your last save:"
        echo "       $(git log -1 --format='%h %s' 2>/dev/null)"
        echo
        echo "     Bring the shelved work back any time:   git stash pop"
        echo "     See everything you have shelved:        git stash list"
    else
        echo "[WARN] could not shelve changes. Run 'git status' and read it, or ask a human."
        exit 1
    fi
else
    echo "[PASS] nothing to rescue - your project is already clean at a save point:"
    echo "       $(git log -1 --format='%h %s' 2>/dev/null)"
fi

echo "--------------------------------------"
echo "  RESCUE DONE"
exit 0
