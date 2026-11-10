#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/report_common.sh"
reports_setup lint rtl
export LINT_LOG="$LOG_DIR/${RUN}.log"
cd -- "$LOG_DIR"

exec "${LEC_BIN:-lec}" -nogui -dofile "$SCRIPT_DIR/../tcl/lint.tcl"
