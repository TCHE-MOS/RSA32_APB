#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/innovus_common.sh"
pdk_parse_args "$@"
innovus_setup "1.check"
innovus_run "$SCRIPT_DIR/../tcl/1.innovus_check.tcl" batch "${TOOL_ARGS[@]}"
