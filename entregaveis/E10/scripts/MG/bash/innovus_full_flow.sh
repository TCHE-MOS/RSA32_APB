#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/innovus_common.sh"
pdk_parse_args "$@"
innovus_setup "0.init"

stages=(
    0.innovus_init.sh
    1.innovus_check.sh
    2.innovus_floorplan.sh
    3.innovus_power.sh
    4.innovus_place.sh
    5.innovus_cts.sh
    6.innovus_route.sh
    7.innovus_postroute.sh
    8.innovus_verify.sh
    9.innovus_export.sh
)

for stage in "${stages[@]}"; do
    stage_path="$SCRIPT_DIR/$stage"
    if [[ ! -x "$stage_path" ]]; then
        printf 'Erro: script Innovus ausente ou sem permissão de execução: %s\n' "$stage_path" >&2
        exit 1
    fi
done

for stage in "${stages[@]}"; do
    printf '\n[INNOVUS %s] %s — %s\n' "$PDK" "$SYNTH_RUN" "$stage"
    "$SCRIPT_DIR/$stage" -p "$PDK" -- "${TOOL_ARGS[@]}"
done

printf '\n[INNOVUS %s] Fluxo concluído: %s\n' "$PDK" "$SYNTH_RUN"
