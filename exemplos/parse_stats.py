#!/usr/bin/env python3
"""Parseia arquivos m5out/stats.txt do gem5 e monta uma tabela comparativa.

Uso:
    parse_stats.py RUN[:RÓTULO] [RUN[:RÓTULO] ...] [--csv saida.csv]

    RUN pode ser um stats.txt OU uma pasta contendo stats.txt.
    Exemplos:
        parse_stats.py m5out/stats.txt
        parse_stats.py res/soma_timing:soma-TIMING res/soma_o3:soma-O3 --csv tab.csv

Saída: tabela Markdown no stdout (pronta p/ o artigo) e, opcionalmente, CSV.
Robusto a variações de nome entre versões/config do gem5 (usa regex).
"""
from __future__ import annotations
import re
import sys
from pathlib import Path


def ler_stats(path: Path) -> dict[str, float]:
    """stats.txt -> {nome: valor}. Pega só linhas escalares 'nome valor ...'.
    Em arquivos com vários dumps, mantém a última ocorrência."""
    stats: dict[str, float] = {}
    for linha in path.read_text(errors="ignore").splitlines():
        s = linha.strip()
        if not s or s.startswith("-"):          # separadores Begin/End
            continue
        partes = s.split()
        if len(partes) < 2:
            continue
        nome, val = partes[0], partes[1]
        try:
            stats[nome] = float(val)             # ignora histogramas/distribuições
        except ValueError:
            continue
    return stats


# (rótulo na tabela, regex para casar a chave). Primeira chave que casar vence.
METRICAS: list[tuple[str, str]] = [
    ("Instruções (simInsts)", r"^simInsts$"),
    ("Ops (simOps)",          r"^simOps$"),
    ("Ciclos",                r"\.numCycles$"),
    ("IPC",                   r"\.ipc$"),
    ("CPI",                   r"\.cpi$"),
    ("Tempo simulado (s)",    r"^simSeconds$"),
    ("Ticks",                 r"^simTicks$"),
    ("Host (s)",              r"^hostSeconds$"),
    ("L1D miss rate",         r"l1d.*[Mm]iss[_ ]?[Rr]ate.*total|dcache.*miss_rate"),
    ("L1I miss rate",         r"l1i.*[Mm]iss[_ ]?[Rr]ate.*total|icache.*miss_rate"),
    ("Branch mispred",        r"(branch|Branch).*(mispred|Mispred|incorrect)"),
]


def casa(stats: dict[str, float], padrao: str):
    rx = re.compile(padrao, re.IGNORECASE)
    for nome, val in stats.items():
        if rx.search(nome):
            return val
    return None


def fmt(v) -> str:
    if v is None:
        return "—"
    if isinstance(v, float):
        if v != v:                       # nan
            return "—"
        if v == int(v) and abs(v) >= 1:
            return f"{int(v)}"
        if abs(v) < 1e-3 or abs(v) >= 1e6:
            return f"{v:.3e}"
        return f"{v:.4g}"
    return str(v)


def resolver(arg: str) -> tuple[str, Path]:
    """'caminho:rótulo' -> (rótulo, Path do stats.txt)."""
    if ":" in arg and not arg[1:3] == ":\\":
        alvo, rotulo = arg.rsplit(":", 1)
    else:
        alvo, rotulo = arg, ""
    p = Path(alvo)
    if p.is_dir():
        p = p / "stats.txt"
    if not rotulo:
        rotulo = p.parent.name or p.stem
    return rotulo, p


def main() -> None:
    args = sys.argv[1:]
    csv_out = None
    if "--csv" in args:
        i = args.index("--csv")
        csv_out = args[i + 1]
        args = args[:i] + args[i + 2:]
    if not args:
        print(__doc__)
        sys.exit(1)

    rotulos: list[str] = []
    colunas: list[dict[str, float]] = []
    for a in args:
        rot, p = resolver(a)
        if not p.exists():
            print(f"# aviso: não achei {p}", file=sys.stderr)
            continue
        rotulos.append(rot)
        colunas.append(ler_stats(p))

    if not colunas:
        print("Nenhum stats.txt válido.", file=sys.stderr)
        sys.exit(1)

    # monta linhas
    linhas = []
    for label, padrao in METRICAS:
        valores = [casa(c, padrao) for c in colunas]
        if all(v is None for v in valores):
            continue                      # métrica ausente em todos → oculta
        linhas.append((label, valores))

    # tabela Markdown
    header = "| Métrica | " + " | ".join(rotulos) + " |"
    sep    = "|" + "---|" * (len(rotulos) + 1)
    print(header)
    print(sep)
    for label, valores in linhas:
        print(f"| {label} | " + " | ".join(fmt(v) for v in valores) + " |")

    # CSV opcional
    if csv_out:
        import csv
        with open(csv_out, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["metrica", *rotulos])
            for label, valores in linhas:
                w.writerow([label, *[("" if v is None else v) for v in valores]])
        print(f"\n# CSV salvo em {csv_out}", file=sys.stderr)


if __name__ == "__main__":
    main()
