#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/imc_common.sh"
imc_select_run "$@"
export IMC_GENERATE_REPORTS=0
source "$SCRIPT_DIR/report_common.sh"
reports_setup imc rtl
cd -- "$LOG_DIR"

printf 'Banco UVM: %s\n' "$IMC_COV_RUN"
exec "${IMC_BIN:-imc}" -gui -init "$SCRIPT_DIR/../tcl/imc.tcl"
