#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
RSA32_DIR="$PROJECT_ROOT/RSA32_opt"
RUN="rsa_core_32_opt_$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$PROJECT_ROOT/logs/RSA32/rsa_core_32_opt/xrun"
IMC_LOG_DIR="$PROJECT_ROOT/logs/RSA32/rsa_core_32_opt/imc"
WAVE_DIR="$PROJECT_ROOT/waveforms/RSA32/rsa_core_32_opt"
COV_DIR="$PROJECT_ROOT/coverage/RSA32/rsa_core_32_opt"
REPORT_DIR="$PROJECT_ROOT/reports/RSA32/rsa_core_32_opt"

mkdir -p -- "$LOG_DIR" "$IMC_LOG_DIR" "$WAVE_DIR" "$COV_DIR" "$REPORT_DIR"
cd -- "$LOG_DIR"

# Verificar se as ferramentas estao acessiveis.
for tool in xrun imc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Erro: '$tool' nao encontrado no PATH. Execute o setup das ferramentas Cadence." >&2
        exit 1
    fi
done

# ======================================
# RTL Simulation - Cadence Xcelium
# ======================================

RTL_FILES=(
    "$RSA32_DIR/src/v2/rsa32_core_kogge_stone_adder.sv"
    "$RSA32_DIR/src/v2/rsa32_core_mult.sv"
    "$RSA32_DIR/src/v2/rsa32_core_mod.sv"
    "$RSA32_DIR/src/v2/rsa32_core_ctrl.sv"
    "$RSA32_DIR/src/v2/rsa32_core_top.sv"
)
RTL_FILES+=("$RSA32_DIR/testbenches/testbench.sv")

xrun -64bit \
    -timescale 1ns/1ps \
    -top testbench \
    -access +rwc \
    -coverage all \
    -covoverwrite \
    -covworkdir "$COV_DIR" \
    -covtest "$RUN" \
    -l "$LOG_DIR/${RUN}.log" \
    "${RTL_FILES[@]}" \
    "+VCD=$WAVE_DIR/${RUN}.vcd"

# ======================================
# Coverage Report - Cadence IMC
# ======================================

COV_RUN="$COV_DIR/scope/$RUN"
REPORT_FILE="$REPORT_DIR/${RUN}_coverage.rpt"

if [[ ! -d "$COV_RUN" ]]; then
    echo "Erro: banco de cobertura nao encontrado: $COV_RUN" >&2
    exit 1
fi

(
    cd -- "$IMC_LOG_DIR"
    imc -load "$COV_RUN" \
        -execcmd "report -summary -cumulative on -inst -local off -out \"$REPORT_FILE\""
)

if [[ ! -s "$REPORT_FILE" ]]; then
    echo "Erro: o IMC nao gerou o relatorio esperado: $REPORT_FILE" >&2
    exit 1
fi

echo "Simulacao e relatorio de cobertura concluidos."
echo "Log:       $LOG_DIR/${RUN}.log"
echo "Cobertura: $COV_RUN"
echo "Relatorio: $REPORT_FILE"
