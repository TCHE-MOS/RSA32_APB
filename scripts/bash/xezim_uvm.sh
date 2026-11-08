#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

usage() {
    cat <<'EOF'
Uso: xezim_uvm.sh [--compile] [--no-waves] [-- argumentos_do_xezim]

Executa a bancada UVM top_tb sobre amba_3_apb_rsa_apb_top com Xezim.
Gera cobertura HTML e CSV automaticamente apos a simulacao (requer python3).

  --compile   Apenas compila e elabora; nao simula.
  --no-waves  Desabilita a geracao de ondas FST.
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
  MAX_TIME         Limite de tempo simulado (padrao: 2.5ms).

Exemplo:
  ./xezim_uvm.sh
  UVM_HOME=/caminho/uvm/src ./xezim_uvm.sh
  ./xezim_uvm.sh -- +UVM_TIMEOUT=2500000,YES
EOF
}

MODE=simulate
WAVES=1
while (($#)); do
    case "$1" in
        --compile) MODE=compile; shift ;;
        --no-waves) WAVES=0; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        *) printf 'Erro: argumento desconhecido: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

REPORT_SCRIPT="$SCRIPT_DIR/../validation/report_xezim_coverage.py"
if [[ "$MODE" == simulate ]]; then
    if ! command -v python3 >/dev/null 2>&1; then
        printf 'Erro: python3 necessario para gerar o relatorio HTML de cobertura.\n' >&2
        exit 127
    fi
    if [[ ! -r "$REPORT_SCRIPT" || ! -r "$SCRIPT_DIR/../validation/xezim_coverage.html" ]]; then
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
MAX_TIME="${MAX_TIME:-2.5ms}"
RTL_DIR="$PROJECT_ROOT/src/amba_3_apb"
UVM_DIR="$PROJECT_ROOT/UVM"

# testbench.svh inclui interface, pacotes, classes, harness e top_tb.
# Os arquivos incluidos nao devem ser compilados separadamente.
SOURCES=(
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_kogge_stone_adder.sv"
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_mult.sv"
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_mod.sv"
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_ctrl.sv"
    "$PROJECT_ROOT/src/rsa32/v2/rsa32_core_top.sv"
    "$RTL_DIR/amba_3_apb_adrec.sv"
    "$RTL_DIR/amba_3_apb_data_o_mux.sv"
    "$RTL_DIR/amba_3_apb_data_io_top.sv"
    "$RTL_DIR/amba_3_apb_control.sv"
    "$RTL_DIR/amba_3_apb_regbank.sv"
    "$RTL_DIR/amba_3_apb_reset.sv"
    "$RTL_DIR/amba_3_apb_rsa_wrapper_control.sv"
    "$RTL_DIR/amba_3_apb_rsa_wrapper_data.sv"
    "$RTL_DIR/amba_3_apb_rsa_wrapper_top.sv"
    "$RTL_DIR/amba_3_apb_rsa_apb_top.sv"
    "$UVM_DIR/testbench.svh"
)
for source_file in "${SOURCES[@]}"; do
    if [[ ! -r "$source_file" ]]; then
        printf 'Erro: fonte ausente ou sem permissao de leitura: %s\n' "$source_file" >&2
        exit 1
    fi
done

LOG_ROOT="$PROJECT_ROOT/logs/amba_3_apb_rsa_apb_top/xezim_uvm"
mkdir -p -- "$LOG_ROOT"
BUILD_DIR="$(mktemp -d "$LOG_ROOT/$(date '+%Y-%m-%d_%H-%M-%S')_XXXXXX")"
RUN="${BUILD_DIR##*/}"
ARGS=("--$MODE" -uvm -s top_tb -I "$UVM_DIR"
      --error-exit --timescale 1ns/1ps --max-time "$MAX_TIME")
