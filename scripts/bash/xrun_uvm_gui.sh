#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
RUN="amba_3_apb_rsa_apb_top_uvm_$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top/xrun_uvm/gui"
WAVE_DIR="$PROJECT_ROOT/waveforms/amba_3_apb_rsa_apb_top/uvm"
RTL_DIR="$PROJECT_ROOT/src/amba_3_apb"
UVM_DIR="$PROJECT_ROOT/UVM"
COV_DIR="$PROJECT_ROOT/coverage/amba_3_apb_rsa_apb_top/uvm"
UVM_TESTNAME="${UVM_TESTNAME:-test_rsa_operation}"
UVM_VERBOSITY="${UVM_VERBOSITY:-UVM_MEDIUM}"

if ! command -v xrun >/dev/null 2>&1; then
    echo "Erro: 'xrun' nao encontrado no PATH. Execute o setup das ferramentas Cadence." >&2
    exit 1
fi

mkdir -p -- "$LOG_DIR" "$WAVE_DIR" "$COV_DIR"
export RUN WAVE_FILE="$WAVE_DIR/${RUN}.shm"
cd -- "$LOG_DIR"

# Mesmos fontes e teste da execucao sem GUI, com depuracao no SimVision.
xrun -64bit -sv -uvm -uvmhome CDNS-1.2 -gui \
    -timescale 1ns/1ps \
    -input "$SCRIPT_DIR/../tcl/xrun_uvm_gui.tcl" \
    -top top_tb \
    -access +rwc \
    -incdir "$UVM_DIR" \
    -coverage all \
    -covoverwrite \
    -covdut amba_3_apb_rsa_apb_top \
    -covworkdir "$COV_DIR" \
    -covtest "$RUN" \
    -l "$LOG_DIR/${RUN}.log" \
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_kogge_stone_adder.sv" \
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_mult.sv" \
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_mod.sv" \
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_ctrl.sv" \
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_top.sv" \
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
    "$UVM_DIR/testbench.svh" \
    "+UVM_TESTNAME=$UVM_TESTNAME" \
    "+UVM_VERBOSITY=$UVM_VERBOSITY" \
    "$@"
