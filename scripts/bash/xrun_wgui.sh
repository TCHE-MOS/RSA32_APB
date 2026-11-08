#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
RUN="amba_3_apb_rsa_apb_top_$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top/xrun"
WAVE_DIR="$PROJECT_ROOT/waveforms/amba_3_apb_rsa_apb_top"
RTL_DIR="$PROJECT_ROOT/src/amba_3_apb"

mkdir -p -- "$LOG_DIR" "$WAVE_DIR"
export RUN WAVE_FILE="$WAVE_DIR/${RUN}.shm"
cd -- "$LOG_DIR"

xrun -64bit -gui \
    -timescale 1ns/1ps \
    -input "$SCRIPT_DIR/../tcl/xrun_wgui.tcl" \
    -top testbench \
    -access +rwc \
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
    "$PROJECT_ROOT/testbenchs/rsa_apb_top/testbench.sv"
