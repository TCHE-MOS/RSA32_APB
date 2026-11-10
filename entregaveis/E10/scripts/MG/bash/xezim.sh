#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
XEZIM_BIN="${XEZIM_BIN:-xezim}"
XEZIM_BIN="$(command -v "$XEZIM_BIN")"
if [[ "$XEZIM_BIN" != /* ]]; then XEZIM_BIN="$PWD/$XEZIM_BIN"; fi

# Integrated procedural testbench, RSA v2; no UVM or UVM assertion sources.
RTL_DIR="$PROJECT_ROOT/src/MG/amba_3_apb"
SOURCES=(
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_kogge_stone_adder.sv"
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_mult.sv"
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_mod.sv"
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_ctrl.sv"
    "$PROJECT_ROOT/src/MG/rsa32/v2/rsa32_core_top.sv"
    "$RTL_DIR/amba_3_apb_adrec.sv"
    "$RTL_DIR/amba_3_apb_data_o_mux.sv"
    "$RTL_DIR/amba_3_apb_data_io_top.sv"
    "$RTL_DIR/amba_3_apb_control.sv"
    "$RTL_DIR/amba_3_apb_regbank.sv"
    "$RTL_DIR/amba_3_apb_reset.sv"
    "$RTL_DIR/amba_3_apb_rsa_wrapper_control.sv"
    "$RTL_DIR/amba_3_apb_rsa_wrapper_data.sv"
    "$RTL_DIR/amba_3_apb_rsa_wrapper_top.sv"
    "$RTL_DIR/amba_3_apb_rsa_apb_top.sv"
    "$PROJECT_ROOT/testbenchs/rsa_apb_top/testbench.sv"
)

LOG_ROOT="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top/xezim"
WAVE_ROOT="$PROJECT_ROOT/waveforms/amba_3_apb_rsa_apb_top/xezim"
mkdir -p -- "$LOG_ROOT" "$WAVE_ROOT"
BUILD_DIR="$(mktemp -d "$LOG_ROOT/$(date '+%Y-%m-%d_%H-%M-%S')_XXXXXX")"
WAVE_FILE="$WAVE_ROOT/${BUILD_DIR##*/}.fst"
ARGS=(--simulate -s testbench --timescale 1ns/1ps --error-exit
      --max-time 4ms --fst "$WAVE_FILE" --fst-scope testbench
      "${SOURCES[@]}" "$@")
printf 'Testbench integrado | RSA v2 | Logs: %s\n' "$BUILD_DIR"
{
    printf '%q ' "$XEZIM_BIN" "${ARGS[@]}"
    printf '\n'
} > "$BUILD_DIR/command.sh"
cd -- "$BUILD_DIR"
SIM_STATUS=0
"$XEZIM_BIN" "${ARGS[@]}" 2>&1 | tee "$BUILD_DIR/simulate.log" || SIM_STATUS=$?
if [[ "$SIM_STATUS" == 0 ]] && ! awk '/^TEST PASS:/ { passed = 1 } END { exit !passed }' "$BUILD_DIR/simulate.log"; then
    printf 'Erro: simulacao encerrada sem TEST PASS.\n' >&2
    SIM_STATUS=1
fi
printf '%s\n' "$SIM_STATUS" > "$BUILD_DIR/simulation.exitcode"
printf 'Ondas: %s\nCodigo de saida: %s\n' "$WAVE_FILE" "$SIM_STATUS"
exit "$SIM_STATUS"
