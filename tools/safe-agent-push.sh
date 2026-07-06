#!/usr/bin/env bash
# tools/safe-agent-push.sh
# Automated, gate-verified git commit & push for an AI agent that has NATIVE git access
# (NOT a synced-mount/sandbox agent - those must never run git). This is the local-access
# SAVE+push path of the git lifecycle (docs-template/workflow/GIT-LIFECYCLE.md): it runs the
# checkpoints in order and ABORTS - never forces - on any failure or divergence, exactly as
# gitwalk requires.
#   C0 ARRIVE : verify-path-health + sync-repo (a STOP/exit 2 aborts -> hand back to a human)
#   C2 SAVE   : gate (exit 0 or no commit) -> git add -A -> commit -> push (current branch's upstream)
# For a panic save of a half-broken tree use checkpoint.sh, not this. Twin: safe-agent-push.ps1.
#   Usage: ./tools/safe-agent-push.sh ["commit message"]
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$dir/.." && pwd)"

# Guard: this runs git, so it must NOT run through a synced/emulated mount (gitwalk: git only
# in a native shell). sync-repo enforces this too, but fail fast and clearly here, before any
# git or sub-tool runs.
case "$repo" in
    /sessions/*/mnt/*|/mnt/c/*|/mnt/d/*|*/.gvfs/*)
        echo "[STOP] $repo looks like a synced/emulated mount - safe-agent-push runs git and must" >&2
        echo "       run in a NATIVE shell only. Aborting; no git ran. (Let the human push, or use" >&2
        echo "       a host-shell. gitwalk: never git through a mount.)" >&2
        exit 2 ;;
esac

echo "=== Step 1/4: path health (C0) ==="
"$dir/verify-path-health.sh"

echo "=== Step 2/4: safe arrival / sync (C0 ARRIVE) ==="
"$dir/sync-repo.sh"

echo "=== Step 3/4: the gate (C2) ==="
"$dir/gate.sh"

echo "=== Step 4/4: save + push (C2 SAVE) ==="
msg="${1:-chore: agent commit (gate verified)}"
git -C "$repo" add -A
if git -C "$repo" diff --cached --quiet; then
    echo "[INFO] nothing staged to commit - pushing any unpushed commits."
else
    git -C "$repo" commit -m "$msg"
fi
git -C "$repo" push
echo "=== SAFE-AGENT-PUSH COMPLETE ==="
exit 0
# EOF
