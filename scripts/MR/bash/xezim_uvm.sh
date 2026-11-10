#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=uvm_campaign.sh
source "$SCRIPT_DIR/uvm_campaign.sh"

usage() {
    cat <<'EOF'
Uso: xezim_uvm.sh [--compile] [--no-waves] [--vcd] [-- argumentos_do_xezim]

Executa a bancada UVM top_tb sobre amba_3_apb_rsa_apb_top com Xezim.
Nucleo RSA utilizado: src/MR/RSA_APB/.
Ordem das sequences: rsa_operation -> soft_reset -> test_id -> corners_exp -> xz_values.
Gera cobertura HTML e CSV automaticamente apos a simulacao (requer python3).

  --compile   Apenas compila e elabora; nao simula.
  --no-waves  Desabilita a geracao de ondas FST.
  --vcd       Exporta tambem um VCD a partir do FST (requer fst2vcd).
  -h, --help  Mostra esta ajuda.
  --          Encaminha os argumentos seguintes ao Xezim.

Variaveis de ambiente:
  XEZIM_BIN        Executavel (padrao: xezim).
  XEZIM_UVM_DIR    Biblioteca UVM: src/, raiz de release ou checkout multi-release.
                   Aceita UVM_HOME como alternativa. Padrao local:
                   <projeto>/.deps/1800.2-2017-1.0 (instalada na primeira execucao).
  XEZIM_UVM_VERSION  Release em um checkout multi-release (opcional).
  UVM_TESTNAME     Teste (padrao: test_rsa_operation).
  UVM_VERBOSITY    Mensagens UVM (padrao: UVM_MEDIUM).
  UVM_SEED         Seed (padrao: 1; aceita random).
  MAX_TIME         Limite externo Xezim (padrao: auto, 10% acima do watchdog UVM).

Campanha corners (argumentos apos --):
  +TEST_ID_ONLY=1      Executa somente leitura -> escrita -> leitura do ID.
                       Padrao: 0. Incompativel com +XZ_VALUES_ONLY=1.
  +XZ_VALUES_ONLY=1    Executa somente a campanha X/Z, sem operacoes RSA.
                       Padrao: 0 (executa todas as sequences).
                       X/Z varre os 4096 enderecos por byte em oito rotinas:
                       X, Z, e X/Z por bit, nibble e byte nas duas ordens.
  +CORNERS_CASES=N      Limita a execucao aos primeiros N casos da campanha.
                       Padrao: soma das cotas CORNERS_CASES_EXP_* definidas
                       no header UVM/top_tb_pkg.svh. Zero desabilita uma largura.
  +CORNERS_BASE_CYCLES=N     Margem inicial/erro (padrao: 1024 ciclos).
  +CORNERS_CYCLES_PER_EXP=N  Custo estimado por unidade de EXP (padrao: 256).
  +CORNERS_POLL_CYCLES=N    Intervalo minimo do polling (padrao: 16 ciclos).
  +CORNERS_MAX_READS=N      Cap diagnostico opcional; 0 desabilita (padrao).
  O watchdog UVM e calculado para os casos planejados; +UVM_TIMEOUT o substitui.
  MAX_TIME explicito limita o total e antecipa o watchdog UVM a 90% desse tempo.

Exemplo:
  ./xezim_uvm.sh
  UVM_HOME=/caminho/uvm/src ./xezim_uvm.sh
  ./xezim_uvm.sh -- +UVM_TIMEOUT=2500000,YES
EOF
}

MODE=simulate
WAVES=1
EXPORT_VCD=0
while (($#)); do
    case "$1" in
        --compile) MODE=compile; shift ;;
        --no-waves) WAVES=0; shift ;;
        --vcd) EXPORT_VCD=1; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        *) printf 'Erro: argumento desconhecido: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ "$EXPORT_VCD" == 1 && "$WAVES" == 0 ]]; then
    printf 'Erro: --vcd requer ondas habilitadas; remova --no-waves.\n' >&2
    exit 2
fi
if [[ "$MODE" == simulate && "$EXPORT_VCD" == 1 ]] && ! command -v fst2vcd >/dev/null 2>&1; then
    printf 'Erro: fst2vcd necessario para --vcd.\n' >&2
    exit 127
fi
WAVE_VIEW_SCRIPT="$SCRIPT_DIR/../tcl/xezim_uvm_wave_view.tcl"

REPORT_SCRIPT="$SCRIPT_DIR/../../validation/report_xezim_coverage.py"
if [[ "$MODE" == simulate ]]; then
    if ! command -v python3 >/dev/null 2>&1; then
        printf 'Erro: python3 necessario para gerar o relatorio HTML de cobertura.\n' >&2
        exit 127
    fi
    if [[ ! -r "$REPORT_SCRIPT" || ! -r "$SCRIPT_DIR/../../validation/xezim_coverage.html" ]]; then
        printf 'Erro: gerador ou template do relatorio de cobertura ausente.\n' >&2
        exit 1
    fi
