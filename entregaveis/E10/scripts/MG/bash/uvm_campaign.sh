# Funcoes compartilhadas pelas execucoes da bancada UVM completa
# (xezim_uvm.sh, xrun_uvm_nogui.sh e xrun_uvm_gui.sh). Use com "source".

UVM_CAMPAIGN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# uvm_campaign_timing MAX_TIME PROJECT_ROOT xcelium|xezim [plusargs do usuario...]
# Define MAX_TIME, CAMPAIGN_TIMEOUT_NS e TIMING_ARGS. TIMING_ARGS recebe os
# padroes +CORNERS_* e o watchdog +UVM_TIMEOUT que o usuario nao informou.
uvm_campaign_timing() {
    local max_time="$1" project_root="$2" simulator="$3" timing_config auto_timeout
    local cases base slope poll read_cap python
    shift 3
    # O setup Cadence pode antepor seu Python/bibliotecas ao ambiente do SO.
    # Use o Python do sistema e isole somente este processo; xrun/imc precisam
    # continuar recebendo o ambiente original das ferramentas.
    python="${UVM_PYTHON:-/usr/bin/python3}"
    if [[ -z "${UVM_PYTHON:-}" && ! -x "$python" ]]; then
        python=python3
    fi
    if ! command -v "$python" >/dev/null 2>&1; then
        printf 'Erro: Python nao encontrado: %s. Defina UVM_PYTHON com um Python 3.6+ do sistema.\n' "$python" >&2
        return 127
    fi
    timing_config="$(env -u LD_LIBRARY_PATH -u LD_PRELOAD "$python" -I \
        "$UVM_CAMPAIGN_DIR/../../validation/uvm_campaign_timing.py" \
        "$max_time" "$project_root/UVM/top_tb_pkg.svh" "$simulator" "$@")" || return
    read -r MAX_TIME CAMPAIGN_TIMEOUT_NS auto_timeout cases base slope poll read_cap CAMPAIGN_BUDGET_NS \
        <<< "$timing_config"
    TIMING_ARGS=()
    _uvm_campaign_default "+CORNERS_CASES=$cases" "$@"
    _uvm_campaign_default "+CORNERS_BASE_CYCLES=$base" "$@"
    _uvm_campaign_default "+CORNERS_CYCLES_PER_EXP=$slope" "$@"
    _uvm_campaign_default "+CORNERS_POLL_CYCLES=$poll" "$@"
    _uvm_campaign_default "+CORNERS_MAX_READS=$read_cap" "$@"
    if [[ "$auto_timeout" == 1 ]]; then
        TIMING_ARGS+=("+UVM_TIMEOUT=$CAMPAIGN_TIMEOUT_NS,YES")
    fi
}

_uvm_campaign_default() {
    local default="$1" arg
    shift
    for arg in "$@"; do
        if [[ "$arg" == "${default%%=*}="* ]]; then return; fi
    done
    TIMING_ARGS+=("$default")
}

# uvm_campaign_passed LOG
# $finish ou um limite de tempo podem encerrar sem codigo de erro.
# Exige o resumo UVM com zero UVM_ERROR/UVM_FATAL.
uvm_campaign_passed() {
    awk '
        /^[[:space:]]*UVM_ERROR[[:space:]]*:/ { errors = $NF; saw_errors = 1 }
        /^[[:space:]]*UVM_FATAL[[:space:]]*:/ { fatals = $NF; saw_fatals = 1 }
        /^\[SVA\] Contagens finais UVM: ERROR=[0-9]+ \| FATAL=[0-9]+$/ {
            split($5, final_errors, "="); errors = final_errors[2]
            split($7, final_fatals, "="); fatals = final_fatals[2]
        }
        END { exit !(saw_errors && saw_fatals && errors == 0 && fatals == 0) }
    ' "$1"
}

# uvm_campaign_sources PROJECT_ROOT
# Define UVM_SOURCES: RTL do DUT (nucleo src/MG/rsa32/v2) e testbench.svh, que
# inclui interface, pacotes, assertions, harness e top_tb. Os arquivos
# incluidos por testbench.svh nao devem ser compilados separadamente.
uvm_campaign_sources() {
    local rsa_dir="$1/src/MG/rsa32/v2" rtl_dir="$1/src/MG/amba_3_apb" source_file
    UVM_SOURCES=(
        "$rsa_dir/rsa32_core_kogge_stone_adder.sv"
        "$rsa_dir/rsa32_core_mult.sv"
        "$rsa_dir/rsa32_core_mod.sv"
        "$rsa_dir/rsa32_core_ctrl.sv"
        "$rsa_dir/rsa32_core_top.sv"
        "$rtl_dir/amba_3_apb_adrec.sv"
        "$rtl_dir/amba_3_apb_data_o_mux.sv"
        "$rtl_dir/amba_3_apb_data_io_top.sv"
        "$rtl_dir/amba_3_apb_control.sv"
        "$rtl_dir/amba_3_apb_regbank.sv"
        "$rtl_dir/amba_3_apb_reset.sv"
        "$rtl_dir/amba_3_apb_rsa_wrapper_control.sv"
        "$rtl_dir/amba_3_apb_rsa_wrapper_data.sv"
        "$rtl_dir/amba_3_apb_rsa_wrapper_top.sv"
        "$rtl_dir/amba_3_apb_rsa_apb_top.sv"
        "$1/UVM/testbench.svh"
    )
    for source_file in "${UVM_SOURCES[@]}"; do
        if [[ ! -r "$source_file" ]]; then
            printf 'Erro: fonte ausente ou sem permissao de leitura: %s\n' "$source_file" >&2
            return 1
        fi
    done
}