if [[ "$MODE" == simulate && "$WAVES" == 1 ]]; then
    WAVE_DIR="$PROJECT_ROOT/waveforms/amba_3_apb_rsa_apb_top/xezim_uvm"
    mkdir -p -- "$WAVE_DIR"
    WAVE_FILE="$WAVE_DIR/$RUN.fst"
    ARGS+=(--fst "$WAVE_FILE" --fst-scope top_tb.th)
fi
if [[ "$MODE" == simulate ]]; then
    ARGS+=(--code-coverage=stmt,branch,toggle --code-coverage-scope top_tb.th.dut)
fi
export XEZIM_COV_DB="$BUILD_DIR/xezim_cov.json"
ARGS+=("${SOURCES[@]}" "+UVM_TESTNAME=$UVM_TESTNAME"
       "+UVM_VERBOSITY=$UVM_VERBOSITY" "+seed=$UVM_SEED" "$@")

cd -- "$BUILD_DIR"
trap 'printf "Erro na execucao Xezim. Consulte: %s\n" "$BUILD_DIR" >&2' ERR
"$XEZIM_BIN" -V > "$BUILD_DIR/version.log" 2>&1
printf 'Teste: %s | Seed: %s | Modo: %s\nLogs: %s\n' "$UVM_TESTNAME" "$UVM_SEED" "$MODE" "$BUILD_DIR"
# Registra os argumentos exatos e a biblioteca, inclusive caminhos com espacos.
{
    printf 'XEZIM_UVM_DIR=%q XEZIM_UVM_VERSION=%q XEZIM_COV_DB=%q ' \
        "$XEZIM_UVM_DIR" "${XEZIM_UVM_VERSION:-}" "$XEZIM_COV_DB"
    printf '%q ' "$XEZIM_BIN" "${ARGS[@]}"
    printf '\n'
} > "$BUILD_DIR/command.sh"
SIM_STATUS=0
"$XEZIM_BIN" "${ARGS[@]}" 2>&1 | tee "$BUILD_DIR/$MODE.log" || SIM_STATUS=$?

if [[ "$MODE" == simulate ]]; then
    # $finish e o limite --max-time podem encerrar sem codigo de erro.
    # Exija o resumo UVM para detectar teste incompleto ou com erros.
    if ! awk '
        /^[[:space:]]*UVM_ERROR[[:space:]]*:/ { errors = $NF; saw_errors = 1 }
        /^[[:space:]]*UVM_FATAL[[:space:]]*:/ { fatals = $NF; saw_fatals = 1 }
        /^\[SVA\] Contagens finais UVM: ERROR=[0-9]+ \| FATAL=[0-9]+$/ {
            split($5, final_errors, "="); errors = final_errors[2]
            split($7, final_fatals, "="); fatals = final_fatals[2]
        }
        END { exit !(saw_errors && saw_fatals && errors == 0 && fatals == 0) }
    ' "$BUILD_DIR/simulate.log"; then
        printf 'Erro: resumo UVM ausente ou com UVM_ERROR/UVM_FATAL. Consulte %s\n' \
            "$BUILD_DIR/simulate.log" >&2
        if [[ "$SIM_STATUS" == 0 ]]; then SIM_STATUS=1; fi
    fi
    # Gere o relatorio tambem em uma execucao com falha, se houver banco.
    # O status original e preservado; HTML gerado nao significa teste aprovado.
    REPORT_DIR="$PROJECT_ROOT/reports/amba_3_apb_rsa_apb_top/xezim_uvm/$RUN"
    REPORT_STATUS=0
    python3 "$REPORT_SCRIPT" --database "$XEZIM_COV_DB" \
        --output-dir "$REPORT_DIR" --simulation-log "$BUILD_DIR/simulate.log" \
        --test-name "$UVM_TESTNAME" --seed "$UVM_SEED" \
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
    if [[ "$WAVES" == 1 ]]; then
        printf 'Ondas: %s\n' "$WAVE_FILE"
    fi
else
    if [[ "$SIM_STATUS" != 0 ]]; then exit "$SIM_STATUS"; fi
    printf 'Compilacao e elaboracao concluidas.\n'
fi
