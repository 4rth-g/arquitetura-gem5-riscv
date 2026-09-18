# Imagem derivada: gem5 (deps oficiais) + cross-compiler RISC-V.
# Assim compilamos os exemplos e rodamos o gem5 no MESMO ambiente reprodutível.
FROM ghcr.io/gem5/ubuntu-24.04_all-dependencies:latest
RUN apt-get update \
    && apt-get install -y --no-install-recommends g++-riscv64-linux-gnu \
    && rm -rf /var/lib/apt/lists/*
