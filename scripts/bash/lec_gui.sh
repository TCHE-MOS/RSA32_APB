#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pdk_common.sh"
pdk_parse_args "$@"
export PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/report_common.sh"
reports_setup lec "$PDK"
export LEC_LOG="$LOG_DIR/${RUN}.log"
cd -- "$LOG_DIR"

exec "${LEC_BIN:-lec}" -dofile "$SCRIPT_DIR/../tcl/lec_gui.tcl" "${TOOL_ARGS[@]}"
