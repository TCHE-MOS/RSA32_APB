#!/usr/bin/env python3
"""Orcamento da campanha UVM compartilhado por xezim_uvm.sh e xrun_uvm_*.sh.

Uso: uvm_campaign_timing.py MAX_TIME top_tb_pkg.svh xcelium|xezim [plusargs...]
Saida: MAX_TIME TIMEOUT_NS AUTO_TIMEOUT CASES BASE SLOPE POLL READ_CAP BUDGET_NS
"""
from decimal import Decimal
from pathlib import Path
import re
import sys

external, clock_file, simulator, *args = sys.argv[1:]
if simulator not in ('xcelium', 'xezim'):
    raise SystemExit('Erro: simulador deve ser xcelium ou xezim.')
# Xcelium 24.03 overflows near 2**63 fs even with a 1 ns / 1 ps testbench.
# Leave headroom below that absolute limit. Splitting delays does not help.
maximum_ns = 9_200_000_000_000 if simulator == 'xcelium' else ((1 << 63) - 1) // 1000
automatic_maximum_ns = 9_000_000_000_000 if simulator == 'xcelium' else maximum_ns * 10 // 11
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
id_only = number('TEST_ID_ONLY', 0, 0)
if id_only not in (0, 1) or (id_only and xz_only):
    raise SystemExit('Erro: TEST_ID_ONLY deve ser 0 ou 1 e nao pode ser combinado com XZ_VALUES_ONLY=1.')
focused = bool(xz_only or id_only)
total_cases = sum(quotas)
if not focused and (not total_cases or total_cases > (1 << 31) - 1):
    raise SystemExit('Erro: a soma das cotas em top_tb_pkg.svh deve estar entre 1 e 2147483647.')
cases = number('CORNERS_CASES', total_cases, 0 if focused else 1)
if not focused and cases > total_cases:
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
id_cycles = 16  # Three APB transfers, plus allowance for scenario boundaries.
cycles = (100_000 + (0 if id_only else xz_cycles) + (0 if xz_only else id_cycles)
          + (0 if focused else sum(case_cycles(i) for i in range(cases))))
derived_ns = (cycles + (cycles + 3) // 4) * clock_ns
user_timeout = first('UVM_TIMEOUT', None)
if user_timeout is not None:
    if not re.fullmatch(r'\d+(?:,(?:YES|NO))?', user_timeout):
        raise SystemExit('Erro: +UVM_TIMEOUT deve conter nanossegundos inteiros e, opcionalmente, YES/NO.')
    timeout_ns = int(user_timeout.split(',')[0])
else:
    timeout_ns = derived_ns
if user_timeout is not None and timeout_ns > maximum_ns:
    raise SystemExit(f'Erro: +UVM_TIMEOUT excede o limite seguro de {simulator}: {maximum_ns} ns.')
if external == 'auto':
    if user_timeout is None:
        timeout_ns = min(timeout_ns, automatic_maximum_ns)
    fallback_ns = timeout_ns if timeout_ns else derived_ns
    external = f'{min((fallback_ns * 11 + 9) // 10, maximum_ns)}ns'
else:
    match = re.fullmatch(r'(\d+(?:\.\d+)?)(ps|ns|us|ms|s)?', external)
    if not match:
        raise SystemExit('Erro: MAX_TIME deve usar ps/ns/us/ms/s ou auto.')
    scale = {'ps': Decimal('.001'), 'ns': 1, 'us': 1000, 'ms': 1_000_000, 's': 1_000_000_000}
    external_ns = Decimal(match[1]) * scale[match[2] or 'ns']
    if external_ns <= 0:
        raise SystemExit('Erro: MAX_TIME deve ser positivo.')
    if external_ns > maximum_ns:
        raise SystemExit(f'Erro: MAX_TIME excede o limite seguro de {simulator}: {maximum_ns} ns.')
    if user_timeout is None:
        timeout_ns = min(timeout_ns, max(1, int(external_ns * Decimal('.9'))))
if user_timeout is None and derived_ns > automatic_maximum_ns:
    print(f'Aviso: orcamento conservador da campanha = {derived_ns} ns '
          f'({derived_ns / 1e9:.3f} s simulados). Watchdog aplicado = {timeout_ns} ns. '
          f'O limite de {simulator} impede garantir todo esse orcamento em uma execucao; '
          'se o watchdog expirar, a campanha sera reportada como falha.', file=sys.stderr)
print(external, timeout_ns, int(user_timeout is None), cases, base, slope, poll, read_cap, derived_ns)
