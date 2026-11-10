#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
RUN="amba_3_apb_rsa_apb_top_$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$PROJECT_ROOT/logs/MR/amba_3_apb_rsa_apb_top/xrun"
WAVE_DIR="$PROJECT_ROOT/waveforms/MR/amba_3_apb_rsa_apb_top"
RTL_DIR="$PROJECT_ROOT/src/MR/RSA_APB"

mkdir -p -- "$LOG_DIR" "$WAVE_DIR"
export RUN WAVE_FILE="$WAVE_DIR/${RUN}.shm"
cd -- "$LOG_DIR"

xrun -64bit -gui \
    -timescale 1ns/1ps \
    -input "$SCRIPT_DIR/../tcl/xrun_wgui.tcl" \
    -top tb \
    -access +rwc \
    -l "$LOG_DIR/${RUN}.log" \
    "$RTL_DIR/rsa_core_32bits.sv" \
    "$RTL_DIR/rsa_apb_top.sv" \
    "$PROJECT_ROOT/testbenchs/rsa_apb_top/rsa_apb_tb.sv"
