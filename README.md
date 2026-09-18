# Simulação arquitetural com gem5 (RISC-V) — Avaliação 1

Trabalho da disciplina **Arquitetura de Computadores (COMP0415 — UFS)**: uso do
simulador **gem5** para executar algoritmos básicos sobre a ISA **RISC-V** e
observar métricas de microarquitetura (instruções, ciclos, IPC/CPI, cache).

Ênfase em **reprodutibilidade**: a dupla usa sistemas diferentes (**NixOS** e
**Ubuntu**), e todo o gem5 é compilado/executado dentro de um **container**
idêntico, eliminando o "na minha máquina funciona".

## Ambiente reprodutível

- Simulador: **gem5 25.1.0.1** (branch `stable`) — commit fixado em
  [`gem5_commit.txt`](gem5_commit.txt).
- Base: imagem oficial `ghcr.io/gem5/ubuntu-24.04_all-dependencies`.
- Imagem local ([`Containerfile`](Containerfile)): a base + cross-compiler
  `g++-riscv64-linux-gnu` — mesma imagem compila os exemplos **e** roda o gem5.
- Motor de container: **Podman** (NixOS) / **Docker** (Ubuntu) — comandos iguais.

## Estrutura

```
build-gem5.sh          # clona o gem5 (stable) e compila build/RISCV/gem5.opt via container
Containerfile          # imagem: deps do gem5 + toolchain RISC-V
configs_local/
  se_run.py            # config gem5 (Standard Library), modo SE, troca de CPU por argumento
exemplos/
  soma_vetor.cpp       # soma de vetor      (acesso linear à memória)
  bubble_sort.cpp      # ordenação          (desvios condicionais)
  busca_binaria.cpp    # busca binária      (acesso não-contíguo, O(log N))
  fibonacci.cpp        # recursão × iteração (pilha/chamadas)
  parse_stats.py       # parseia m5out/stats.txt -> tabela Markdown + CSV
  test_parse_stats.py  # testes do parser (20 asserts)
```
> `gem5/`, `bin/` e as saídas `m5out` não são versionados (ver `.gitignore`).

## Como reproduzir

```bash
# 1) compilar o gem5 (RISC-V) — ~30-60 min de CPU, uma vez
./build-gem5.sh

# 2) imagem local com o cross-compiler RISC-V
podman build -t gem5-riscv:local -f Containerfile .

# 3) compilar um exemplo para RISC-V estático
podman run --rm -v "$PWD":/w -w /w gem5-riscv:local \
  riscv64-linux-gnu-g++ -O2 -static exemplos/soma_vetor.cpp -o bin/soma_vetor_riscv

# 4) simular no gem5 (troque --cpu por atomic|timing|minor|o3)
podman run --rm -v "$PWD":/w -w /w gem5-riscv:local \
  ./gem5/build/RISCV/gem5.opt --outdir=resultados/soma_o3 \
  configs_local/se_run.py bin/soma_vetor_riscv --cpu o3

# 5) tabela comparativa
python3 exemplos/parse_stats.py \
  resultados/soma_atomic:ATOMIC resultados/soma_timing:TIMING resultados/soma_o3:O3
```

## Resultado de exemplo (`soma_vetor`, 3 modelos de CPU)

| Métrica | ATOMIC | TIMING | O3 |
|---|---|---|---|
| Instruções | 115710 | 115710 | 115710 |
| Ciclos | 156180 | 231036 | 54936 |
| IPC | 0.74 | 0.50 | 2.11 |
| CPI | 1.35 | 2.00 | 0.47 |

Mesmo programa, **mesmas instruções**, ciclos muito diferentes: o desempenho vem
de **como** a microarquitetura executa (o `O3`, superescalar/fora de ordem,
alcança IPC > 2). É o que um simulador de arquitetura permite observar.

## Testes

```bash
python3 exemplos/test_parse_stats.py   # 20 asserts, casos de borda + dados reais
```
