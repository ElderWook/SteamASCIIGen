#!/usr/bin/env bash
# Git identity history check (OGDK). Scans author + committer name/email across
# ALL commit objects in history against the gitignored tools/PRIVATE-MARKERS.list
# and FAILS if any marker appears. Closes the gap content scans cannot see:
# check-kit-docs (check 8) scans tracked FILE CONTENT, but author/committer metadata
# travels in every commit object and is invisible to it (the "personal email leaked
# via commit author identity" lesson). Output reports marker INDEX only, never text.
# Graceful skip (exit 0) when git or the markers list is absent. Twin: check-git-identity.ps1.
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$KIT" || exit 1
issues=0

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
echo "  Git Identity History Check (OGDK)   "
echo "======================================"

# Preconditions: git present and inside a work tree. Skip (not fail) otherwise so
# fresh clones / non-git copies do not block on a check they cannot run.
command -v git >/dev/null 2>&1 || { echo "[WARN] git not found - identity history scan skipped"; exit 0; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "[WARN] not a git repo - identity history scan skipped"; exit 0; }

# Markers: gitignored, per-owner. Absent = skip (same posture as check-kit-docs 8).
markfile="tools/PRIVATE-MARKERS.list"
if [ ! -f "$markfile" ]; then
    echo "[WARN] tools/PRIVATE-MARKERS.list not found - identity scan skipped (seed yours: see tools/README.md)"
    exit 0
fi

markers=()
while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    trimmed="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$trimmed" in ''|'#'*) continue ;; esac
    markers+=("$(printf '%s' "$trimmed" | tr '[:upper:]' '[:lower:]')")
done < "$markfile"

if [ "${#markers[@]}" -eq 0 ]; then
    echo "[WARN] PRIVATE-MARKERS.list has no markers - identity scan skipped"
    exit 0
fi

# One line per commit across ALL refs: <shorthash>|<an>|<ae>|<cn>|<cE>. Emails/names
# never contain '|', so trimming up to the first '|' isolates the hash; the rest is
# the identity blob. --all covers every local ref, not just HEAD.
ident_ok=1
commit_count=0
while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    commit_count=$((commit_count+1))
    hash="${entry%%|*}"
    blob="$(printf '%s' "${entry#*|}" | tr '[:upper:]' '[:lower:]')"
    midx=0
    for m in "${markers[@]}"; do
        midx=$((midx+1))
        case "$blob" in
            *"$m"*)
                echo "[FAIL] commit $hash author/committer identity contains private marker #$midx (text withheld - marker #$midx in your PRIVATE-MARKERS.list)"
                issues=$((issues+1))
                ident_ok=0
                break
                ;;
        esac
    done
done < <(git log --all --format='%h|%an|%ae|%cn|%cE' 2>/dev/null)

if [ "$ident_ok" = 1 ]; then
    echo "[PASS] no private markers in author/committer identity ($commit_count commit(s), ${#markers[@]} marker(s) checked)"
fi

echo "--------------------------------------"
if [ "$issues" -eq 0 ]; then
    echo "  GIT IDENTITY OK"
else
    echo "  $issues COMMIT(S) WITH LEAKED IDENTITY"
    echo "  Rewrite author/committer metadata before pushing to a public remote."
    echo "  (git filter-repo --mailmap / rebase reset-author; re-tag; force-push in an unlinked window.)"
fi
echo "--------------------------------------"
exit "$issues"
# EOF