fi

XEZIM_BIN="${XEZIM_BIN:-xezim}"
if ! command -v "$XEZIM_BIN" >/dev/null 2>&1; then
    printf 'Erro: Xezim nao encontrado: %s. Configure PATH ou XEZIM_BIN.\n' "$XEZIM_BIN" >&2
    exit 127
fi
# Resolve o executavel antes de mudar para a pasta de resultados.
XEZIM_BIN="$(command -v "$XEZIM_BIN")"
if [[ "$XEZIM_BIN" != /* ]]; then
    XEZIM_BIN="$PWD/$XEZIM_BIN"
fi

DEFAULT_UVM_DIR="$PROJECT_ROOT/.deps/1800.2-2017-1.0"
# Prepare a dependencia local somente quando nenhuma biblioteca foi indicada.
# Uma configuracao explicita invalida continua sendo reportada como erro.
if [[ -z "${XEZIM_UVM_DIR:-}" && -z "${UVM_HOME:-}" ]]; then
    if [[ ! -r "$DEFAULT_UVM_DIR/src/uvm_pkg.sv" || ! -r "$DEFAULT_UVM_DIR/src/uvm_macros.svh" ]]; then
        bash "$SCRIPT_DIR/setup_uvm.sh"
    fi
fi
export XEZIM_UVM_DIR="${XEZIM_UVM_DIR:-${UVM_HOME:-$DEFAULT_UVM_DIR}}"
if [[ ! -d "$XEZIM_UVM_DIR" ]]; then
    printf 'Erro: biblioteca UVM ausente: %s\nConfigure XEZIM_UVM_DIR ou UVM_HOME.\n' "$XEZIM_UVM_DIR" >&2
    exit 1
fi
XEZIM_UVM_DIR="$(cd -- "$XEZIM_UVM_DIR" && pwd)"
UVM_TESTNAME="${UVM_TESTNAME:-test_rsa_operation}"
UVM_VERBOSITY="${UVM_VERBOSITY:-UVM_MEDIUM}"
UVM_SEED="${UVM_SEED:-1}"
MAX_TIME="${MAX_TIME:-auto}"
TIMING_ARGS=()
if [[ "$MODE" == simulate ]]; then
    # Resolve the effective plusargs once, before starting the simulator.
    # The UVM watchdog must be installed before run_phase starts its delay.
    uvm_campaign_timing "$MAX_TIME" "$PROJECT_ROOT" xezim "$@"
fi
UVM_DIR="$PROJECT_ROOT/UVM"
uvm_campaign_sources "$PROJECT_ROOT"

LOG_ROOT="$PROJECT_ROOT/logs/MR/amba_3_apb_rsa_apb_top/xezim_uvm"
mkdir -p -- "$LOG_ROOT"
BUILD_DIR="$(mktemp -d "$LOG_ROOT/$(date '+%Y-%m-%d_%H-%M-%S')_XXXXXX")"
RUN="${BUILD_DIR##*/}"
ARGS=("--$MODE" -uvm -s top_tb -I "$UVM_DIR"
      --error-exit --timescale 1ns/1ps)
if [[ "$MODE" == simulate ]]; then ARGS+=(--max-time "$MAX_TIME"); fi
if [[ "$MODE" == simulate && "$WAVES" == 1 ]]; then
    WAVE_DIR="$PROJECT_ROOT/waveforms/MR/amba_3_apb_rsa_apb_top/xezim_uvm"
    mkdir -p -- "$WAVE_DIR"
    WAVE_FILE="$WAVE_DIR/$RUN.fst"
    ARGS+=(--fst "$WAVE_FILE" --fst-scope top_tb.th)
fi
if [[ "$MODE" == simulate ]]; then
    ARGS+=(--code-coverage=stmt,branch,toggle --code-coverage-scope top_tb.th.dut)
fi
export XEZIM_COV_DB="$BUILD_DIR/xezim_cov.json"
ARGS+=("${UVM_SOURCES[@]}" "+UVM_TESTNAME=$UVM_TESTNAME"
       "+UVM_VERBOSITY=$UVM_VERBOSITY" "+seed=$UVM_SEED" "$@" "${TIMING_ARGS[@]}")

cd -- "$BUILD_DIR"
trap 'printf "Erro na execucao Xezim. Consulte: %s\n" "$BUILD_DIR" >&2' ERR
"$XEZIM_BIN" -V > "$BUILD_DIR/version.log" 2>&1
printf 'Teste: %s | Seed: %s | Modo: %s\nLogs: %s\n' "$UVM_TESTNAME" "$UVM_SEED" "$MODE" "$BUILD_DIR"
# Registra os argumentos exatos e a biblioteca, inclusive caminhos com espacos.
{
    printf 'XEZIM_UVM_DIR=%q XEZIM_UVM_VERSION=%q XEZIM_COV_DB=%q XEZIM_JIT=%q ' \
        "$XEZIM_UVM_DIR" "${XEZIM_UVM_VERSION:-}" "$XEZIM_COV_DB" "${XEZIM_JIT:-0}"
    printf '%q ' "$XEZIM_BIN" "${ARGS[@]}"
    printf '\n'
} > "$BUILD_DIR/command.sh"
if [[ "$MODE" == simulate ]]; then
    printf 'Campanha UVM | Watchdog UVM: %s ns | Limite Xezim: %s\n' "$CAMPAIGN_TIMEOUT_NS" "$MAX_TIME"
fi
SIM_STATUS=0
if [[ "$MODE" == simulate ]]; then
    SIM_STARTED_NS="$(python3 -c 'import time; print(time.monotonic_ns())')"
fi
"$XEZIM_BIN" "${ARGS[@]}" 2>&1 | tee "$BUILD_DIR/$MODE.log" || SIM_STATUS=$?
if [[ "$MODE" == simulate ]]; then
SIM_FINISHED_NS="$(python3 -c 'import time; print(time.monotonic_ns())')"
python3 - "$BUILD_DIR/$MODE.walltime_seconds" "$SIM_STARTED_NS" "$SIM_FINISHED_NS" <<'PY_WALL'
from pathlib import Path
import sys
seconds = (int(sys.argv[3]) - int(sys.argv[2])) / 1_000_000_000
Path(sys.argv[1]).write_text(f'{seconds:.6f}\n')
print(f'[TIMING] Tempo real do Xezim: {seconds:.3f} s')
PY_WALL
fi

if [[ "$MODE" == simulate && "$WAVES" == 1 ]]; then
    # Print the wave paths also when functional assertions fail.
    printf 'Ondas FST: %s\nAbrir pinos do DUT no GTKWave: ' "$WAVE_FILE"
    printf '%q ' gtkwave "$WAVE_FILE" -S "$WAVE_VIEW_SCRIPT"
    printf '\n'
    if [[ "$EXPORT_VCD" == 1 ]]; then
        VCD_FILE="$WAVE_DIR/$RUN.vcd"
        WAVE_STATUS=0
        fst2vcd --fstname "$WAVE_FILE" --output "$VCD_FILE" \
            > "$BUILD_DIR/wave_export.log" 2>&1 || WAVE_STATUS=$?
        if [[ "$WAVE_STATUS" == 0 ]]; then
            printf 'Ondas VCD: %s\n' "$VCD_FILE"
        else
            printf 'Erro ao exportar VCD. Consulte: %s\n' "$BUILD_DIR/wave_export.log" >&2
            if [[ "$SIM_STATUS" == 0 ]]; then SIM_STATUS="$WAVE_STATUS"; fi
        fi
    fi
fi

if [[ "$MODE" == simulate ]]; then
    # $finish e o limite --max-time podem encerrar sem codigo de erro.
    # Exija o resumo UVM para detectar teste incompleto ou com erros.
    if ! uvm_campaign_passed "$BUILD_DIR/simulate.log"; then
        printf 'Erro: resumo UVM ausente ou com UVM_ERROR/UVM_FATAL. Consulte %s\n' \
            "$BUILD_DIR/simulate.log" >&2
        if [[ "$SIM_STATUS" == 0 ]]; then SIM_STATUS=1; fi
    fi
    # Gere o relatorio tambem em uma execucao com falha, se houver banco.
    # O status original e preservado; HTML gerado nao significa teste aprovado.
    REPORT_DIR="$PROJECT_ROOT/reports/MR/amba_3_apb_rsa_apb_top/xezim_uvm/$RUN"
    REPORT_STATUS=0
    python3 "$REPORT_SCRIPT" --database "$XEZIM_COV_DB" \
        --output-dir "$REPORT_DIR" --simulation-log "$BUILD_DIR/simulate.log" \
        --test-name "$UVM_TESTNAME" --seed "$UVM_SEED" \
        --walltime-file "$BUILD_DIR/simulate.walltime_seconds" \
        --simulation-exit-code "$SIM_STATUS" \
        2>&1 | tee "$BUILD_DIR/coverage_report.log" || REPORT_STATUS=$?
    if [[ "$SIM_STATUS" == 0 && "$REPORT_STATUS" != 0 ]]; then
        SIM_STATUS="$REPORT_STATUS"
    fi
    printf '%s\n' "$SIM_STATUS" > "$BUILD_DIR/simulation.exitcode"
    if [[ "$SIM_STATUS" != 0 ]]; then
        printf 'Erro na simulacao ou no relatorio. Consulte: %s\n' "$BUILD_DIR" >&2
        exit "$SIM_STATUS"
    fi
    printf 'Simulacao UVM concluida sem UVM_ERROR/UVM_FATAL.\nCobertura: %s\nHTML: %s\n' \
        "$XEZIM_COV_DB" "$REPORT_DIR/index.html"
else
    if [[ "$SIM_STATUS" != 0 ]]; then exit "$SIM_STATUS"; fi
    printf 'Compilacao e elaboracao concluidas.\n'
fi
