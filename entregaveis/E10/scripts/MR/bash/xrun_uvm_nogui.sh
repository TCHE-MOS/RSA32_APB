#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=uvm_campaign.sh
source "$SCRIPT_DIR/uvm_campaign.sh"

usage() {
    cat <<'EOF'
Uso: xrun_uvm_nogui.sh [plusargs_e_opcoes_do_xrun...]

Executa a bancada UVM completa (top_tb) sobre amba_3_apb_rsa_apb_top com
Xcelium em batch, seguida do relatorio de cobertura IMC.
Gera ondas SHM e VCD em waveforms/MR/amba_3_apb_rsa_apb_top/uvm/.
Nucleo RSA utilizado: src/MR/RSA_APB/.
Ordem das sequences: rsa_operation -> soft_reset -> test_id -> corners_exp -> xz_values.
Assertions SVA de todos os cenarios incluidas via UVM/testbench.svh.

Variaveis de ambiente:
  UVM_TESTNAME   Teste (padrao: test_rsa_operation).
  UVM_VERBOSITY  Mensagens UVM (padrao: UVM_MEDIUM).
  UVM_SEED       Seed passada a -svseed (padrao: 1; aceita random).
  UVM_PYTHON     Python 3.6+ para calcular o watchdog (padrao: /usr/bin/python3).
  MAX_TIME       Limita o watchdog UVM a 90% deste tempo (ex.: 10ms).
                 Padrao: auto, orcamento calculado para a campanha completa.
                 No Xcelium, watchdog automatico limitado a 9000 s simulados.

Plusargs da campanha (mesmos do xezim_uvm.sh):
  +TEST_ID_ONLY=1 | +XZ_VALUES_ONLY=1 | +CORNERS_CASES=N
  +CORNERS_BASE_CYCLES=N | +CORNERS_CYCLES_PER_EXP=N | +CORNERS_POLL_CYCLES=N
  +CORNERS_MAX_READS=N | +UVM_TIMEOUT=<ns>,YES
  Valores omitidos usam as cotas de UVM/top_tb_pkg.svh; o watchdog UVM e
  calculado para os casos planejados (o padrao do UVM 1.2, 9200 s, e menor
  que a campanha completa).

Exemplo:
  ./xrun_uvm_nogui.sh
  ./xrun_uvm_nogui.sh +CORNERS_CASES=5
  UVM_SEED=random ./xrun_uvm_nogui.sh +XZ_VALUES_ONLY=1
EOF
}
for arg in "$@"; do
    if [[ "$arg" == -h || "$arg" == --help ]]; then usage; exit 0; fi
done

RUN="amba_3_apb_rsa_apb_top_uvm_$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$PROJECT_ROOT/logs/MR/amba_3_apb_rsa_apb_top/xrun_uvm/nogui"
WAVE_DIR="$PROJECT_ROOT/waveforms/MR/amba_3_apb_rsa_apb_top/uvm"
UVM_DIR="$PROJECT_ROOT/UVM"
COV_DIR="$PROJECT_ROOT/coverage/MR/amba_3_apb_rsa_apb_top/uvm"
UVM_TESTNAME="${UVM_TESTNAME:-test_rsa_operation}"
UVM_VERBOSITY="${UVM_VERBOSITY:-UVM_MEDIUM}"
UVM_SEED="${UVM_SEED:-1}"

for tool in xrun imc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Erro: '$tool' nao encontrado no PATH. Execute o setup das ferramentas Cadence." >&2
        exit 1
    fi
done

uvm_campaign_sources "$PROJECT_ROOT"
uvm_campaign_timing "${MAX_TIME:-auto}" "$PROJECT_ROOT" xcelium "$@"

mkdir -p -- "$LOG_DIR" "$WAVE_DIR" "$COV_DIR"
export RUN WAVE_FILE="$WAVE_DIR/${RUN}.shm"
export VCD_FILE="$WAVE_DIR/${RUN}.vcd"
LOG_FILE="$LOG_DIR/${RUN}.log"
cd -- "$LOG_DIR"

printf 'Teste: %s | Seed: %s | Watchdog UVM: %s ns\n' \
    "$UVM_TESTNAME" "$UVM_SEED" "$CAMPAIGN_TIMEOUT_NS"
printf 'Orcamento conservador da campanha: %s ns (tempo simulado)\n' "$CAMPAIGN_BUDGET_NS"
printf 'Ondas SHM: %s\nOndas VCD: %s\n' "$WAVE_FILE" "$VCD_FILE"

SIM_STATUS=0
xrun -64bit -sv -uvm -uvmhome CDNS-1.2 \
    -timescale 1ns/1ps \
    -input "$SCRIPT_DIR/../tcl/xrun_uvm_nogui.tcl" \
    -top top_tb \
    -access +rwc \
    -incdir "$UVM_DIR" \
    -svseed "$UVM_SEED" \
    -coverage all \
    -abvrecordcoverall \
    -covoverwrite \
    -covdut amba_3_apb_rsa_apb_top \
    -covworkdir "$COV_DIR" \
    -covtest "$RUN" \
    -l "$LOG_FILE" \
    "${UVM_SOURCES[@]}" \
    "+UVM_TESTNAME=$UVM_TESTNAME" \
    "+UVM_VERBOSITY=$UVM_VERBOSITY" \
    "$@" "${TIMING_ARGS[@]}" || SIM_STATUS=$?

# xrun retorna 0 mesmo com UVM_ERROR; exija o resumo UVM sem erros.
if ! uvm_campaign_passed "$LOG_FILE"; then
    printf 'Erro: resumo UVM ausente ou com UVM_ERROR/UVM_FATAL. Consulte %s\n' "$LOG_FILE" >&2
    if [[ "$SIM_STATUS" == 0 ]]; then SIM_STATUS=1; fi
fi

# Gere a cobertura tambem em execucao com falha, se o banco existir.
COV_RUN="$COV_DIR/scope/$RUN"
if [[ -d "$COV_RUN" ]]; then
    COV_STATUS=0
    "$SCRIPT_DIR/imc.sh" "$COV_RUN" || COV_STATUS=$?
    if [[ "$SIM_STATUS" == 0 ]]; then SIM_STATUS="$COV_STATUS"; fi
else
    printf 'Aviso: banco de cobertura nao gerado: %s\n' "$COV_RUN" >&2
fi

echo "Teste:     $UVM_TESTNAME (seed $UVM_SEED)"
echo "Log:       $LOG_FILE"
echo "Ondas SHM: $WAVE_FILE"
echo "Ondas VCD: $VCD_FILE"
echo "Cobertura: $COV_RUN"
if [[ "$SIM_STATUS" != 0 ]]; then
    echo "Simulacao UVM com falha (status $SIM_STATUS)." >&2
    exit "$SIM_STATUS"
fi
echo "Simulacao UVM concluida sem UVM_ERROR/UVM_FATAL."
