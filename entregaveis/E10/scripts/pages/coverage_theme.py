#!/usr/bin/env python3
"""Append the project theme to genhtml's CSS while preserving its layout rules."""

import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
BEGIN = "/* RSA_APB coverage theme: begin */"
END = "/* RSA_APB coverage theme: end */"


def apply_theme(report):
    stylesheet = Path(report) / "gcov.css"
    if not stylesheet.is_file():
        raise ValueError(f"CSS do relatório LCOV não encontrado: {stylesheet}")
    original = stylesheet.read_text(encoding="utf-8")
    base = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), "", original, flags=re.S).rstrip()
    theme = (ROOT / "site/assets/lcov.css").read_text(encoding="utf-8").rstrip()
    stylesheet.write_text(f"{base}\n\n{BEGIN}\n{theme}\n{END}\n", encoding="utf-8")
    return stylesheet


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path, help="Diretório HTML gerado pelo genhtml")
    args = parser.parse_args()
    try:
        print(f"[COVERAGE] Tema azul escuro aplicado: {apply_theme(args.report)}")
    except (ValueError, OSError) as error:
        parser.exit(1, f"Erro: {error}\n")
