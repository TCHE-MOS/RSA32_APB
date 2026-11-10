#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
RSA32_DIR="$PROJECT_ROOT/RSA32_opt"
RUN="rsa_core_32_opt_$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$PROJECT_ROOT/logs/RSA32/rsa_core_32_opt/xrun"
WAVE_DIR="$PROJECT_ROOT/waveforms/RSA32/rsa_core_32_opt"

mkdir -p -- "$LOG_DIR" "$WAVE_DIR"
export RUN WAVE_FILE="$WAVE_DIR/${RUN}.shm"
cd -- "$LOG_DIR"

RTL_FILES=(
    "$RSA32_DIR/src/v2/rsa32_core_kogge_stone_adder.sv"
    "$RSA32_DIR/src/v2/rsa32_core_mult.sv"
    "$RSA32_DIR/src/v2/rsa32_core_mod.sv"
    "$RSA32_DIR/src/v2/rsa32_core_ctrl.sv"
    "$RSA32_DIR/src/v2/rsa32_core_top.sv"
)
RTL_FILES+=("$RSA32_DIR/testbenches/testbench.sv")

xrun -64bit -gui \
    -timescale 1ns/1ps \
    -input "$SCRIPT_DIR/../tcl/xrun_wgui.tcl" \
    -top testbench \
    -access +rwc \
    -l "$LOG_DIR/${RUN}.log" \
    "${RTL_FILES[@]}"
