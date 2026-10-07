# gem5-build — gem5 (RISC-V) reprodutível via container

Infraestrutura do trabalho de **Arquitetura de Computadores (COMP0415 — UFS)**:
compila o **gem5** para a ISA **RISC-V** dentro de um container, com commit
fixado, para que qualquer máquina tenha exatamente o mesmo simulador.

Os exemplos, a execução das simulações, a análise, o artigo e os slides ficam
no repositório [`comp0415-gem5`](https://github.com/4rth-g/comp0415-gem5),
clonado **ao lado** deste — que deve ficar numa pasta chamada `gem5-build`:

```bash
git clone https://github.com/4rth-g/arquitetura-gem5-riscv.git gem5-build
git clone https://github.com/4rth-g/comp0415-gem5.git
```

## Ambiente reprodutível

Tudo o que define o simulador está fixado e versionado:

| O quê | Como é fixado |
|---|---|
| gem5 **25.1.0.1** | commit em [`gem5_commit.txt`](gem5_commit.txt); o script busca exatamente esse commit |
| Imagem base `ghcr.io/gem5/ubuntu-24.04_all-dependencies` | **digest** sha256 (não a tag `:latest`, que muda) |
| Cross-compiler RISC-V (g++ 13.3.0, binutils 2.42, glibc 2.39) | versões explícitas, lidas do **snapshot** de 25/09/2026 do arquivo Ubuntu (`apt --snapshot`) |
| Binário gerado | [`gem5_build_info.txt`](gem5_build_info.txt) (`gem5.opt -B`: versão e opções de build) |

A mesma imagem `gem5-riscv:local` compila os exemplos **e** roda o gem5.
Motor de container: **Podman** ou **Docker** (detectado sozinho).

Verificação: binários dos exemplos compilados com esta imagem são idênticos
bit a bit aos compilados com a imagem anterior ao snapshot — o
`make verificar` do `comp0415-gem5` confere isso em qualquer máquina.

## Estrutura

```
build-gem5.sh          # clone no commit fixado + imagens + gem5.opt + libm5 + build info
Containerfile          # imagem: deps do gem5 (digest) + toolchain RISC-V (snapshot apt)
gem5_commit.txt        # commit exato do gem5 usado
gem5_build_info.txt    # saída de `gem5.opt -B` (gerada pelo script)
```
> `gem5/` (clone + binário de ~970 MB) não é versionado — `build-gem5.sh` reconstrói.

## Como reproduzir

```bash
./build-gem5.sh          # ~1h15 na 1ª vez (-j8 num i5-1245U); depois, segundos
```

O script é idempotente: com o `gem5.opt` já compilado, só confere commit e
imagens, e refaz `libm5` e o build info (`REBUILD=1` força recompilar o gem5;
`JOBS=n` limita o paralelismo). Progresso em `build.log`; resultado em
`STATUS_OK` ou `STATUS_FAIL`.

Resultado: `gem5/build/RISCV/gem5.opt`, `gem5/util/m5/build/riscv/out/libm5.a`
(marcação de região de interesse) e a imagem `gem5-riscv:local`, usados pelo
`comp0415-gem5`.
