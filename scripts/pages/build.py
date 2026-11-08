#!/usr/bin/env python3
"""Build GitHub Pages from module READMEs and actual simulation/LCOV artifacts."""

import argparse
from datetime import datetime, timezone
from html import escape
import json
from pathlib import Path
import re
import shutil
import subprocess

from documents import build_documents
from coverage_theme import apply_theme

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "https://github.com/MattGrossi12/RSA_APB_32-bit"
REPORTS = ROOT / "reports/amba_3_apb_rsa_apb_top/verilator"


def read_required(path):
    if not path.is_file():
        raise ValueError(f"Arquivo ausente: {path.relative_to(ROOT)}. Execute os scripts de simulação antes do build.")
    return path.read_text(encoding="utf-8")


def plain_markdown(text):
    text = re.sub(r"\[([^]]+)\]\([^)]*\)", r"\1", text)
    return re.sub(r"\s+", " ", text.replace("**", "").replace("`", "")).strip()


def metric(covered, total):
    return {"covered": covered, "total": total,
            "percent": round(100 * covered / total, 1) if total else None}


def relative_source(source):
    # SF can contain the local checkout path or the GitHub runner's checkout path.
    source = source.replace("\\", "/")
    if "/src/" in source:
        source = "src/" + source.split("/src/", 1)[1]
    path = Path(source)
    if not source.startswith("src/") or ".." in path.parts:
        raise ValueError(f"Fonte LCOV fora do RTL: {source}")
    return source


def parse_lcov(text):
    files = []
    sanitized = []
    for record in text.split("end_of_record"):
        source = None
        lines, branches = {}, {}
        for row in record.splitlines():
            if row.startswith("SF:"):
                source = relative_source(row[3:])
                sanitized.append("SF:" + source)
            else:
                if row.strip():
                    sanitized.append(row)
                if row.startswith("DA:"):
                    number, count, *_ = row[3:].split(",")
                    lines[number] = lines.get(number, 0) + int(count)
                elif row.startswith("BRDA:"):
                    number, block, branch, count = row[5:].split(",", 3)
                    key = (number, block, branch)
                    branches[key] = branches.get(key, 0) + (0 if count == "-" else int(count))
        if source:
            sanitized.append("end_of_record")
            files.append({"source": source, "name": Path(source).name,
                          "lines": metric(sum(count > 0 for count in lines.values()), len(lines)),
                          "branches": metric(sum(count > 0 for count in branches.values()), len(branches)),
                          "report": f"coverage/{source}.gcov.html"})
    if not files:
        raise ValueError("LCOV não contém arquivos RTL.")
    totals = {kind: metric(sum(file[kind]["covered"] for file in files),
                           sum(file[kind]["total"] for file in files))
              for kind in ("lines", "branches")}
    return {"files": files, **totals}, "\n".join(sanitized) + "\n"


def parse_native(text):
    summary = text.split("Hierarchy Coverage Summary:", 1)[0]
    return {kind: metric(int(covered), int(total))
            for kind, covered, total in re.findall(
                r"^\s+(\w+)\s*:\s*[\d.]+%\s*\(\s*(\d+)/\s*(\d+)\)", summary, re.M)
            if int(total)}


def parse_simulation(text):
    result = re.search(r"TEST (PASS|FAIL): (\d+) checks, (\d+) errors", text)
    rounds = re.search(r"regbank=(\d+) rodadas \| RSA=(\d+) rodadas", text)
    if not result or not rounds:
        raise ValueError("Log sem resumo completo da scoreboard; execute novamente a simulação do topo.")
    status, checks, errors = result.groups()
    excerpts = []
    phases = re.split(r"(?=^\[SCB\] )", text, flags=re.M)
    wanted = [("reset", "Reset", "Valores apos reset"),
              ("registers", f"Regbank · {rounds[1]}/{rounds[1]}", f"Rodada {int(rounds[1]):02d}/{rounds[1]} | Retencao"),
              ("rsa-first", "RSA · 01/" + rounds[2], "RSA 01/" + rounds[2] + " | Execucao"),
              ("rsa-last", f"RSA · {rounds[2]}/{rounds[2]}", f"RSA {int(rounds[2]):02d}/{rounds[2]} | Execucao")]
    for key, label, marker in wanted:
        phase = next((phase for phase in phases if phase.startswith("[SCB] " + marker)), None)
        if phase is None:
            raise ValueError(f"Fase ausente no log: {marker}")
        excerpts.append({"id": key, "label": label, "text": phase.strip()})
    return {"status": status, "checks": int(checks), "errors": int(errors),
            "registerRounds": int(rounds[1]), "rsaRounds": int(rounds[2]), "excerpts": excerpts}


