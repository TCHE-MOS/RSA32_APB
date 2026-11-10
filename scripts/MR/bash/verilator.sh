#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"

for tool in verilator verilator_coverage make g++ python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Erro: %s não encontrado. São necessários Verilator, Make, Python 3 e um compilador C++ com suporte a C++20.\n' "$tool" >&2
        exit 127
    fi
done

BUILD_JOBS="${VERILATOR_JOBS:-2}"
if [[ ! "$BUILD_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Erro: VERILATOR_JOBS deve ser um inteiro positivo.\n' >&2
    exit 2
fi

LOG_DIR="$PROJECT_ROOT/logs/MR/amba_3_apb_rsa_apb_top/verilator"
REPORT_DIR="$PROJECT_ROOT/reports/MR/amba_3_apb_rsa_apb_top/verilator"
WAVE_DIR="$PROJECT_ROOT/waveforms/MR/amba_3_apb_rsa_apb_top/verilator"
mkdir -p -- "$LOG_DIR/obj_dir" "$REPORT_DIR" "$WAVE_DIR"
# Keep compiler and runtime artifacts local when invoked from another directory.
cd -- "$LOG_DIR"

RTL_DIR="$PROJECT_ROOT/src/MR/RSA_APB"
SOURCES=(
    "$RTL_DIR/rsa_core_32bits.sv"
    "$RTL_DIR/rsa_apb_top.sv"
    "$PROJECT_ROOT/testbenchs/rsa_apb_top/testbench.sv"
)

# Measure RTL coverage without counting driver/scoreboard code as DUT coverage.
printf '%s\n' '`verilator_config' \
    'coverage_off -file "*/testbenchs/rsa_apb_top/testbench.sv"' \
    > "$LOG_DIR/coverage.vlt"

printf '[BUILD] %s\n' "$(verilator --version)"
printf '[BUILD] Compilando; log: %s\n' "$LOG_DIR/compile.log"
if ! verilator --binary --timing --assert --coverage --trace \
    --top-module testbench --timescale 1ns/1ps \
    --Mdir "$LOG_DIR/obj_dir" -o simulation -j "$BUILD_JOBS" \
    -Wall -Wno-fatal "$LOG_DIR/coverage.vlt" "${SOURCES[@]}" \
    > "$LOG_DIR/compile.log" 2>&1; then
    cat "$LOG_DIR/compile.log" >&2
    exit 1
fi

"$LOG_DIR/obj_dir/simulation" \
    "+VCD=$WAVE_DIR/testbench.vcd" \
    "+verilator+coverage+file+$LOG_DIR/coverage.dat" "$@" \
    2>&1 | tee "$LOG_DIR/simulation.log"

if [[ ! -s "$LOG_DIR/coverage.dat" ]]; then
    printf 'Erro: a simulação não gerou %s. Confira a versão e o suporte a cobertura de --binary.\n' \
        "$LOG_DIR/coverage.dat" >&2
    exit 1
fi

verilator_coverage --report summary,hier "$LOG_DIR/coverage.dat" \
    2>&1 | tee "$REPORT_DIR/coverage_summary.txt"
verilator_coverage --annotate "$REPORT_DIR/annotated" --annotate-all \
    --annotate-min 1 --annotate-points "$LOG_DIR/coverage.dat" \
    > "$LOG_DIR/coverage_annotate.log" 2>&1
verilator_coverage --write-info "$REPORT_DIR/coverage.info" "$LOG_DIR/coverage.dat" \
    > "$LOG_DIR/coverage_lcov.log" 2>&1

if command -v genhtml >/dev/null 2>&1; then
    if ! genhtml --branch-coverage --prefix "$PROJECT_ROOT" \
        --output-directory "$REPORT_DIR/html" "$REPORT_DIR/coverage.info" \
        > "$LOG_DIR/genhtml.log" 2>&1; then
        cat "$LOG_DIR/genhtml.log" >&2
        exit 1
    fi
    python3 "$PROJECT_ROOT/scripts/pages/coverage_theme.py" "$REPORT_DIR/html"
    printf '\n[COVERAGE] HTML: %s\n' "$REPORT_DIR/html/index.html"
else
    printf '\n[COVERAGE] genhtml não encontrado; instale LCOV para gerar também o HTML.\n'
fi
printf '[COVERAGE] Resumo: %s\n' "$REPORT_DIR/coverage_summary.txt"
printf '[COVERAGE] LCOV: %s\n' "$REPORT_DIR/coverage.info"
printf '[COVERAGE] Fontes anotadas: %s\n' "$REPORT_DIR/annotated"
