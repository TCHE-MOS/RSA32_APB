#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/imc_common.sh"
imc_select_run "$@"
source "$SCRIPT_DIR/report_common.sh"
reports_setup imc rtl
export IMC_GENERATE_REPORTS=1
cd -- "$LOG_DIR"

printf 'Banco UVM: %s\n' "$IMC_COV_RUN"
"${IMC_BIN:-imc}" -execcmd "source \"$SCRIPT_DIR/../tcl/imc.tcl\""
for output in coverage_rtl.rpt coverage_rates_rtl.rpt coverage_covergroups_rtl.rpt coverage_html_rtl/index.html; do
    if [[ ! -s "$REPORT_DIR/$output" ]]; then
        printf 'Erro: IMC nao gerou %s. Consulte %s\n' "$REPORT_DIR/$output" "$LOG_DIR" >&2
        exit 1
    fi
done
printf '\nCobertura cumulativa: itens cobertos / itens medidos, por hierarquia.\n'
cat "$REPORT_DIR/coverage_rates_rtl.rpt"
printf '\nBins funcionais: %s\nHTML: %s\n' \
    "$REPORT_DIR/coverage_covergroups_rtl.rpt" "$REPORT_DIR/coverage_html_rtl/index.html"
printf 'Relatórios: %s\n' "$REPORT_DIR"