def git(*args):
    result = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def build(output):
    images = [ROOT / f"images/img{number}.png" for number in range(1, 21)]
    missing_images = [path.relative_to(ROOT).as_posix() for path in images if not path.is_file()]
    if missing_images:
        raise ValueError("Imagens da página ausentes: " + ", ".join(missing_images)
                         + ". Confira os arquivos images/img1.png até images/img20.png antes do build.")
    output.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / "site/assets", output / "assets", dirs_exist_ok=True)
    image_output = output / "assets/images"
    image_output.mkdir(parents=True, exist_ok=True)
    for path in images:
        # Some source files have a .png name but contain SVG. Serve them with
        # the proper extension so GitHub Pages sends an image/svg+xml MIME type.
        suffix = ".svg" if b"<svg" in path.read_bytes()[:2048].lower() else path.suffix
        shutil.copyfile(path, image_output / path.with_suffix(suffix).name)
    for folder in ("reference", "artifacts"):
        (output / folder).mkdir(exist_ok=True)

    modules = json.loads(read_required(ROOT / "site/modules.json"))
    for module in modules:
        readme = read_required(ROOT / module["readme"])
        introduction = re.search(r"^## 1\.[^\n]*\n+(.*?)(?=\n\n|\n##|\Z)", readme, re.M | re.S)
        diagrams = re.findall(r"```mermaid\s*\n(.*?)```", readme, re.S)
        if not introduction or not diagrams:
            raise ValueError(f"README sem objetivo/diagrama Mermaid: {module['readme']}")
        module["summary"] = module.get("summary") or plain_markdown(introduction[1])
        module["diagrams"] = [diagram.strip() for diagram in diagrams]
        module["documentation"] = "reference/" + Path(module["readme"]).with_suffix(".html").name

    supplemental_diagrams = []
    for identifier, label, source in (
        ("project-overview", "Visão geral do projeto", "README.md"),
        ("rsa-integration", "Integração do núcleo RSA", "src/rsa32/README_rsa_apb_top.md"),
    ):
        diagrams = re.findall(r"```mermaid\s*\n(.*?)```", read_required(ROOT / source), re.S)
        if not diagrams:
            raise ValueError(f"README sem diagrama Mermaid: {source}")
        supplemental_diagrams.append({
            "id": identifier, "label": label,
            "documentation": "reference/" + Path(source).with_suffix(".html").name,
            "diagrams": [diagram.strip() for diagram in diagrams],
        })

    lcov, normalized_lcov = parse_lcov(read_required(REPORTS / "coverage.info"))
    for module in modules:
        if not any(file["source"] == module["source"] for file in lcov["files"]):
            raise ValueError(f"Módulo sem resultados LCOV: {module['name']}")
    native = parse_native(read_required(REPORTS / "coverage_summary.txt"))
    simulations = {}
    for simulator in ("iverilog", "verilator"):
        path = ROOT / f"logs/amba_3_apb_rsa_apb_top/{simulator}/simulation.log"
        text = read_required(path).replace(str(ROOT), ".")
        simulations[simulator] = parse_simulation(text)
        (output / f"artifacts/{simulator}.log").write_text(text, encoding="utf-8")
    if simulations["iverilog"]["checks"] != simulations["verilator"]["checks"]:
        raise ValueError("Os logs Icarus e Verilator têm quantidades diferentes de comparações.")

    if not (REPORTS / "html/index.html").is_file():
        raise ValueError("Relatório HTML ausente: instale genhtml e execute verilator.sh novamente.")
    shutil.copytree(REPORTS / "html", output / "coverage", dirs_exist_ok=True)
    missing_reports = [file["report"] for file in lcov["files"]
                       if not (output / file["report"]).is_file()]
    if missing_reports:
        raise ValueError("Relatório LCOV sem páginas anotadas: " + ", ".join(missing_reports)
                         + ". Execute verilator.sh novamente para gerar o relatório completo.")
    apply_theme(output / "coverage")
    # genhtml stores its original command line; keep local machine paths out of the site.
    (output / "coverage/cmd_line").unlink(missing_ok=True)
    for file in (output / "coverage").rglob("*.html"):
        file.write_text(file.read_text(encoding="utf-8").replace(str(ROOT), "."), encoding="utf-8")
    (output / "artifacts/coverage.info").write_text(normalized_lcov, encoding="utf-8")
    shutil.copyfile(REPORTS / "coverage_summary.txt", output / "artifacts/coverage_summary.txt")
    shutil.copyfile(ROOT / "docs/plano_teste_amba_3_apb_rsa_apb_top.md", output / "reference/plano_teste.md")
    references = {
        "README.md": "README.md",
        "testbenchs/rsa_apb_top/testbench.sv": "testbench.sv",
        "legacy/testbenchs/amba_3_apb_adrec/testbench.sv": "testbench_adrec.sv",
        "scripts/bash/iverilog.sh": "iverilog.sh",
        "scripts/bash/verilator.sh": "verilator.sh",
        "scripts/pages/build.py": "build.py",
        ".github/workflows/pages.yml": "pages.yml",
        "docs/apb_protocol.pdf": "apb_protocol.pdf",
        "docs/apb_integration.pdf": "apb_integration.pdf",
    }
    for source, name in references.items():
        shutil.copyfile(ROOT / source, output / "reference" / name)

    document_count = build_documents(ROOT, output, REPOSITORY, git("rev-parse", "HEAD"), references)

    log_path = ROOT / "logs/amba_3_apb_rsa_apb_top/verilator/simulation.log"
    metadata = {"repository": REPOSITORY, "commit": git("rev-parse", "HEAD"),
                "dirty": bool(git("status", "--porcelain", "--untracked-files=no")),
                "generatedAt": datetime.now(timezone.utc).isoformat(),
                "simulatedAt": datetime.fromtimestamp(log_path.stat().st_mtime, timezone.utc).isoformat()}
    data = {"meta": metadata, "modules": modules, "supplementalDiagrams": supplemental_diagrams,
            "simulations": simulations,
            "lcov": lcov, "native": native}
    serialized = json.dumps(data, ensure_ascii=False, indent=2).replace("<", "\\u003c")
    (output / "assets/data.js").write_text("window.PROJECT_DATA = " + serialized + ";\n", encoding="utf-8")
    html = read_required(ROOT / "site/index.html")
    for token, value in {"CHECKS": simulations["iverilog"]["checks"], "MODULES": len(modules),
                         "ERRORS": max(simulation["errors"] for simulation in simulations.values()),
                         "REGISTER_ROUNDS": simulations["iverilog"]["registerRounds"],
                         "RSA_ROUNDS": simulations["iverilog"]["rsaRounds"],
                         "LCOV_LINES": str(lcov["lines"]["percent"]).replace(".", ","),
                         "LCOV_BRANCHES": str(lcov["branches"]["percent"]).replace(".", ",")}.items():
        html = html.replace("{{" + token + "}}", escape(str(value)))
    (output / "index.html").write_text(html, encoding="utf-8")
    (output / ".nojekyll").touch()
    print(f"Página gerada em {output}; {len(modules)} módulos, {document_count} documentos formatados, {simulations['iverilog']['checks']} comparações, LCOV completo.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "_site")
    args = parser.parse_args()
    try:
        build(args.output.resolve())
    except (ValueError, OSError) as error:
        parser.exit(1, f"Erro: {error}\n")
