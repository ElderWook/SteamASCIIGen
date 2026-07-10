#!/usr/bin/env bash
# File integrity check (OGDK) - detects the corruption signatures we have actually seen:
#   1. NUL bytes inside tracked text files  (MSYS2/NTFS zero-filled-tail corruption)
#   2. Truncated source files               (sync-layer truncation; .py checked by compile)
#   3. Git object-store corruption          (git fsck)
# Run BEFORE committing after heavy agent writes, and any time files look suspicious.
# Twin: verify-file-integrity.ps1 (keep behavior identical - see tools/README.md).
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
issues=0
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
echo "  File Integrity Check (OGDK)         "
echo "======================================"

# Check 1: git object store
if [ -d .git ]; then
    if git fsck --no-progress >/dev/null 2>&1; then
        pass "git fsck: object store healthy"
    else
        fail "git fsck reports corruption - do NOT commit; investigate .git"
    fi
else
    warn "not a git repo - skipping fsck"
fi

# Check 2: NUL bytes in tracked text files (zero-filled tails)
TEXT_RE='\.(md|txt|py|js|ts|jsx|tsx|json|ps1|sh|bat|cs|cpp|c|h|hpp|ini|yml|yaml|toml|svelte|dart|cjs|mjs|html|css|xml|sql|uproject|uplugin|gitignore|gitattributes)$'
tracked_files=$(git ls-files 2>/dev/null | grep -E "$TEXT_RE" || true)

if [ -z "$tracked_files" ]; then
    warn "git ls-files returned no files. Falling back to local file system scan..."
    tracked_files=$(find . -type f \
        -not -path '*/.*' \
        -not -path './node_modules/*' \
        -not -path './dist/*' \
        -not -path './target/*' \
        -not -path './bin/*' \
        -not -path './obj/*' \
        -not -path './build/*' \
        -not -path './artifacts/*' \
        -not -path '*/__pycache__/*' \
        2>/dev/null | sed 's|^\./||' | grep -E "$TEXT_RE" || true)
fi

nul_hits=""
if [ -n "$tracked_files" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ -f "$f" ] || continue
        if LC_ALL=C grep -qaP '\x00' "$f" 2>/dev/null; then
            nul_hits="$nul_hits  $f"$'\n'
        fi
    done <<< "$tracked_files"
fi
if [ -n "$nul_hits" ]; then
    fail "NUL bytes found in text files (zero-fill corruption signature):"
    printf '%s' "$nul_hits"
else
    pass "no NUL bytes in tracked text files"
fi

# Check 3: Python files compile (catches mid-file truncation of .py).
# Find a python that ACTUALLY LAUNCHES - mirror the .ps1 twin, which probes
# python/py/python3 and confirms --version runs. Some systems have 'python' but
# no 'python3' (the old twin checked only python3 and silently skipped the gate).
PYCMD=""
for cand in python3 python py; do
    if command -v "$cand" >/dev/null 2>&1 && "$cand" --version >/dev/null 2>&1; then
        PYCMD="$cand"; break
    fi
done
py_bad=""
py_files=$(git ls-files '*.py' 2>/dev/null || true)
if [ -z "$py_files" ] && [ -n "$tracked_files" ]; then
    py_files=$(echo "$tracked_files" | grep -E '\.py$' || true)
fi
if [ -z "$py_files" ]; then
    pass "no tracked .py files (compile check not applicable)"
elif [ -z "$PYCMD" ]; then
    warn "no WORKING python found - .py truncation check SKIPPED (install python3 to restore this gate)"
else
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ -f "$f" ] || continue
        "$PYCMD" -m py_compile "$f" 2>/dev/null || py_bad="$py_bad  $f"$'\n'
    done <<< "$py_files"
    if [ -n "$py_bad" ]; then
        fail "Python files do not compile (possible truncation):"
        printf '%s' "$py_bad"
    else
        pass "all tracked .py files compile ($PYCMD)"
    fi
fi

# Check 3b: shell scripts parse via bash -n (catches mid-file truncation of .sh).
# Platform difference (documented): the .ps1 twin validates *.ps1 via the PowerShell
# parser instead; each platform parses what it can execute.
sh_bad=""
sh_files=$(git ls-files '*.sh' 2>/dev/null || true)
if [ -z "$sh_files" ] && [ -n "$tracked_files" ]; then
    sh_files=$(echo "$tracked_files" | grep -E '\.sh$' || true)
fi
if [ -n "$sh_files" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ -f "$f" ] || continue
        bash -n "$f" 2>/dev/null || sh_bad="$sh_bad  $f"$'\n'
    done <<< "$sh_files"
fi
if [ -n "$sh_bad" ]; then
    fail "shell scripts do not parse (possible truncation):"
    printf '%s' "$sh_bad"
else
    pass "all tracked .sh files parse (bash -n)"
fi

# Check 4b: EOF sentinel on tools scripts. A truncated script can PASS syntax
# checks if the cut lands inside a comment (2026-06-12 lesson - bash -n approved
# a script missing its last 30 lines). Every tools script must therefore END
# with an explicit final statement: a line starting with 'exit' or '# EOF'.
sent_bad=""
sent_count=0
sent_files=$(git ls-files 'tools/*.ps1' 'tools/*.sh' 2>/dev/null || true)
if [ -z "$sent_files" ] && [ -n "$tracked_files" ]; then
    sent_files=$(echo "$tracked_files" | grep -E '^tools/[^/]+\.(ps1|sh)$' || true)
fi
if [ -n "$sent_files" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ -f "$f" ] || continue
        sent_count=$((sent_count+1))
        last="$(grep -v '^[[:space:]]*$' "$f" | tail -1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        case "$last" in
            exit|exit\ *|'# EOF') ;;
            *) sent_bad="$sent_bad  $f"$'\n' ;;
        esac
    done <<< "$sent_files"
fi
if [ "$sent_count" -eq 0 ]; then
    pass "no tools scripts tracked (EOF sentinel not applicable)"
elif [ -n "$sent_bad" ]; then
    fail "tools script(s) missing EOF sentinel - last non-blank line must start with 'exit' or be '# EOF' (truncation guard):"
    printf '%s' "$sent_bad"
else
    pass "all tools scripts end with an EOF sentinel"
fi

# Check 4: tracked text files ending mid-line (no trailing newline = truncation smell)
noeol=""
eol_files=$(git ls-files 2>/dev/null | grep -E '\.(py|sh|md)$' || true)
if [ -z "$eol_files" ] && [ -n "$tracked_files" ]; then
    eol_files=$(echo "$tracked_files" | grep -E '\.(py|sh|md)$' || true)
fi
if [ -n "$eol_files" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ -f "$f" ] || continue
        [ -s "$f" ] || continue
        [ "$(tail -c 1 "$f" | od -An -tx1 | tr -d ' \n')" != "0a" ] && noeol="$noeol  $f"$'\n'
    done <<< "$eol_files"
fi
if [ -n "$noeol" ]; then
    warn "files lacking trailing newline (verify they are complete):"
    printf '%s' "$noeol"
else
    pass "all checked files end with newline"
fi

echo "--------------------------------------"
if [ "$issues" -eq 0 ]; then
    echo "  INTEGRITY OK - safe to commit"
else
    echo "  $issues ISSUE(S) - do NOT commit until resolved"
fi
exit "$issues"
