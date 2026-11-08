#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

usage() {
    cat <<'EOF'
Uso: xezim_uvm.sh [--compile] [--no-waves] [--vcd] [-- argumentos_do_xezim]

Executa a bancada UVM top_tb sobre amba_3_apb_rsa_apb_top com Xezim.
Nucleo RSA utilizado: src/rsa32/v2/.
Ordem das sequences: rsa_operation -> soft_reset -> corners_exp -> xz_values.
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
MAX_TIME="${MAX_TIME:-auto}"
TIMING_ARGS=()
if [[ "$MODE" == simulate ]]; then
    # Resolve the effective plusargs once, before starting the simulator.
    # The UVM watchdog must be installed before run_phase starts its delay.
    TIMING_CONFIG="$(python3 - "$MAX_TIME" "$PROJECT_ROOT/UVM/top_tb_pkg.svh" "$@" <<'PY_TIMING'
from decimal import Decimal
from pathlib import Path
import re
import sys

external, clock_file, *args = sys.argv[1:]
def first(name, default):
    prefix = '+' + name + '='
    return next((arg[len(prefix):] for arg in args if arg.startswith(prefix)), default)

def number(name, default, minimum=1):
    value = int(first(name, str(default)))
    if value < minimum:
        raise SystemExit(f'Erro: {name} deve ser >= {minimum}.')
    return value

header = Path(clock_file).read_text()
widths = (4, 8, 12, 16, 32)
quotas = []
for width in widths:
    name = f'CORNERS_CASES_EXP_{width}'
    match = re.search(r'\bparameter\s+integer\s+' + name + r'\s*=\s*(\d+)\s*;', header)
    if not match:
        raise SystemExit(f'Erro: {name} em top_tb_pkg.svh deve ser um literal inteiro nao negativo.')
    quotas.append(int(match[1]))
xz_only = number('XZ_VALUES_ONLY', 0, 0)
if xz_only not in (0, 1):
    raise SystemExit('Erro: XZ_VALUES_ONLY deve ser 0 ou 1.')
total_cases = sum(quotas)
if not xz_only and (not total_cases or total_cases > (1 << 31) - 1):
    raise SystemExit('Erro: a soma das cotas em top_tb_pkg.svh deve estar entre 1 e 2147483647.')
cases = number('CORNERS_CASES', total_cases, 0 if xz_only else 1)
if not xz_only and cases > total_cases:
    raise SystemExit(f'Erro: CORNERS_CASES deve estar entre 1 e {total_cases}, conforme as cotas de top_tb_pkg.svh.')
base = number('CORNERS_BASE_CYCLES', 1024)
slope = number('CORNERS_CYCLES_PER_EXP', 256)
poll = number('CORNERS_POLL_CYCLES', 16)
read_cap = number('CORNERS_MAX_READS', 0, 0)
clock = re.search(r'parameter integer CLOCK_PERIOD_NS\s*=\s*(\d+)\s*;', header)
if not clock or int(clock[1]) <= 0:
    raise SystemExit('Erro: CLOCK_PERIOD_NS deve ser um literal inteiro positivo para calcular o watchdog.')
clock_ns = int(clock[1])
def case_shape(index):
    for ordinal in range(max(quotas)):
        for width, quota in zip(widths, quotas):
            if ordinal < quota:
                if index == 0:
                    return width, ordinal % 10
                index -= 1
    raise ValueError('Indice fora das cotas de top_tb_pkg.svh.')

def case_cycles(index):
    width, kind = case_shape(index)
    operation = 0 if kind == 8 else base if kind == 9 else base + slope * (1 << width)
    if read_cap:
        operation = min(operation, read_cap * (poll + 3))
    # Transfer/setup/recovery allowance, separate from arithmetic latency.
    return 25_000 + operation

# Per address: read/write/read (three cycles each), plus one idle cycle.
# Each pattern restores five registers and ends with four retention reads;
# five final writes restore a known state after the entire campaign.
addr_width = re.search(r'parameter integer ADDR_WIDTH\s*=\s*(\d+)\s*;', header)
xz_patterns = re.search(r'parameter integer XZ_VALUES_PATTERN_COUNT\s*=\s*(\d+)\s*;', header)
if not addr_width or not xz_patterns:
    raise SystemExit('Erro: parametros da campanha X/Z ausentes em top_tb_pkg.svh.')
xz_cycles = int(xz_patterns[1]) * ((1 << int(addr_width[1])) * 10 + 27) + 15
cycles = 100_000 + xz_cycles + (0 if xz_only else sum(case_cycles(i) for i in range(cases)))
derived_ns = (cycles + (cycles + 3) // 4) * clock_ns
user_timeout = first('UVM_TIMEOUT', None)
if user_timeout is not None:
    if not re.fullmatch(r'\d+(?:,(?:YES|NO))?', user_timeout):
        raise SystemExit('Erro: +UVM_TIMEOUT deve conter nanossegundos inteiros e, opcionalmente, YES/NO.')
    timeout_ns = int(user_timeout.split(',')[0])
else:
    timeout_ns = derived_ns
if external == 'auto':
    fallback_ns = timeout_ns if timeout_ns else derived_ns
    external = f'{(fallback_ns * 11 + 9) // 10}ns'
else:
    match = re.fullmatch(r'(\d+(?:\.\d+)?)(ps|ns|us|ms|s)?', external)
    if not match:
        raise SystemExit('Erro: MAX_TIME deve usar ps/ns/us/ms/s ou auto.')
    scale = {'ps': Decimal('.001'), 'ns': 1, 'us': 1000, 'ms': 1_000_000, 's': 1_000_000_000}
    external_ns = Decimal(match[1]) * scale[match[2] or 'ns']
    if external_ns <= 0:
        raise SystemExit('Erro: MAX_TIME deve ser positivo.')
    if user_timeout is None:
        timeout_ns = min(timeout_ns, max(1, int(external_ns * Decimal('.9'))))
# Simulation uses 1 ps precision; keep the limits inside signed 64-bit ticks.
maximum_ns = ((1 << 63) - 1) // 1000
external_match = re.fullmatch(r'(\d+(?:\.\d+)?)(ps|ns|us|ms|s)?', external)
external_ns = Decimal(external_match[1]) * {'ps': Decimal('.001'), 'ns': 1, 'us': 1000, 'ms': 1_000_000, 's': 1_000_000_000}[external_match[2] or 'ns']
if timeout_ns > maximum_ns or external_ns > maximum_ns:
    raise SystemExit('Erro: orcamento excede o intervalo de tempo de 64 bits com precisao de 1 ps.')
print(external, timeout_ns, int(user_timeout is None), cases, base, slope, poll, read_cap)
PY_TIMING
)"
    read -r MAX_TIME CAMPAIGN_TIMEOUT_NS AUTO_UVM_TIMEOUT TIMING_CASES TIMING_BASE TIMING_SLOPE TIMING_POLL TIMING_READ_CAP <<< "$TIMING_CONFIG"
    USER_ARGS=("$@")
    add_timing_default() {
        local timing_name="$1" timing_value="$2" timing_arg
        for timing_arg in "${USER_ARGS[@]}"; do
            if [[ "$timing_arg" == "+$timing_name="* ]]; then return; fi
        done
        TIMING_ARGS+=("+$timing_name=$timing_value")
    }
    add_timing_default CORNERS_CASES "$TIMING_CASES"
    add_timing_default CORNERS_BASE_CYCLES "$TIMING_BASE"
    add_timing_default CORNERS_CYCLES_PER_EXP "$TIMING_SLOPE"
    add_timing_default CORNERS_POLL_CYCLES "$TIMING_POLL"
    add_timing_default CORNERS_MAX_READS "$TIMING_READ_CAP"
    if [[ "$AUTO_UVM_TIMEOUT" == 1 ]]; then TIMING_ARGS+=("+UVM_TIMEOUT=$CAMPAIGN_TIMEOUT_NS,YES"); fi
fi
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
      --error-exit --timescale 1ns/1ps)
if [[ "$MODE" == simulate ]]; then ARGS+=(--max-time "$MAX_TIME"); fi
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
    printf 'Campanha UVM (inclui X/Z) | Watchdog UVM: %s ns | Limite Xezim: %s\n' "$CAMPAIGN_TIMEOUT_NS" "$MAX_TIME"
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
