#!/usr/bin/env python3
"""Testes do parse_stats.py — casos de borda + dados reais. Sem dependências."""
import sys, tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import parse_stats as ps

falhas = 0
def check(cond, msg):
    global falhas
    print(("  ok  " if cond else "FALHA ") + msg)
    if not cond:
        falhas += 1

def stats_de(texto: str) -> dict:
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
        f.write(texto); p = Path(f.name)
    return ps.ler_stats(p)

print("== 1. escalares básicos ==")
s = stats_de(
    "---------- Begin Simulation Statistics ----------\n"
    "simInsts   1000   # comentário\n"
    "board.processor.cores.core.ipc   1.5   # ratio\n"
    "---------- End Simulation Statistics   ----------\n")
check(s.get("simInsts") == 1000.0, "simInsts lido")
check(s.get("board.processor.cores.core.ipc") == 1.5, "ipc lido")
check(ps.casa(s, r"\.ipc$") == 1.5, "casa() acha ipc por sufixo")

print("== 2. ignora separadores, histogramas e linhas não-escalares ==")
s = stats_de(
    "---------- Begin Simulation Statistics ----------\n"
    "simInsts   42\n"
    "algum.dist::0   3   4   5   # distribuição (2ª col numérica, pega 3)\n"
    "algum.texto   (Unspecified)   # não numérico -> ignora\n"
    "linha_sozinha\n")
check(s.get("simInsts") == 42.0, "escalar lido em meio a ruído")
check("algum.texto" not in s, "linha não-numérica ignorada")
check("linha_sozinha" not in s, "linha de 1 token ignorada")

print("== 3. múltiplos dumps: mantém a última ocorrência ==")
s = stats_de("simInsts 10\nsimInsts 20\nsimInsts 99\n")
check(s.get("simInsts") == 99.0, "última ocorrência vence")

print("== 4. arquivo vazio ==")
s = stats_de("")
check(s == {}, "vazio -> dict vazio")

print("== 5. casa(): sem match -> None; case-insensitive ==")
s = {"system.cpu.branchPred.condIncorrect": 7.0}
check(ps.casa(s, r"nao_existe") is None, "sem match retorna None")
check(ps.casa(s, r"branch.*incorrect") == 7.0, "branch mispred casa (case-insensitive)")

print("== 6. fmt(): None, nan, inteiro, float, científico ==")
check(ps.fmt(None) == "—", "None -> travessão")
check(ps.fmt(float('nan')) == "—", "nan -> travessão")
check(ps.fmt(156180.0) == "156180", "float inteiro sem casas")
check(ps.fmt(0.4748) == "0.4748", "float com casas")
check("e" in ps.fmt(1.56e-04), "valor pequeno em notação científica")

print("== 7. resolver(): pasta e rótulo ==")
with tempfile.TemporaryDirectory() as d:
    (Path(d) / "stats.txt").write_text("simInsts 5\n")
    rot, p = ps.resolver(f"{d}:MEU-ROTULO")
    check(p.name == "stats.txt" and rot == "MEU-ROTULO", "pasta:rótulo resolvido")
    rot2, p2 = ps.resolver(d)
    check(p2.name == "stats.txt", "pasta sem rótulo aponta p/ stats.txt")

print("== 8. dados REAIS (resultados/soma_atomic) ==")
real = Path(__file__).parent.parent / "resultados" / "soma_atomic" / "stats.txt"
if real.exists():
    s = ps.ler_stats(real)
    ins = ps.casa(s, r"^simInsts$")
    check(ins is not None and ins > 0, "simInsts real > 0")
    check(ps.casa(s, r"\.numCycles$") is not None, "numCycles real presente")
    check(ps.casa(s, r"\.ipc$") is not None, "ipc real presente")
else:
    print("  (pulado: sem resultados reais ainda)")

print()
print("RESULTADO:", "TODOS PASSARAM ✅" if falhas == 0 else f"{falhas} FALHA(S) ❌")
sys.exit(1 if falhas else 0)
