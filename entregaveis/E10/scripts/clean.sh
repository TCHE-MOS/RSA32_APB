#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DESIGN="amba_3_apb_rsa_apb_top"

if [[ ! -d "$PROJECT_ROOT/scripts/MG/tcl" || ! -d "$PROJECT_ROOT/ps_files/rsa_apb_top_ihp130" ]]; then
    printf 'Erro: diretório do projeto RSA_APB não reconhecido: %s\n' "$PROJECT_ROOT" >&2
    exit 1
fi

case "${1:-}" in
    ''|--dry-run|--yes) ;;
    *) printf 'Uso: %s [--dry-run|--yes]\n' "${0##*/}" >&2; exit 2 ;;
esac

# Artefatos de Genus e Innovus exclusivamente do projeto RSA_APB top.
targets=(
    "$PROJECT_ROOT/logs/$DESIGN/genus"
    "$PROJECT_ROOT/logs/$DESIGN/innovus"
    "$PROJECT_ROOT/reports/$DESIGN/genus"
    "$PROJECT_ROOT/reports/$DESIGN/innovus"
    "$PROJECT_ROOT/ps_files/rsa_apb_top_ihp130/netlist"
    "$PROJECT_ROOT/ps_files/rsa_apb_top_ihp130/sdc"
    "$PROJECT_ROOT/ps_files/rsa_apb_top_ihp130/db"
    "$PROJECT_ROOT/ps_files/rsa_apb_top_ihp130/genus"
    "$PROJECT_ROOT/ps_files/rsa_apb_top_ihp130/innovus"
)

# Logs antigos criados na raiz antes da correção do diretório de execução.
shopt -s nullglob
targets+=(
    "$PROJECT_ROOT"/innovus.log*
    "$PROJECT_ROOT"/innovus.cmd*
    "$PROJECT_ROOT"/innovus_temp_*
    "$PROJECT_ROOT"/genus.log*
    "$PROJECT_ROOT"/genus.cmd*
)
shopt -u nullglob

present=()
for path in "${targets[@]}"; do
    if [[ -e "$path" || -L "$path" ]]; then
        present+=("$path")
    fi
done

if (( ${#present[@]} == 0 )); then
    printf 'Nenhum artefato de Genus/Innovus encontrado.\n'
    exit 0
fi

printf 'Arquivos e diretórios que serão removidos:\n'
printf '  %s\n' "${present[@]}"

if [[ "${1:-}" == '--dry-run' ]]; then
    exit 0
fi

if [[ "${1:-}" != '--yes' ]]; then
    read -r -p 'Confirmar exclusão permanente? [s/N] ' answer
    [[ "$answer" == 's' || "$answer" == 'S' ]] || exit 0
fi

for path in "${present[@]}"; do
    rm -rf -- "$path"
done

printf 'Limpeza concluída.\n'

