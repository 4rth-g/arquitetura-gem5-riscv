# Imagem derivada: gem5 (deps oficiais) + cross-compiler RISC-V.
# Assim compilamos os exemplos e rodamos o gem5 no MESMO ambiente reprodutível.
#
# Tudo fixado para que a imagem seja igual em qualquer máquina, em qualquer data:
#  - base pelo digest (não pela tag :latest, que muda);
#  - pacotes do apt lidos de um snapshot datado do arquivo Ubuntu
#    (snapshot.ubuntu.com), com as versões explícitas.
FROM ghcr.io/gem5/ubuntu-24.04_all-dependencies@sha256:a9b10b20b91d32610d628b0ee7041ac7767d361900f5c7306f83bdf0d981c57c
ARG APT_SNAPSHOT=20260925T000000Z
RUN apt-get update --snapshot "$APT_SNAPSHOT" \
    && apt-get install -y --no-install-recommends --snapshot "$APT_SNAPSHOT" \
         g++-riscv64-linux-gnu=4:13.2.0-7ubuntu1 \
         g++-13-riscv64-linux-gnu=13.3.0-6ubuntu2~24.04.1cross1 \
         binutils-riscv64-linux-gnu=2.42-4ubuntu2.10 \
         libc6-dev-riscv64-cross=2.39-0ubuntu8cross1 \
    && rm -rf /var/lib/apt/lists/*
