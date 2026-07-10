#!/usr/bin/env bash
# OGDK - PANIC SAVE. One command, zero questions: stage everything, commit as a
# 'wip:' checkpoint, push. Designed for interruptions - phone rings, battery
# dies, usage limit hits, you have to leave NOW.
# A LOCAL commit is already a successful save: if the push fails (offline,
# remote moved), your work is safe and sync-repo sorts it out next session.
# Twin: checkpoint.ps1. Windows double-click shim: checkpoint.bat.
#
# Usage: ./tools/checkpoint.sh ["what I was doing"]
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
MSG="${1:-}"

echo "======================================"
echo "  CHECKPOINT - panic save (OGDK)      "
echo "======================================"

git rev-parse --git-dir >/dev/null 2>&1 || { echo "[FAIL] not a git repository"; exit 1; }

if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    ahead="$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)"
    if [ "${ahead:-0}" -gt 0 ]; then
        echo "[INFO] nothing new to commit, but $ahead commit(s) unpushed - pushing those."
    else
        echo "[PASS] nothing to save - tree clean and pushed. You're free."
        exit 0
    fi
else
    stamp="$(date '+%Y-%m-%d %H:%M')"
    subject="wip: checkpoint $stamp"
    [ -n "$MSG" ] && subject="$subject - $MSG"
    git add -A
    # Panic save: bypass the pre-commit cheap-integrity gate (a half-broken tree
    # must still be savable). The privacy scan in the hook always runs regardless.
    if OGDK_SKIP_INTEGRITY=1 git commit -m "$subject" >/dev/null 2>&1; then
        echo "[PASS] committed locally: $subject"
    else
        echo "[FAIL] commit failed - run 'git status' and read it"; exit 1
    fi
fi

if git push >/dev/null 2>&1; then
    echo "[PASS] pushed - work is safe on the remote. Go."
else
    echo "[WARN] push did not go through (offline, or the remote moved ahead)."
    echo "       YOUR WORK IS SAFE - it is committed locally. Next session,"
    echo "       run ./tools/sync-repo.sh and it will walk you through syncing."
fi
echo "--------------------------------------"
echo "  CHECKPOINT DONE"
exit 0
