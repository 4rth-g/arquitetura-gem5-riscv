#!/usr/bin/env bash
# Build reprodutível do gem5 (ISA RISC-V) via container (Podman ou Docker).
# Toda a compilação acontece dentro do container: o sistema do host
# (NixOS, Ubuntu, Arch...) não interfere.
#
# Etapas (todas idempotentes — rodar de novo só refaz o que falta):
#   1) clone do gem5 no commit fixado em gem5_commit.txt
#   2) imagem base (pelo digest) + imagem local gem5-riscv:local (Containerfile)
#   3) scons build/RISCV/gem5.opt
#   4) libm5 (RISC-V) — necessária para marcar a região de interesse (ROI)
#   5) gem5_build_info.txt — versão/commit/flags do binário, para o artigo
#
# Uso: ./build-gem5.sh        (JOBS=n para limitar o paralelismo)
set -o pipefail

BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
GEM5_DIR="$BUILD_DIR/gem5"
LOG="$BUILD_DIR/build.log"
ENGINE="$(command -v podman || command -v docker)"
BASE="ghcr.io/gem5/ubuntu-24.04_all-dependencies@sha256:a9b10b20b91d32610d628b0ee7041ac7767d361900f5c7306f83bdf0d981c57c"
IMG="gem5-riscv:local"
GEM5_COMMIT="$(cat "$BUILD_DIR/gem5_commit.txt")"
JOBS="${JOBS:-$(nproc)}"

cd "$BUILD_DIR" || exit 1
rm -f "$BUILD_DIR"/STATUS_*
: > "$LOG"
echo "== INICIO $(date -Is) ==" | tee -a "$LOG"

step() { echo "-- $* --" | tee -a "$LOG"; }
falha() {
  echo "FAIL $1" > "$BUILD_DIR/STATUS_FAIL"
  echo "== FALHOU: $1 ==" | tee -a "$LOG"
  exit 1
}
run() { "$ENGINE" run --rm -v "$GEM5_DIR":/gem5 -w /gem5 "$@"; }

# 1) gem5 no commit fixado (busca rasa só daquele commit)
if [ ! -d "$GEM5_DIR/.git" ]; then
  step "clone gem5 @ $GEM5_COMMIT"
  { git init -q "$GEM5_DIR" \
    && git -C "$GEM5_DIR" remote add origin https://github.com/gem5/gem5.git \
    && git -C "$GEM5_DIR" fetch -q --depth 1 origin "$GEM5_COMMIT" \
    && git -C "$GEM5_DIR" checkout -q FETCH_HEAD; } >>"$LOG" 2>&1 || falha "clone"
fi
[ "$(git -C "$GEM5_DIR" rev-parse HEAD)" = "$GEM5_COMMIT" ] \
  || falha "gem5/ está em $(git -C "$GEM5_DIR" rev-parse HEAD), esperado $GEM5_COMMIT"
step "gem5 @ $GEM5_COMMIT"

# 2) imagens
step "$ENGINE pull (base fixada por digest)"
"$ENGINE" pull "$BASE" >>"$LOG" 2>&1 || falha "pull"
step "$ENGINE build $IMG"
"$ENGINE" build -t "$IMG" -f Containerfile . >>"$LOG" 2>&1 || falha "build da imagem"

# 3) gem5.opt
# (o scons do gem5 religa o binário a cada chamada, ~7 min; como o commit é
#  fixo, um gem5.opt existente é reaproveitado — REBUILD=1 força a compilação)
SECONDS=0
if [ -x "$GEM5_DIR/build/RISCV/gem5.opt" ] && [ -z "${REBUILD:-}" ]; then
  step "gem5.opt já compilado — reaproveitando (REBUILD=1 para refazer)"
else
  step "scons build/RISCV/gem5.opt -j$JOBS"
  run "$BASE" scons build/RISCV/gem5.opt -j"$JOBS" >>"$LOG" 2>&1 \
    && [ -x "$GEM5_DIR/build/RISCV/gem5.opt" ] || falha "scons gem5.opt (${SECONDS}s)"
fi
DUR=$SECONDS

# 4) libm5 para RISC-V (usa o cross-compiler da imagem local)
step "scons libm5 (riscv)"
run -w /gem5/util/m5 "$IMG" \
  scons riscv.CROSS_COMPILE=riscv64-linux-gnu- build/riscv/out/m5 >>"$LOG" 2>&1 \
  && [ -f "$GEM5_DIR/util/m5/build/riscv/out/libm5.a" ] || falha "libm5"

# 5) informação de build (gem5 não tem --version; -B mostra versão e flags)
step "gem5.opt -B -> gem5_build_info.txt"
run "$IMG" build/RISCV/gem5.opt -B > "$BUILD_DIR/gem5_build_info.txt" 2>>"$LOG" \
  || falha "gem5.opt -B"

echo "OK (gem5.opt: ${DUR}s)" > "$BUILD_DIR/STATUS_OK"
echo "== SUCESSO (gem5.opt em ${DUR}s) — FIM $(date -Is) ==" | tee -a "$LOG"
