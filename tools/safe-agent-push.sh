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
#   Usage: ./tools/safe-agent-push.sh ["commit message"] [path1] [path2]...
#          ./tools/safe-agent-push.sh --push-only
# --push-only: sync-guard + push ONLY (skips the gate + add/commit) - for pushing commits that
# were already gate-verified when created, when THIS env's gate now fails for orthogonal reasons
# (a missing optional dep, a heavy project build, an already-public historical identity leak).
# It still runs path-health + sync-repo and still honors the pre-push hook: it REFUSES, never
# forces, never --no-verify.
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

# Parse flags: --push-only anywhere in the args toggles push-only mode; everything else stays
# positional (commit message + optional paths) for full mode.
push_only=0
args=()
for a in "$@"; do
    if [ "$a" = "--push-only" ]; then push_only=1; else args+=("$a"); fi
done
set -- ${args[@]+"${args[@]}"}
if [ "$push_only" = 1 ]; then stepN=3; else stepN=4; fi

echo "=== Step 1/$stepN: path health (C0) ==="
"$dir/verify-path-health.sh"

echo "=== Step 2/$stepN: safe arrival / sync (C0 ARRIVE) ==="
"$dir/sync-repo.sh"

if [ "$push_only" = 1 ]; then
    # PUSH-ONLY: the commits were gate-verified when created; skip the gate + add/commit and
    # just push already-committed history. For when THIS env's gate fails for orthogonal reasons
    # (a missing dep, a heavy project build, an already-public historical identity). The pre-push
    # hook still runs, so a genuine identity leak is REFUSED here - never forced, never bypassed.
    if [ $# -gt 0 ]; then echo "[INFO] --push-only neither stages nor commits; ignoring args: $*"; fi
    echo "=== Step 3/$stepN: push only (gate + add/commit skipped) ==="
    ahead="$(git -C "$repo" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)"
    if [ "${ahead:-0}" = 0 ]; then
        echo "[INFO] no local commits ahead of upstream - nothing to push."
        exit 0
    fi
    git -C "$repo" diff --quiet || echo "[NOTE] uncommitted working-tree changes are NOT pushed (push-only pushes committed history)."
    git -C "$repo" push
    echo "=== SAFE-AGENT-PUSH (push-only) COMPLETE - pushed $ahead commit(s) ==="
    exit 0
fi

echo "=== Step 3/$stepN: the gate (C2) ==="
"$dir/gate.sh"

echo "=== Step 4/$stepN: save + push (C2 SAVE) ==="
msg="${1:-chore: agent commit (gate verified)}"
shift || true
if [ $# -gt 0 ]; then
    git -C "$repo" add "$@"
else
    untracked_size=$(git -C "$repo" ls-files --others --exclude-standard -z | xargs -0 -r stat -c %s 2>/dev/null | awk '{s+=$1} END {print s}')
    if [ "${untracked_size:-0}" -gt 104857600 ]; then
        echo "[STOP] Untracked files exceed 100MB. Unsafe for a blanket 'git add -A'. Stage selectively, then pass paths to safe-agent-push." >&2
        exit 1
    fi
    git -C "$repo" add -A
fi
if git -C "$repo" diff --cached --quiet; then
    echo "[INFO] nothing staged to commit - pushing any unpushed commits."
else
    git -C "$repo" commit -m "$msg"
fi
git -C "$repo" push
echo "=== SAFE-AGENT-PUSH COMPLETE ==="
exit 0
# EOF
