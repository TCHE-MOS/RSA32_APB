#!/usr/bin/env bash
set -euo pipefail

# Valida os arquivos Sky130 usados pelo Genus e pelo Innovus.
# O diretório-base pode ser sobrescrito com SKY130_PDK_BASE.

SKY130_PDK_BASE="${SKY130_PDK_BASE:-/home/aluno/eda-pdks-docker/home/.sc/cache/dataroot}"
SKY130_ROOT="$SKY130_PDK_BASE/lambdapdk-v0.2.22-967925fc5309e6d4/lambdapdk/sky130"
STD_CELL="$SKY130_ROOT/libs/sky130hd"

LIBERTY="$STD_CELL/nldm/sky130_fd_sc_hd__tt_025C_1v80.lib.gz"
TECH_LEF="$SKY130_ROOT/base/apr/sky130_fd_sc.tlef"
CELL_LEF="$STD_CELL/lef/sky130_fd_sc_hd_merged.lef"
PRIMITIVES_VERILOG="$STD_CELL/verilog/primitives.v"
STD_CELL_VERILOG="$STD_CELL/verilog/sky130_fd_sc_hd.v"
STD_CELL_GDS="$STD_CELL/gds/sky130_fd_sc_hd.gds"

check_dir() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        printf '[ERRO] Diretório ausente: %s\n' "$path" >&2
        return 1
    fi
    printf '[OK]   Diretório: %s\n' "$path"
}

check_file() {
    local path="$1"
    if [[ ! -r "$path" ]]; then
        printf '[ERRO] Arquivo ausente ou ilegível: %s\n' "$path" >&2
        return 1
    fi
    printf '[OK]   Arquivo: %s\n' "$path"
}

printf 'Validando Sky130 para Genus/Innovus\n'
printf 'Base do PDK: %s\n\n' "$SKY130_PDK_BASE"

check_dir "$SKY130_ROOT"
check_dir "$STD_CELL"
check_file "$LIBERTY"
check_file "$TECH_LEF"
check_file "$CELL_LEF"
check_file "$PRIMITIVES_VERILOG"
check_file "$STD_CELL_VERILOG"

if [[ -r "$STD_CELL_GDS" ]]; then
    printf '[OK]   GDS: %s\n' "$STD_CELL_GDS"
else
    printf '[AVISO] GDS não encontrado; necessário somente para stream-out físico: %s\n' "$STD_CELL_GDS"
fi

printf '\nSky130 validado com sucesso para síntese e implementação física.\n'
