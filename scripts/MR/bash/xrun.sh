#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
RUN="amba_3_apb_rsa_apb_top_$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$PROJECT_ROOT/logs/MR/amba_3_apb_rsa_apb_top/xrun"
IMC_LOG_DIR="$PROJECT_ROOT/logs/MR/amba_3_apb_rsa_apb_top/imc"
WAVE_DIR="$PROJECT_ROOT/waveforms/MR/amba_3_apb_rsa_apb_top"
RTL_DIR="$PROJECT_ROOT/src/MR/RSA_APB"
COV_DIR="$PROJECT_ROOT/coverage/MR/amba_3_apb_rsa_apb_top"
REPORT_DIR="$PROJECT_ROOT/reports/MR/amba_3_apb_rsa_apb_top"

mkdir -p -- "$LOG_DIR" "$IMC_LOG_DIR" "$WAVE_DIR" "$COV_DIR" "$REPORT_DIR"
export WAVE_FILE="$WAVE_DIR/${RUN}.shm"
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
    -input "$SCRIPT_DIR/../tcl/xrun.tcl" \
    -top tb \
    -access +rwc \
    -coverage all \
    -covoverwrite \
    -covworkdir "$COV_DIR" \
    -covtest "$RUN" \
    -l "$LOG_DIR/${RUN}.log" \
    "$RTL_DIR/rsa_core_32bits.sv" \
    "$RTL_DIR/rsa_apb_top.sv" \
    "$PROJECT_ROOT/testbenchs/rsa_apb_top/rsa_apb_tb.sv"

# O testbench MR e autoverificavel: exige "PASS: <n> checks" no log.
if ! grep -Eq '^PASS: [0-9]+ checks' "$LOG_DIR/${RUN}.log"; then
    echo "Erro: simulacao sem PASS do testbench MR. Consulte $LOG_DIR/${RUN}.log" >&2
    exit 1
fi

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
echo "Ondas:     $WAVE_FILE"
echo "Cobertura: $COV_RUN"
echo "Relatorio: $REPORT_FILE"

