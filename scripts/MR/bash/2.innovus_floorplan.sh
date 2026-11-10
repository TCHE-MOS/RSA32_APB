#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/innovus_common.sh"
pdk_parse_args "$@"
innovus_setup "2.floorplan"
innovus_run "$SCRIPT_DIR/../tcl/2.innovus_floorplan.tcl" batch "${TOOL_ARGS[@]}"
