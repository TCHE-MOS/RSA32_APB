#!/usr/bin/env bash
# Bancada do núcleo RSA isolado (sem APB, UVM ou SVA).
# Uso: bash scripts/MG/bash/xezim_rsa_core_fault.sh [v1|v2] [+SEED=n] [+N_RANDOM=n] [+RAND_EXP_MAX=n]
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
XEZIM_BIN="$(command -v "${XEZIM_BIN:-xezim}")"

RSA_VERSION="v2"
if [[ "${1:-}" == v1 || "${1:-}" == v2 ]]; then RSA_VERSION="$1"; shift; fi

DEFINES=()
if [[ "$RSA_VERSION" == v1 ]]; then
    SOURCES=("$PROJECT_ROOT/src/MG/rsa32/v1/rsa_core_32.sv")
    DEFINES=(-D RSA_V1)
else
    SOURCES=(
        "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_kogge_stone_adder.sv"
        "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_mult.sv"
        "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_mod.sv"
        "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_ctrl.sv"
        "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_top.sv"
    )
fi
SOURCES+=("$PROJECT_ROOT/testbenchs/rsa_core_fault/tb_rsa_core_fault.sv")

LOG_ROOT="$PROJECT_ROOT/logs/rsa_core/xezim_core_fault"
WAVE_ROOT="$PROJECT_ROOT/waveforms/rsa_core/xezim_core_fault"
mkdir -p -- "$LOG_ROOT" "$WAVE_ROOT"
BUILD_DIR="$(mktemp -d "$LOG_ROOT/$(date '+%Y-%m-%d_%H-%M-%S')_${RSA_VERSION}_XXXXXX")"
WAVE_FILE="$WAVE_ROOT/${BUILD_DIR##*/}.fst"
ARGS=(--simulate -s tb_rsa_core_fault --timescale 1ns/1ps --error-exit
      --max-time 50ms --fst "$WAVE_FILE" --fst-scope tb_rsa_core_fault
      "${DEFINES[@]}" "${SOURCES[@]}" "$@")
printf 'rsa_core isolado | RSA %s | Logs: %s\n' "$RSA_VERSION" "$BUILD_DIR"
{ printf '%q ' "$XEZIM_BIN" "${ARGS[@]}"; printf '\n'; } > "$BUILD_DIR/command.sh"
cd -- "$BUILD_DIR"
SIM_STATUS=0
"$XEZIM_BIN" "${ARGS[@]}" 2>&1 | tee "$BUILD_DIR/simulate.log" || SIM_STATUS=$?
if [[ "$SIM_STATUS" == 0 ]] && ! grep -q '^TEST PASS' "$BUILD_DIR/simulate.log"; then SIM_STATUS=1; fi
printf '%s\n' "$SIM_STATUS" > "$BUILD_DIR/simulation.exitcode"
printf 'Ondas: %s\nCodigo de saida: %s\n' "$WAVE_FILE" "$SIM_STATUS"
exit "$SIM_STATUS"
