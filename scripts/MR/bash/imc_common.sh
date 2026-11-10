#!/usr/bin/env bash

# Compartilhado pelos lancadores batch e GUI; PROJECT_ROOT vem do lancador.
imc_select_run() {
    local scope="$PROJECT_ROOT/coverage/MR/amba_3_apb_rsa_apb_top/uvm/scope"
    local candidate data found=0
    if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
        printf 'Uso: %s [diretorio_do_banco_UVM]\n' "${0##*/}"
        printf 'Sem argumento, seleciona a ultima execucao UVM pelo nome/data.\n'
        printf 'imc.sh gera percentuais, bins funcionais e HTML; imc_gui.sh abre o banco.\n'
        exit 0
    fi
    if (( $# > 1 )); then
        printf 'Erro: informe somente um diretorio de cobertura UVM.\n' >&2
        return 2
    fi
    IMC_COV_RUN="${1:-}"
    if [[ -z "$IMC_COV_RUN" ]]; then
        # Os nomes RUN possuem data/hora ordenavel; nao dependemos do mtime.
        for candidate in "$scope"/amba_3_apb_rsa_apb_top_uvm_*; do
            [[ -d "$candidate" ]] && IMC_COV_RUN="$candidate"
        done
    fi
    if [[ -z "$IMC_COV_RUN" || ! -d "$IMC_COV_RUN" ]]; then
        printf 'Erro: banco UVM nao encontrado. Execute xrun_uvm_nogui.sh ou informe o diretorio do banco.\n' >&2
        return 1
    fi
    IMC_COV_RUN="$(cd -- "$IMC_COV_RUN" && pwd)"
    for data in "$IMC_COV_RUN"/*.ucd; do
        if [[ -s "$data" && -r "$data" ]]; then found=1; break; fi
    done
    if [[ "$found" == 0 ]]; then
        printf 'Erro: banco sem dados .ucd: %s. Aguarde o fim da simulacao.\n' "$IMC_COV_RUN" >&2
        return 1
    fi
    export IMC_COV_RUN
}
