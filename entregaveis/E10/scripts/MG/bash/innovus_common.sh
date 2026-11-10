#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/pdk_common.sh"

innovus_setup() {
    if [[ "$PDK" == "tsmc28" ]]; then
        printf 'Erro: tsmc28 suporta somente síntese Genus sem LEF; o fluxo Innovus exige configuração física.\n' >&2
        return 2
    fi
    local stage="$1" candidate latest="" netlist_dir
    local common_dir
    common_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd -- "$common_dir/../../.." && pwd)"
    INNOVUS_BASE_DIR="$PROJECT_ROOT/ps_files/rsa_apb_top_${PDK}/innovus/rsa32_v2"
    netlist_dir="$PROJECT_ROOT/ps_files/rsa_apb_top_${PDK}/netlist"

    if [[ -z "${SYNTH_RUN:-}" ]]; then
        if [[ "$stage" == "0.init" ]]; then
            for candidate in "$netlist_dir"/synth_amba_3_apb_rsa_apb_top_*_"$PDK".v; do
                [[ -f "$candidate" ]] || continue
                if [[ -z "$latest" || "$candidate" -nt "$latest" ]]; then
                    latest="$candidate"
                fi
            done
            if [[ -z "$latest" ]]; then
                echo "Erro: nenhuma netlist sintetizada encontrada em $netlist_dir." >&2
                return 1
            fi
            SYNTH_RUN="$(basename -- "${latest%.v}")"
            SYNTH_RUN="${SYNTH_RUN#synth_}"
        else
            if [[ ! -s "$INNOVUS_BASE_DIR/active_run" ]]; then
                echo "Erro: execute 0.innovus_init.sh para iniciar o fluxo RSA32 v2." >&2
                return 1
            fi
            IFS= read -r SYNTH_RUN < "$INNOVUS_BASE_DIR/active_run"
        fi
    fi

    if [[ ! "$SYNTH_RUN" =~ ^amba_3_apb_rsa_apb_top_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}(_[0-9]+)?_${PDK}$ ]]; then
        echo "Erro: identificador de sintese invalido para $PDK: $SYNTH_RUN" >&2
        return 1
    fi

    NETLIST_FILE="$netlist_dir/synth_${SYNTH_RUN}.v"
    SDC_FILE="$PROJECT_ROOT/ps_files/rsa_apb_top_${PDK}/sdc/synth_${SYNTH_RUN}.sdc"
    for candidate in "$NETLIST_FILE" "$SDC_FILE"; do
        if [[ ! -s "$candidate" ]]; then
            echo "Erro: arquivo da sintese selecionada nao encontrado ou vazio: $candidate" >&2
            return 1
        fi
    done

    INNOVUS_STAGE="$stage"
    INNOVUS_DB_DIR="$INNOVUS_BASE_DIR/$SYNTH_RUN"
    INNOVUS_REPORT_DIR="$PROJECT_ROOT/reports/amba_3_apb_rsa_apb_top_${PDK}/innovus/rsa32_v2/$SYNTH_RUN"
    INNOVUS_LOG_DIR="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top_${PDK}/innovus/rsa32_v2/$SYNTH_RUN/$stage"
    INNOVUS_TECH_DIR="${INNOVUS_TECH_DIR:-/home/cadence/DDI221/JLS221/etc/rtls/tutorial/libraries}"
    MMMC_FILE="$common_dir/../tcl/innovus_mmmc.tcl"
    export PDK PROJECT_ROOT SYNTH_RUN NETLIST_FILE SDC_FILE MMMC_FILE
    export INNOVUS_BASE_DIR INNOVUS_DB_DIR INNOVUS_REPORT_DIR INNOVUS_LOG_DIR
    export INNOVUS_STAGE INNOVUS_TECH_DIR
}

innovus_run() {
    local tcl_file="$1" mode="${2:-batch}" binary
    shift
    if [[ $# -gt 0 ]]; then shift; fi
    if [[ -n "${INNOVUS_BIN:-}" ]]; then
        binary="$INNOVUS_BIN"
    elif command -v innovus >/dev/null 2>&1; then
        binary="$(command -v innovus)"
    else
        binary="${INNOVUS:-/home/cadence/DDI221/INNOVUS221}/bin/innovus"
    fi
    if [[ ! -x "$binary" ]]; then
        echo "Erro: Innovus nao encontrado. Configure o PATH ou INNOVUS_BIN." >&2
        return 127
    fi
    export INNOVUS_SCRIPT="$tcl_file"
    tcl_file="$PROJECT_ROOT/scripts/MG/tcl/run_innovus_${PDK}.tcl"
    mkdir -p -- "$INNOVUS_LOG_DIR" "$INNOVUS_REPORT_DIR" "$INNOVUS_DB_DIR"
    cd -- "$INNOVUS_LOG_DIR"
    printf 'Sintese: %s\nNetlist: %s\nSDC: %s\nBanco: %s\n' \
        "$SYNTH_RUN" "$NETLIST_FILE" "$SDC_FILE" "$INNOVUS_DB_DIR"
    if [[ "$mode" == "gui" ]]; then
        exec "$binary" -stylus -files "$tcl_file" -log "$INNOVUS_LOG_DIR/innovus_${PDK}.log" "$@"
    fi
    exec "$binary" -stylus -no_gui -files "$tcl_file" "$@"
}
