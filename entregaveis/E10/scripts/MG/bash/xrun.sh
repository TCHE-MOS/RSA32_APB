#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
RUN="amba_3_apb_rsa_apb_top_$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top/xrun"
IMC_LOG_DIR="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top/imc"
WAVE_DIR="$PROJECT_ROOT/waveforms/amba_3_apb_rsa_apb_top"
RTL_DIR="$PROJECT_ROOT/src/MG/amba_3_apb"
COV_DIR="$PROJECT_ROOT/coverage/amba_3_apb_rsa_apb_top"
REPORT_DIR="$PROJECT_ROOT/reports/amba_3_apb_rsa_apb_top"

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

xrun -64bit \
    -timescale 1ns/1ps \
    -top testbench \
    -access +rwc \
    -coverage all \
    -covoverwrite \
    -covworkdir "$COV_DIR" \
    -covtest "$RUN" \
    -l "$LOG_DIR/${RUN}.log" \
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_kogge_stone_adder.sv" \
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_mult.sv" \
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_mod.sv" \
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_ctrl.sv" \
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_top.sv" \
    "$RTL_DIR/amba_3_apb_adrec.sv" \
    "$RTL_DIR/amba_3_apb_data_o_mux.sv" \
    "$RTL_DIR/amba_3_apb_data_io_top.sv" \
    "$RTL_DIR/amba_3_apb_control.sv" \
    "$RTL_DIR/amba_3_apb_regbank.sv" \
    "$RTL_DIR/amba_3_apb_reset.sv" \
    "$RTL_DIR/amba_3_apb_rsa_wrapper_control.sv" \
    "$RTL_DIR/amba_3_apb_rsa_wrapper_data.sv" \
    "$RTL_DIR/amba_3_apb_rsa_wrapper_top.sv" \
    "$RTL_DIR/amba_3_apb_rsa_apb_top.sv" \
    "$PROJECT_ROOT/testbenchs/rsa_apb_top/testbench.sv" \
    "+FST=$WAVE_DIR/${RUN}.fst"

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

