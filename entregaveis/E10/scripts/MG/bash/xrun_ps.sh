#!/usr/bin/env bash
set -euo pipefail

# Use the current TSMC28 flow, including matching netlist/SDF selection.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/xrun_ps_tsmc28.sh" "$@"
