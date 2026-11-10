#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=uvm_campaign.sh
source "$SCRIPT_DIR/uvm_campaign.sh"

for arg in "$@"; do
    if [[ "$arg" == -h || "$arg" == --help ]]; then
        cat <<'EOF'
Uso: xrun_uvm_gui.sh [plusargs_e_opcoes_do_xrun...]

Mesma bancada UVM completa de xrun_uvm_nogui.sh (mesmas variaveis
UVM_TESTNAME, UVM_VERBOSITY, UVM_SEED, UVM_PYTHON, MAX_TIME e plusargs da campanha),
aberta no SimVision para depuracao. Para sessoes interativas curtas, limite a
campanha, por exemplo: ./xrun_uvm_gui.sh +CORNERS_CASES=3
Gera ondas SHM e VCD em waveforms/amba_3_apb_rsa_apb_top/uvm/.
EOF
        exit 0
    fi
done

RUN="amba_3_apb_rsa_apb_top_uvm_$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top/xrun_uvm/gui"
WAVE_DIR="$PROJECT_ROOT/waveforms/amba_3_apb_rsa_apb_top/uvm"
UVM_DIR="$PROJECT_ROOT/UVM"
COV_DIR="$PROJECT_ROOT/coverage/amba_3_apb_rsa_apb_top/uvm"
UVM_TESTNAME="${UVM_TESTNAME:-test_rsa_operation}"
UVM_VERBOSITY="${UVM_VERBOSITY:-UVM_MEDIUM}"
UVM_SEED="${UVM_SEED:-1}"

if ! command -v xrun >/dev/null 2>&1; then
    echo "Erro: 'xrun' nao encontrado no PATH. Execute o setup das ferramentas Cadence." >&2
    exit 1
fi

uvm_campaign_sources "$PROJECT_ROOT"
uvm_campaign_timing "${MAX_TIME:-auto}" "$PROJECT_ROOT" xcelium "$@"

mkdir -p -- "$LOG_DIR" "$WAVE_DIR" "$COV_DIR"
export RUN WAVE_FILE="$WAVE_DIR/${RUN}.shm"
export VCD_FILE="$WAVE_DIR/${RUN}.vcd"
cd -- "$LOG_DIR"

printf 'Teste: %s | Seed: %s | Watchdog UVM: %s ns\n' \
    "$UVM_TESTNAME" "$UVM_SEED" "$CAMPAIGN_TIMEOUT_NS"
printf 'Orcamento conservador da campanha: %s ns (tempo simulado)\n' "$CAMPAIGN_BUDGET_NS"
printf 'Ondas SHM: %s\nOndas VCD: %s\n' "$WAVE_FILE" "$VCD_FILE"

# Mesmos fontes, teste e campanha da execucao sem GUI, com depuracao no SimVision.
xrun -64bit -sv -uvm -uvmhome CDNS-1.2 -gui \
    -timescale 1ns/1ps \
    -input "$SCRIPT_DIR/../tcl/xrun_uvm_gui.tcl" \
    -top top_tb \
    -access +rwc \
    -incdir "$UVM_DIR" \
    -svseed "$UVM_SEED" \
    -coverage all \
    -abvrecordcoverall \
    -covoverwrite \
    -covdut amba_3_apb_rsa_apb_top \
    -covworkdir "$COV_DIR" \
    -covtest "$RUN" \
    -l "$LOG_DIR/${RUN}.log" \
    "${UVM_SOURCES[@]}" \
    "+UVM_TESTNAME=$UVM_TESTNAME" \
    "+UVM_VERBOSITY=$UVM_VERBOSITY" \
    "$@" "${TIMING_ARGS[@]}"
