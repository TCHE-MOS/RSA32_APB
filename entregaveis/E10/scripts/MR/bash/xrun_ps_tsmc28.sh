#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"

case "${1:-}" in
    -h|--help)
        printf 'Uso: %s [-- opções adicionais do Xrun]\n' "${0##*/}"
        printf 'TSMC28: netlist + SDF da mesma síntese; clock padrão de 100 MHz.\n'
        printf 'Variáveis: SYNTH_RUN, TSMC28_ROOT, TSMC28_VERILOG_FILE, XRUN_BIN, CLOCK_PERIOD_NS.\n'
        exit 0
        ;;
    --) shift ;;
    '') ;;
    *) printf 'Erro: use -- antes das opções do Xrun, ou -h para ajuda.\n' >&2; exit 2 ;;
esac

export PDK=tsmc28
SYNTH_DIR="$PROJECT_ROOT/ps_files/MR/rsa_apb_top_tsmc28"
if [[ -z "${SYNTH_RUN:-}" ]]; then
    latest=""
    for candidate in "$SYNTH_DIR"/netlist/synth_amba_3_apb_rsa_apb_top_*_tsmc28.v; do
        [[ -f "$candidate" ]] || continue
        if [[ -z "$latest" || "$candidate" -nt "$latest" ]]; then
            latest="$candidate"
        fi
    done
    if [[ -z "$latest" ]]; then
        printf 'Erro: nenhuma netlist TSMC28 encontrada em %s/netlist. Execute genus_no_gui.sh -p tsmc28.\n' "$SYNTH_DIR" >&2
        exit 1
    fi
    SYNTH_RUN="$(basename -- "${latest%.v}")"
    SYNTH_RUN="${SYNTH_RUN#synth_}"
fi
if [[ ! "$SYNTH_RUN" =~ ^amba_3_apb_rsa_apb_top_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}(_[0-9]+)?_tsmc28$ ]]; then
    printf 'Erro: SYNTH_RUN inválido para TSMC28: %s\n' "$SYNTH_RUN" >&2
    exit 2
fi

NETLIST_FILE="$SYNTH_DIR/netlist/synth_${SYNTH_RUN}.v"
SDF_FILE="$SYNTH_DIR/sdf/synth_${SYNTH_RUN}.sdf"
TSMC28_VERILOG_FILE="${TSMC28_VERILOG_FILE:-${TSMC28_ROOT:-/tsmc28}/tcbn28hpcplusbwp30p140.v}"
TB_FILE="$PROJECT_ROOT/testbenchs/rsa_apb_top/testbench.sv"
for input in "$NETLIST_FILE" "$SDF_FILE" "$TSMC28_VERILOG_FILE" "$TB_FILE"; do
    if [[ ! -r "$input" || ! -s "$input" ]]; then
        printf 'Erro: arquivo ausente, vazio ou ilegível: %s\n' "$input" >&2
        exit 1
    fi
done
# Resolve relative overrides before changing to the run directory.
TSMC28_VERILOG_FILE="$(cd -- "$(dirname -- "$TSMC28_VERILOG_FILE")" && pwd)/$(basename -- "$TSMC28_VERILOG_FILE")"
CLOCK_PERIOD_NS="${CLOCK_PERIOD_NS:-10.0}"
if [[ ! "$CLOCK_PERIOD_NS" =~ ^[0-9]+([.][0-9]+)?$ || ! "$CLOCK_PERIOD_NS" =~ [1-9] ]]; then
    printf 'Erro: CLOCK_PERIOD_NS deve ser um número positivo em ns.\n' >&2
    exit 2
fi
XRUN_BIN="${XRUN_BIN:-xrun}"
if ! command -v "$XRUN_BIN" >/dev/null 2>&1; then
    printf 'Erro: Xrun não encontrado. Configure o ambiente Cadence ou XRUN_BIN.\n' >&2
    exit 127
