#!/usr/bin/env bash
# Scaffold a reference page from COMPONENT-TEMPLATE.md and register it in COVERAGE.md.
# Makes the graduation rule one command: page + manifest row land together, so
# check-reference-coverage tracks the component immediately. Twin: new-reference-page.ps1.
#
# Usage (from the PROJECT root):
#   ./tools/new-reference-page.sh -n <page-slug> -c "<Component Title>" -s "<source/path[;more/paths]>"
# Example:
#   ./tools/new-reference-page.sh -n vote -c "Voting detector" -s "shared/logic/vote.py"
#
# Multiple source paths are ';'-separated (matches the COVERAGE.md parser).
# The page is created with status 'current' - FILL IT IN before committing;
# page and manifest row belong in the same commit as the component (AGENTS.md).
set -euo pipefail

NAME="" COMP="" SRC=""
usage() {
    echo "Usage: $0 -n <page-slug> -c \"<Component Title>\" -s \"<source/path[;more]>\"" >&2
}
while [ $# -gt 0 ]; do
    case "$1" in
        -n|--name)      NAME="$2"; shift 2 ;;
        -c|--component) COMP="$2"; shift 2 ;;
        -s|--source)    SRC="$2";  shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
    esac
done
[ -n "$NAME" ] && [ -n "$COMP" ] && [ -n "$SRC" ] || { usage; exit 1; }
case "$NAME" in
    *[!a-z0-9-]*) echo "page-slug must be lowercase letters, digits, hyphens: '$NAME'" >&2; exit 1 ;;
esac

if [ -z "${OGDK_BANNER:-}" ]; then
cat <<'OGDKART'
   ___   ____ ____  _  __
  / _ \ / ___|  _ \| |/ /
 | | | | |  _| | | | ' /
 | |_| | |_| | |_| | . \
  \___/ \____|____/|_|\_\
OGDKART
fi

REF="docs/reference"
TPL="$REF/COMPONENT-TEMPLATE.md"
MAN="$REF/COVERAGE.md"
PAGE="$REF/$NAME.md"

[ -f "$TPL" ] || { echo "Missing $TPL - run from the project root (docs chain must exist)" >&2; exit 1; }
[ -f "$MAN" ] || { echo "Missing $MAN - reference tier not initialized" >&2; exit 1; }
[ ! -e "$PAGE" ] || { echo "$PAGE already exists - refusing to overwrite" >&2; exit 1; }

TODAY="$(date +%F)"

# sed-escape replacement text: backslash, the '&' whole-match token, and our
# delimiters ('/', '#'). Titles like "Probes & Tomography" must land literally.
esc() { printf '%s' "$1" | sed -e 's/[\\&/#]/\\&/g'; }
COMP_E="$(esc "$COMP")"
SRC_E="$(esc "$SRC")"

# 1. Page from template: stamp title, source path, and changelog date
sed -e "s/<Component Name>/$COMP_E/" \
    -e "s#\`<path/to/module>\`#\`$SRC_E\`#" \
    -e "s/<date>/$TODAY/" \
    "$TPL" > "$PAGE"

# 2. Manifest row (replace the '_none yet_' placeholder if it is still there)
ROW="| $COMP | $SRC | $NAME.md | current |"
if grep -q '^| _none yet_' "$MAN"; then
    sed -i "s#^| _none yet_ .*#$(esc "$ROW")#" "$MAN"
else
    printf '%s\n' "$ROW" >> "$MAN"
fi

echo "Created  $PAGE"
echo "Tracked  $MAN: $ROW"
echo
echo "Next: fill in the page sections, then commit page + manifest + component together."
echo "Verify: ./tools/check-reference-coverage.sh"
exit 0
