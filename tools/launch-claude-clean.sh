#!/usr/bin/env bash
# Launch Claude Code after passing the environment health check.
# Linux twin of launch-claude-clean.ps1 (no PATH sanitizing needed on Linux;
# the gate here is the NTFS/dual-boot check).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! bash "$DIR/verify-path-health.sh"; then
    echo
    echo "Health check failed - fix the issues above before launching an agent."
    exit 1
fi
exec claude "$@"
# EOF
