#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pdk_common.sh"
pdk_parse_args "$@"
export PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
RUN="amba_3_apb_rsa_apb_top_$(date '+%Y-%m-%d_%H-%M-%S_%N')_${PDK}"
DB_DIR="$PROJECT_ROOT/ps_files/rsa_apb_top_${PDK}/db"
LOG_DIR="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top_${PDK}/genus/gui/$RUN"

mkdir -p -- "$LOG_DIR"
if [[ ! -d "$DB_DIR" ]]; then
    printf 'Erro: diretório de bancos Genus não encontrado: %s\nExecute genus_nogui.sh primeiro.\n' \
        "$DB_DIR" >&2
    exit 1
fi

DB_FILE="$(find "$DB_DIR" -maxdepth 1 -type f -name "synth_*_${PDK}.db" \
    -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d ' ' -f 2-)"
if [[ -z "$DB_FILE" ]]; then
    printf 'Erro: nenhum banco de síntese Genus encontrado em %s. Execute genus_nogui.sh primeiro.\n' \
        "$DB_DIR" >&2
    exit 1
fi

export DB_FILE
cd -- "$LOG_DIR"
exec "${GENUS_BIN:-genus}" -gui -files "$SCRIPT_DIR/../tcl/open_genus_gui.tcl" \
    -log "$LOG_DIR/${RUN}.log" "${TOOL_ARGS[@]}"
