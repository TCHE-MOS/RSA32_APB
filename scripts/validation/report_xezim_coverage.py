#!/usr/bin/env python3
"""Render xezim's native code_coverage database without changing its counts."""

import argparse
import csv
import html
import json
import os
from pathlib import Path
import re


METRICS = ('statement', 'branch', 'toggle')
DESIGNS = {
    'rtl': ('RTL APB RSA', 'UVM + RTL APB RSA',
            'Cobertura do RTL APB RSA e núcleo RSA v2, coletada pelo Xezim.',
            'Cobertura dos escopos RTL instrumentados sob top_tb.th.dut. '
            'As SVAs comparam RESULT com uma referência de exponenciação modular; '
            'consulte no log se RSA_RESULT_VALUE foi exercitada. '
            'Ausência de erros UVM não comprova aprovação funcional.'),
}


def read_log(path, exit_code=0):
    text = path.read_text() if path and path.is_file() else ''
    counts = dict(re.findall(
        r'^\s*(UVM_INFO|UVM_WARNING|UVM_ERROR|UVM_FATAL)\s*:\s*(\d+)\s*$',
        text, re.MULTILINE))
    final_counts = re.search(
        r'^\[SVA\] Contagens finais UVM: ERROR=(\d+) \| FATAL=(\d+)$', text, re.MULTILINE)
    if final_counts:
        counts.update(UVM_ERROR=final_counts[1], UVM_FATAL=final_counts[2])
    test = re.search(r'\[RNTST\] Running test (\S+?)\.\.\.', text)
    config = {'TEST': test[1]} if test else {}
    if exit_code or any(int(counts.get(key, 0)) for key in ('UVM_ERROR', 'UVM_FATAL')):
        result = 'FALHA NA EXECUÇÃO'
    elif all(key in counts for key in ('UVM_ERROR', 'UVM_FATAL')):
        result = 'SEM ERROS UVM'
    else:
        result = 'SEM CONCLUSÃO'
    return result, config, counts


def render_html(code, metrics, units, database_path, out, design, result, config, counts):
    esc = html.escape
    label, title, description, note = DESIGNS[design]
    cards = []
    names = {'statement': 'INSTRUÇÕES', 'branch': 'DECISÕES', 'toggle': 'TRANSIÇÕES'}
    for metric in metrics:
        tally = code[metric]
        covered, total = tally['covered'], tally['total']
        percent = 100 * covered / total if total else 0
        display = f'{percent:.2f}%' if total else 'N/A'
        detail = f'{covered:,} de {total:,} pontos cobertos'.replace(',', '.')
        foot = 'Duas direções por bit rastreado' if metric == 'toggle' else 'Pontos contados por instância'
        cards.append(f'''<article class="card {'' if total else 'na'}">
<div class="metric-top"><span class="metric-name">{metric.title()}</span><span class="metric-tag">{names[metric]}</span></div>
<div class="metric-value">{display}</div><div class="metric-detail">{detail}</div>
<div class="track" role="img" aria-label="{metric}: {display}"><div class="fill" style="width:{percent:.4f}%"></div></div>
<p class="metric-foot">{foot if total else 'Nenhum ponto instrumentado nesta métrica'}</p></article>''')
    headers = '<th><button data-key="name">Módulo</button></th><th><button data-key="instances">Instâncias</button></th>'
    headers += ''.join(f'<th><button data-key="{m}">{m.title()}</button></th>' for m in metrics)
    rows = []
    for unit in units:
        partial = any(unit[m]['covered'] < unit[m]['total'] for m in metrics)
        zero = any(unit[m]['total'] > 0 and not unit[m]['covered'] for m in metrics)
        attrs = (f'data-name="{esc(unit["design_unit"], quote=True)}" '
                 f'data-instances="{unit["instances"]}" data-partial="{int(partial)}" data-zero="{int(zero)}"')
        cells = f'<td class="unit">{esc(unit["design_unit"])}</td><td class="numeric">{unit["instances"]}</td>'
        for metric in metrics:
            tally = unit[metric]
            covered, total = tally['covered'], tally['total']
            percent = 100 * covered / total if total else -1
            attrs += f' data-{metric}="{percent:.4f}"'
            display = f'{percent:.2f}%' if total else 'N/A'
            cells += (f'<td class="coverage-cell"><div class="numbers"><b>{display}</b>'
                      f'<small>{covered}/{total}</small></div><div class="track">'
                      f'<div class="fill" style="width:{max(0, percent):.4f}%"></div></div></td>')
        rows.append(f'<tr {attrs}>{cells}</tr>')

    chips = [('Escopos', str(len(code['scopes'])))]
    chips += [(label, config[key]) for label, key in
              [('Teste', 'TEST'), ('Seed configurada', 'SEED')]
              if key in config]
    campaign = '<div class="campaign-label"><strong>Resumo UVM</strong>Contagens registradas no log; não validam o cálculo RSA</div>'
    for name, key, css in [('Informações', 'UVM_INFO', ''), ('Avisos', 'UVM_WARNING', ''),
                           ('Erros', 'UVM_ERROR', 'fail'), ('Fatais', 'UVM_FATAL', 'fail')]:
        campaign += f'<div class="stat {css}">{name}<b>{esc(counts.get(key, "—"))}</b></div>'

    replacements = {
        'TITLE': esc(title), 'DESIGN_LABEL': esc(label), 'DESCRIPTION': esc(description),
        'DESIGN_NOTE': esc(note), 'RESULT': esc(result),
        'RESULT_CLASS': {'SEM ERROS UVM': 'pass', 'FALHA NA EXECUÇÃO': 'fail'}.get(result, ''),
        'METRIC_COUNT': str(len(metrics)), 'CARDS': ''.join(cards), 'CAMPAIGN': campaign,
        'HEADERS': headers, 'ROWS': ''.join(rows), 'UNIT_COUNT': str(len(units)),
        'CHIPS': ''.join(f'<span class="chip">{esc(k)}<b>{esc(v)}</b></span>' for k, v in chips),
        'DB_LINK': esc(os.path.relpath(database_path.resolve(), out.resolve()), quote=True),
        'DB_PATH': esc(str(database_path.resolve())),
    }
    template = Path(__file__).with_name('xezim_coverage.html').read_text()
    return re.sub(r'@@([A-Z_]+)@@', lambda match: replacements[match[1]], template)


