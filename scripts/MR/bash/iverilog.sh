#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"

for tool in iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Erro: %s não encontrado. Instale o Icarus Verilog e inclua-o no PATH.\n' "$tool" >&2
        exit 127
    fi
done

BUILD_DIR="$PROJECT_ROOT/logs/MR/amba_3_apb_rsa_apb_top/iverilog"
WAVE_DIR="$PROJECT_ROOT/waveforms/MR/amba_3_apb_rsa_apb_top"
mkdir -p -- "$BUILD_DIR" "$WAVE_DIR"
cd -- "$BUILD_DIR"

RTL_DIR="$PROJECT_ROOT/src/MR/RSA_APB"
SOURCES=(
    "$RTL_DIR/rsa_core_32bits.sv"
    "$RTL_DIR/rsa_apb_top.sv"
    "$PROJECT_ROOT/testbenchs/rsa_apb_top/testbench.sv"
)

iverilog -g2012 -Wall -s testbench \
    -o "$BUILD_DIR/testbench.vvp" "${SOURCES[@]}" \
    2>&1 | tee "$BUILD_DIR/compile.log"

vvp "$BUILD_DIR/testbench.vvp" \
    "+VCD=$WAVE_DIR/testbench.vcd" "$@" \
    2>&1 | tee "$BUILD_DIR/simulation.log"
