#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
RSA32_DIR="$PROJECT_ROOT/RSA32_opt"
RUN="rsa_core_32_opt_$(date '+%Y-%m-%d_%H-%M-%S')"

# Directories:
LOG_DIR="$PROJECT_ROOT/logs/RSA32/rsa_core_32_opt/xrun"
IMC_LOG_DIR="$PROJECT_ROOT/logs/RSA32/rsa_core_32_opt/imc"
WAVE_DIR="$PROJECT_ROOT/waveforms/RSA32/rsa_core_32_opt"
COV_DIR="$PROJECT_ROOT/coverage/RSA32/rsa_core_32_opt"
REPORT_DIR="$PROJECT_ROOT/reports/RSA32/rsa_core_32_opt"

# Innovus Export:
EXPORT_DIR="$RSA32_DIR/ps_files/rsa_core_32_opt/innovus/export"
NETLIST_FILE="$EXPORT_DIR/rsa_core.v"
SDF_FILE="$EXPORT_DIR/rsa_core.sdf"

# GSCLib045 Standard-Cell Library:
LIB_FILE="/home/cadence/DDI221/JLS221/etc/rtls/tutorial/libraries/verilog/typical.v"

# Testbench:
TB_FILE="$RSA32_DIR/testbenches/testbench.sv"
TB_TOP="testbench"
DUT_SCOPE="testbench.duv"

# SDF Annotation:
SDF_CMD_FILE="$LOG_DIR/${RUN}.sdf.cmd"
SDF_LOG="$LOG_DIR/${RUN}_sdf.log"

mkdir -p -- "$LOG_DIR" "$IMC_LOG_DIR" "$WAVE_DIR" "$COV_DIR" "$REPORT_DIR"
for required_file in "$NETLIST_FILE" "$SDF_FILE" "$TB_FILE" "$LIB_FILE"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'Erro: arquivo necessário não encontrado: %s\n' "$required_file" >&2
        exit 1
    fi
done
for tool in xrun imc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Erro: %s não encontrado no PATH; configure as ferramentas Cadence.\n' "$tool" >&2
        exit 127
    fi
done
cd -- "$LOG_DIR"

# ======================================
# SDF Back-Annotation Configuration
# ======================================

cat > "$SDF_CMD_FILE" <<EOF
SDF_FILE = "$SDF_FILE",
SCOPE = $DUT_SCOPE,
LOG_FILE = "$SDF_LOG",
MTM_CONTROL = "TYPICAL",
SCALE_TYPE = "FROM_MTM";
EOF

# ======================================
# Post-Route Gate-Level Simulation
# Cadence Xcelium
# ======================================

xrun -64bit \
    -timescale 1ns/1ps \
    -top "$TB_TOP" \
    -access +rwc \
    -sdf_cmd_file "$SDF_CMD_FILE" \
    -sdf_verbose \
    -coverage all \
    -covoverwrite \
    -covworkdir "$COV_DIR" \
    -covtest "$RUN" \
    -l "$LOG_DIR/${RUN}.log" \
    -v "$LIB_FILE" \
    "$NETLIST_FILE" \
    "$TB_FILE" \
    "+VCD=$WAVE_DIR/${RUN}.vcd"

# ======================================
# Coverage Report - Cadence IMC
# ======================================

COV_RUN="$COV_DIR/scope/$RUN"
REPORT_FILE="$REPORT_DIR/${RUN}_coverage.rpt"

(
    cd -- "$IMC_LOG_DIR"
    imc -load "$COV_RUN" \
        -execcmd "report -summary -cumulative on -inst -local off -out \"$REPORT_FILE\""
)

echo "Simulacao gate-level e relatorio de cobertura concluidos."
echo "Netlist:   $NETLIST_FILE"
echo "SDF:       $SDF_FILE"
echo "Biblioteca: $LIB_FILE"
echo "Log:       $LOG_DIR/${RUN}.log"
echo "SDF Log:   $SDF_LOG"
echo "Waveform:  $WAVE_DIR/${RUN}.vcd"
echo "Cobertura: $COV_RUN"
echo "Relatorio: $REPORT_FILE"