fi
if [[ "$XRUN_BIN" == */* ]]; then
    XRUN_BIN="$(cd -- "$(dirname -- "$XRUN_BIN")" && pwd)/$(basename -- "$XRUN_BIN")"
fi

source "$SCRIPT_DIR/report_common.sh"
reports_setup xrun_ps "$PDK"
WAVE_FILE="$PROJECT_ROOT/waveforms/MR/amba_3_apb_rsa_apb_top_tsmc28/xrun_ps/$RUN/waves_tsmc28.shm"
mkdir -p -- "$(dirname -- "$WAVE_FILE")"
SDF_CMD_FILE="$LOG_DIR/sdf_annotation_tsmc28.cmd"
SDF_LOG="$REPORT_DIR/sdf_annotation_tsmc28.log"
XRUN_LOG="$LOG_DIR/${RUN}.log"
export SYNTH_RUN NETLIST_FILE SDF_FILE TSMC28_VERILOG_FILE CLOCK_PERIOD_NS WAVE_FILE SDF_LOG

# SDF command-file strings: preserve paths with spaces, quotes or backslashes.
sdf_string() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}
cat > "$SDF_CMD_FILE" <<EOF
SDF_FILE = "$(sdf_string "$SDF_FILE")",
SCOPE = testbench.dut,
LOG_FILE = "$(sdf_string "$SDF_LOG")",
MTM_CONTROL = "MAXIMUM",
SCALE_TYPE = "FROM_MTM";
EOF

printf 'Síntese: %s\nNetlist: %s\nSDF: %s\nModelos: %s\nClock: %s ns\nRelatórios: %s\n' \
    "$SYNTH_RUN" "$NETLIST_FILE" "$SDF_FILE" "$TSMC28_VERILOG_FILE" "$CLOCK_PERIOD_NS" "$REPORT_DIR"
cd -- "$LOG_DIR"
status=0
# NTC enables delayed signals; RECREM enables combined recovery/removal checks.
"$XRUN_BIN" -64bit -sv \
    -timescale 1ns/1ps \
    +define+POST_SYNTHESIS+NTC+RECREM \
    -top testbench \
    -defparam "testbench.CLOCK_PERIOD_NS=$CLOCK_PERIOD_NS" \
    -access +rwc \
    -input "$SCRIPT_DIR/../tcl/xrun_ps_tsmc28.tcl" \
    -sdf_cmd_file "$SDF_CMD_FILE" -sdf_verbose \
    -sdfstats "$REPORT_DIR/sdf_unannotated_tsmc28.rpt" \
    -l "$XRUN_LOG" \
    -v "$TSMC28_VERILOG_FILE" \
    "$NETLIST_FILE" "$TB_FILE" "$@" || status=$?

# A stopped simulation must not be reported as a passing regression.
xrun_status=$status
if (( status == 0 )) && { [[ ! -s "$SDF_LOG" ]] || ! grep -Eq '^TEST PASS: [0-9]+ checks, 0 errors' "$XRUN_LOG"; }; then
    printf 'Erro: simulação sem confirmação de TEST PASS ou sem log de anotação SDF.\n' >&2
    status=1
fi
if [[ -f "$XRUN_LOG" ]] && grep -Eq '\*[EF],|Timing violation' "$XRUN_LOG"; then
    (( status != 0 )) || status=1
fi
{
    printf 'Synthesis: %s\nXrun exit status: %s\nFlow exit status: %s\nLog: %s\nSDF annotation: %s\nWaveform: %s\n' \
        "$SYNTH_RUN" "$xrun_status" "$status" "$XRUN_LOG" "$SDF_LOG" "$WAVE_FILE"
    if [[ -f "$XRUN_LOG" ]]; then
        grep -E '^TEST PASS:|TEST FAIL:|\[SCB\] RESUMO|\*E,|\*F,|^RSA timeout|^APB timeout|Timing violation' "$XRUN_LOG" || true
        awk '/SDF statistics:/ {capture=1} /Building instance overlay tables/ {capture=0} capture {print}' "$XRUN_LOG"
    fi
} > "$REPORT_DIR/simulation_tsmc28.rpt"
printf 'Resultado: %s\nOndas: %s\n' "$REPORT_DIR/simulation_tsmc28.rpt" "$WAVE_FILE"
exit "$status"
