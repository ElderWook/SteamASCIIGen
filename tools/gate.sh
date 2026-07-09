#!/usr/bin/env bash
# THE GATE - one command answers "did I break it?". Copied into each project by
# new-project; fill in the project section. Twin: gate.ps1.
# Exit 0 = safe to commit. Anything else = fix first.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
total=0
step() { echo; echo "=== GATE: $1 ==="; }
if [ -z "${OGDK_BANNER:-}" ]; then
cat <<'OGDKART'
   ___   ____ ____  _  __
  / _ \ / ___|  _ \| |/ /
 | | | | |  _| | | | ' /
 | |_| | |_| | |_| | . \
  \___/ \____|____/|_|\_\
OGDKART
fi
export OGDK_BANNER=1

step "file integrity"
bash "$DIR/verify-file-integrity.sh" || total=$((total+$?))

step "reference coverage"
bash "$DIR/check-reference-coverage.sh" || total=$((total+$?))

step "git identity"
bash "$DIR/check-git-identity.sh" || total=$((total+$?))

step "project checks"
# Vite/Svelte app: a clean production build is the smoke test (no unit tests yet).
npm run build || total=$((total+1))

echo
echo "======================================"
if [ "$total" -eq 0 ]; then echo "  GATE PASSED - safe to commit"; else echo "  GATE FAILED ($total) - do not commit"; fi
exit "$total"
