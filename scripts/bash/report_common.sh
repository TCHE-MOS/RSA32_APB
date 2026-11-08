#!/usr/bin/env bash

# PROJECT_ROOT is supplied by the launcher. Reserve a fresh report directory,
# including when two processes start at the same time.
reports_setup() {
    local tool="$1" tag="$2"
    local base="$PROJECT_ROOT/reports/amba_3_apb_rsa_apb_top_${tag}/${tool}"
    mkdir -p -- "$base"
    while :; do
        RUN="amba_3_apb_rsa_apb_top_$(date '+%Y-%m-%d_%H-%M-%S_%N')_${tag}"
        REPORT_DIR="$base/$RUN"
        if mkdir -- "$REPORT_DIR" 2>/dev/null; then
            break
        fi
        if [[ ! -d "$REPORT_DIR" ]]; then
            printf 'Erro: não foi possível criar %s\n' "$REPORT_DIR" >&2
            return 1
        fi
    done
    LOG_DIR="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top_${tag}/${tool}/$RUN"
    mkdir -p -- "$LOG_DIR"
    export RUN REPORT_DIR LOG_DIR
}
