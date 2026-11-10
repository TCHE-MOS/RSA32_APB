#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
RELEASE=1800.2-2017-1.0
DEST="$PROJECT_ROOT/.deps/$RELEASE"
URL="https://www.accellera.org/images/downloads/standards/uvm/Accellera-$RELEASE.tar.gz"
SHA256=60466406956e4a6f1101198b1b6459f829ba0bae72c8850b7dac24cd79ecc466

if [[ -r "$DEST/src/uvm_pkg.sv" && -r "$DEST/src/uvm_macros.svh" ]]; then
    printf 'Biblioteca UVM disponivel: %s\n' "$DEST"
    exit 0
fi
if [[ -e "$DEST" || -L "$DEST" ]]; then
    printf 'Erro: dependencia UVM existente e incompleta: %s\n' "$DEST" >&2
    exit 1
fi
for tool in curl sha256sum tar; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Erro: %s necessario para preparar a biblioteca UVM.\n' "$tool" >&2
        exit 127
    fi
done

mkdir -p -- "$PROJECT_ROOT/.deps"
TEMP_DIR="$(mktemp -d "$PROJECT_ROOT/.deps/.uvm-setup-XXXXXX")"
trap 'rm -rf -- "$TEMP_DIR"' EXIT
printf 'Preparando UVM %s em %s\n' "$RELEASE" "$DEST"
curl --fail --location --retry 2 --connect-timeout 15 --max-time 120 \
    --output "$TEMP_DIR/uvm.tar.gz" "$URL"
printf '%s  %s\n' "$SHA256" "$TEMP_DIR/uvm.tar.gz" | sha256sum -c -
tar -xzf "$TEMP_DIR/uvm.tar.gz" -C "$TEMP_DIR"
test -r "$TEMP_DIR/$RELEASE/src/uvm_pkg.sv"
test -r "$TEMP_DIR/$RELEASE/src/uvm_macros.svh"
mv -T -- "$TEMP_DIR/$RELEASE" "$DEST"
printf 'Biblioteca UVM instalada: %s\n' "$DEST"
