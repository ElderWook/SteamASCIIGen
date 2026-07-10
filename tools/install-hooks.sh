#!/usr/bin/env bash
# Install the OGDK git hooks for THIS clone by pointing core.hooksPath at the
# tracked tools/hooks directory, and make the hooks executable. pre-commit blocks a
# private-marker leak (content or git identity) before it enters a commit; pre-push
# rescans commit-history identity before it leaves the machine. Per-clone and
# idempotent (core.hooksPath is local config). Undo: git config --unset core.hooksPath.
# Twin: install-hooks.ps1.
set -u
repoRoot="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repoRoot" || exit 1

echo "======================================"
echo "  Install Git Hooks (OGDK)            "
echo "======================================"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "[FAIL] not a git repository - run from inside the repo"
    exit 1
fi
if [ ! -f tools/hooks/pre-push ] && [ ! -f tools/hooks/pre-commit ]; then
    echo "[FAIL] no hooks found in tools/hooks/ - nothing to install"
    exit 1
fi
chmod +x tools/hooks/pre-push tools/hooks/pre-commit 2>/dev/null || true
if git config core.hooksPath tools/hooks; then
    echo "[PASS] core.hooksPath -> tools/hooks (pre-commit + pre-push privacy guards active)"
    echo "       pre-commit blocks a leak before it enters a commit; pre-push rescans history."
    echo "       Undo: git config --unset core.hooksPath"
    code=0
else
    echo "[FAIL] could not set core.hooksPath"
    code=1
fi
exit "$code"
# EOF
