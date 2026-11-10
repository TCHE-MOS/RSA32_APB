#!/usr/bin/env bash
# LEC RTL-to-RTL do projeto RSA de 4 bits:
#   RSA4/src/vlog/rsa_core.v (golden) x RSA4/src/sv/rsa_core.sv (revised)
# Uso: ./scripts/RSA4/bash/run_rsa_lec.sh [modulo_top]   (padrao: rsa_core)
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
RSA4_DIR="$PROJECT_ROOT/RSA4"
TCL_SCRIPT="$SCRIPT_DIR/../tcl/rsa_lec.tcl"
OUTPUT_DIR="$PROJECT_ROOT/reports/RSA4/lec"

# Pode-se substituir o binario: LEC_BIN=/caminho/para/lec ./run_rsa_lec.sh
LEC_BIN="${LEC_BIN:-lec}"
TOP_MODULE="${1:-rsa_core}"

if ! command -v "$LEC_BIN" >/dev/null 2>&1; then
    printf 'ERRO: executavel Conformal nao encontrado: %s\n' "$LEC_BIN" >&2
    exit 127
fi

export LEC_GOLDEN="$RSA4_DIR/src/vlog/rsa_core.v"
export LEC_REVISED="$RSA4_DIR/src/sv/rsa_core.sv"
export LEC_TOP="$TOP_MODULE"
export LEC_OUTPUT_DIR="$OUTPUT_DIR"

for file in "$LEC_GOLDEN" "$LEC_REVISED" "$TCL_SCRIPT"; do
    if [[ ! -r "$file" ]]; then
        printf 'ERRO: arquivo inexistente ou inacessivel: %s\n' "$file" >&2
        exit 2
    fi
done

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/summary.txt"

printf 'Golden    : %s\nRevised   : %s\nTop       : %s\nResultados: %s\n' \
    "$LEC_GOLDEN" "$LEC_REVISED" "$LEC_TOP" "$OUTPUT_DIR"

# -tclmode e indispensavel: o arquivo .tcl usa comandos Conformal com underscore.
# -nodefault evita que um .conformal_lec externo altere silenciosamente o fluxo.
# PIPESTATUS[0] preserva o retorno de 'lec', e nao de 'tee'.
set +e
(
    cd "$OUTPUT_DIR"
    "$LEC_BIN" -64 -nogui -tclmode -nodefault \
        -logfile "$OUTPUT_DIR/equivalence.rpt" \
        -dofile "$TCL_SCRIPT"
) 2>&1 | tee "$OUTPUT_DIR/console.log"
lec_rc=${PIPESTATUS[0]}
set -e

printf '\nRelatorio Conformal: %s/equivalence.rpt\n' "$OUTPUT_DIR"
printf 'Console completa:   %s/console.log\n' "$OUTPUT_DIR"
if [[ -f "$OUTPUT_DIR/summary.txt" ]]; then
    printf 'Resumo:             %s/summary.txt\n' "$OUTPUT_DIR"
    cat "$OUTPUT_DIR/summary.txt"
else
    printf 'AVISO: resumo ausente; verificar licenca, inicializacao e log.\n' >&2
    if [[ "$lec_rc" -eq 0 ]]; then
        lec_rc=2
    fi
fi

exit "$lec_rc"