def cell(row, metric):
    tally = row[metric]
    covered, total = tally['covered'], tally['total']
    if not total:
        return 'N/A (0/0)'
    return f'{covered}/{total} ({100 * covered / total:.2f}%)'


def write_table(path, rows, name, metrics):
    identifiers = [name] + (['design_unit'] if name != 'design_unit' else []) + ['instances']
    fields = identifiers + [f'{metric}_{key}' for metric in metrics
               for key in ('covered', 'total', 'percent')]
    with path.open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            entry = {key: row.get(key, '') for key in identifiers}
            for metric in metrics:
                tally = row[metric]
                entry[f'{metric}_covered'] = tally['covered']
                entry[f'{metric}_total'] = tally['total']
                entry[f'{metric}_percent'] = (
                    100 * tally['covered'] / tally['total'] if tally['total'] else '')
            writer.writerow(entry)


def write_uncovered(path, scopes):
    with path.open('w', newline='') as handle:
        fields = ['metric', 'scope', 'design_unit', 'file', 'line', 'kind',
                  'signal', 'bit', 'direction', 'count']
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for scope in scopes:
            base = {key: scope[key] for key in ('scope', 'design_unit')}
            for site in scope.get('statements', []):
                if not site['count']:
                    writer.writerow(dict(base, metric='statement',
                                         **{key: site[key] for key in
                                            ('file', 'line', 'kind', 'count')}))
            for site in scope.get('branches', []):
                for arm in site['arms']:
                    if not arm['count']:
                        writer.writerow(dict(base, metric='branch', file=site['file'],
                                             line=arm['line'], kind=arm['arm'], count=0))
            for site in scope.get('toggles', []):
                for direction in ('rise', 'fall'):
                    for bit, count in enumerate(site[direction]):
                        if not count:
                            writer.writerow(dict(base, metric='toggle', signal=site['signal'],
                                                 bit=bit, direction=direction, count=0))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--simulation-log', type=Path)
    parser.add_argument('--design-kind', choices=DESIGNS, default='rtl')
    parser.add_argument('--test-name')
    parser.add_argument('--seed')
    parser.add_argument('--simulation-exit-code', type=int, default=0)
    args = parser.parse_args()
    try:
        database = json.loads(args.database.read_text())
        code = database.get('code_coverage')
        if not code or not code.get('scopes'):
            raise ValueError('banco sem code coverage; execute xezim_uvm.sh com instrumentação do DUT')
        metrics = [metric for metric in METRICS if metric in code]
        if not metrics or not any(code[metric]['total'] for metric in metrics):
            raise ValueError('nenhum ponto instrumentado; confira --code-coverage-scope')
        scopes = code['scopes']
        units = code.get('design_units', [])
        result, config, counts = read_log(args.simulation_log, args.simulation_exit_code)
        if args.test_name:
            config['TEST'] = args.test_name
        if args.seed:
            config['SEED'] = args.seed

        out = args.output_dir
        out.mkdir(parents=True, exist_ok=True)
        lines = [f'Code coverage — xezim / APB RSA {DESIGNS[args.design_kind][1]}',
                 f'Banco: {args.database.resolve()}',
                 f'Resultado UVM registrado: {result}',
                 f'Tempo final do banco (unidades do simulador): {database["sim_time"]}',
                 f'Escopos instrumentados: {len(scopes)}']
        lines += [f'{metric}: {cell(code, metric)}' for metric in metrics]
        note = (DESIGNS[args.design_kind][3] + ' Toggle conta duas direcoes por bit. '
                'Total zero e N/A. Cobertura nao implica aprovacao funcional. '
                'Totais por design unit unem hits de suas instancias; '
                'os totais globais contam os pontos por instancia.')
        lines += [note]
        (out / 'summary.txt').write_text('\n'.join(lines) + '\n')
        write_table(out / 'scopes.csv', scopes, 'scope', metrics)
        write_table(out / 'design_units.csv', units, 'design_unit', metrics)
        write_uncovered(out / 'uncovered.csv', scopes)

        document = render_html(code, metrics, units, args.database, out,
                               args.design_kind, result, config, counts)
        (out / 'index.html').write_text(document)
        print('\n'.join(lines))
        print(f'[REPORT] Code coverage HTML={out / "index.html"}')
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'ERRO: {error}\n')


if __name__ == '__main__':
    main()
