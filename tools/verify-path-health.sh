#!/usr/bin/env bash
# Environment health check (OGDK) - Linux twin of verify-path-health.ps1
# The Windows script guards against MSYS2/WSL PATH poisoning. On Linux the
# equivalent hazard is the reverse: writing to a shared NTFS partition from
# Linux. Run at the START of every AI agent session.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
issues=0
pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; issues=$((issues+1)); }

# First-init bootstrap: in the kit repo (where user-notes.md lives), auto-create the
# operator's PRIVATE notes file if missing. It is gitignored - personal/machine/
# project specifics go there, never into tracked files. No-op in project repos.
if [ -f "$REPO_ROOT/user-notes.md" ] && [ ! -f "$REPO_ROOT/user-notes.local.md" ]; then
    cat > "$REPO_ROOT/user-notes.local.md" <<'SEEDEOF'
# user-notes.local.md - YOUR private notes (gitignored, never committed)

> Auto-created on first run of verify-path-health. Personal, machine, and
> project specifics live HERE: repo paths, usernames, build commands, quirks.
> AI agents in this kit route personal notes to this file automatically.
> The tracked user-notes.md stays generic for everyone. Make this one yours.

## My repos & locations

| Repo | Path | What |
|------|------|------|
|      |      |      |

## My machine setup (auth, OS notes, identity)

## My project build & run commands

SEEDEOF
    printf '[INIT] created user-notes.local.md (your private, gitignored notes file)\n'
fi

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
echo "  Environment Health Check (OGDK)     "
echo "======================================"
echo

# Check 1: repo filesystem - NTFS from Linux is the dual-boot corruption hazard
fstype="$(stat -f -c %T "$REPO_ROOT" 2>/dev/null || echo unknown)"
case "$fstype" in
    ntfs|fuseblk|ntfs3)
        fail "Repo is on an NTFS mount ($fstype). Do NOT run agent file writes here from Linux - work on a native (ext4/btrfs) clone and sync via git push/pull." ;;
    unknown)
        warn "Could not determine filesystem type for $REPO_ROOT" ;;
    *)
        pass "Repo filesystem: $fstype (native)" ;;
esac

# Check 2: git present + identity
if ! command -v git >/dev/null; then
    fail "git not found in PATH"
else
    pass "git -> $(command -v git)"
    if [ -z "$(git config user.email || true)" ]; then
        fail "git identity not set (git config --global user.name / user.email)"
    else
        email="$(git config user.email)"
        pass "git identity: $email"
        if [[ ! "$(echo "$email" | tr '[:upper:]' '[:lower:]')" =~ noreply ]]; then
            warn "git email is a public/personal address ($email). Consider using a GitHub noreply email to protect your privacy."
        fi
    fi
fi

# Check 2b: privacy guard - hooks installed + markers present (the leak backstop)
hookspath="$(git config core.hooksPath 2>/dev/null || true)"
if [ "$hookspath" = "tools/hooks" ]; then
    pass "git hooks active (core.hooksPath -> tools/hooks: pre-commit + pre-push)"
else
    warn "git hooks not installed (optional - the privacy guard for repos you will share publicly). Arm any time: ./tools/install-hooks.sh"
fi
if [ -f "$REPO_ROOT/tools/PRIVATE-MARKERS.list" ]; then
    pass "PRIVATE-MARKERS.list present (privacy scan armed)"
else
    warn "tools/PRIVATE-MARKERS.list not set up (optional - only needed before you make a repo public; see tools/README.md)"
fi

# Check 3: git-lfs (required for game-track repos)
if command -v git-lfs >/dev/null; then
    pass "git-lfs -> $(command -v git-lfs)"
else
    warn "git-lfs not installed (required before committing any .uasset in game repos). Arch: sudo pacman -S git-lfs && git lfs install"
fi

# Check 4: line-ending config - on Linux, autocrlf must NOT be true
autocrlf="$(git config core.autocrlf || echo unset)"
if [ "$autocrlf" = "true" ]; then
    fail "core.autocrlf=true on Linux will mangle files. Use: git config --global core.autocrlf input (line-ending policy belongs in .gitattributes anyway)"
else
    pass "core.autocrlf: $autocrlf"
fi

# Check 5: node (app track only)
if command -v node >/dev/null; then
    pass "node -> $(command -v node) ($(node --version))"
else
    warn "node not found (only matters for app-track projects)"
fi

# Provenance: which kit commit this repo's tools came from (projects only;
# stamped by new-project/propagate-tools - absent in the kit itself and in
# repos that have not re-propagated yet).
if [ -f "$REPO_ROOT/tools/KIT-VERSION" ]; then
    printf '[INFO] tools provenance: %s\n' "$(head -1 "$REPO_ROOT/tools/KIT-VERSION")"
fi

echo
echo "--------------------------------------"
if [ "$issues" -eq 0 ]; then
    echo "  ALL CHECKS PASSED - safe to run AI agents"
else
    echo "  $issues ISSUE(S) FOUND - resolve before running AI agents"
fi
echo "--------------------------------------"
exit "$issues"
