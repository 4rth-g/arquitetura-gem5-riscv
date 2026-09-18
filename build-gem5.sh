#!/usr/bin/env bash
# Build do gem5 (ISA RISC-V) via Podman + imagem oficial de dependências.
# NixOS-friendly: toda a compilação acontece dentro do container (FHS).
# Loga tudo e grava marcadores de status para acompanhamento.
set -o pipefail

BUILD_DIR="$HOME/src/gem5-build"
GEM5_DIR="$BUILD_DIR/gem5"
LOG="$BUILD_DIR/build.log"
IMG="ghcr.io/gem5/ubuntu-24.04_all-dependencies:latest"
JOBS=8

cd "$BUILD_DIR" || exit 1
rm -f "$BUILD_DIR"/STATUS_*
: > "$LOG"
echo "== INICIO $(date -Is) ==" | tee -a "$LOG"

step() { echo "-- $* --" | tee -a "$LOG"; }

# 1) clone raso do gem5 (branch stable)
if [ ! -d "$GEM5_DIR/.git" ]; then
  step "git clone gem5 (stable, shallow)"
  git clone --depth 1 --branch stable https://github.com/gem5/gem5.git "$GEM5_DIR" >>"$LOG" 2>&1 \
    || { echo "FAIL clone" >"$BUILD_DIR/STATUS_FAIL"; echo "== FALHOU no clone ==" | tee -a "$LOG"; exit 1; }
else
  step "gem5 já clonado — reutilizando"
fi

# registra o commit exato (reprodutibilidade — vai pro artigo)
git -C "$GEM5_DIR" rev-parse HEAD > "$BUILD_DIR/gem5_commit.txt" 2>>"$LOG"

# 2) baixa imagem de dependências
step "podman pull $IMG"
podman pull "$IMG" >>"$LOG" 2>&1 \
  || { echo "FAIL pull" >"$BUILD_DIR/STATUS_FAIL"; echo "== FALHOU no pull ==" | tee -a "$LOG"; exit 1; }

# 3) compila build/RISCV/gem5.opt dentro do container
step "scons build/RISCV/gem5.opt -j$JOBS (dentro do container)"
SECONDS=0
podman run --rm -v "$GEM5_DIR":/gem5 -w /gem5 "$IMG" \
  scons build/RISCV/gem5.opt -j"$JOBS" >>"$LOG" 2>&1
RC=$?
DUR=$SECONDS

if [ $RC -eq 0 ] && [ -x "$GEM5_DIR/build/RISCV/gem5.opt" ]; then
  echo "OK em ${DUR}s" > "$BUILD_DIR/STATUS_OK"
  echo "== SUCESSO em ${DUR}s ($((DUR/60)) min) ==" | tee -a "$LOG"
  "$GEM5_DIR/build/RISCV/gem5.opt" --version >>"$LOG" 2>&1 || true
else
  echo "rc=$RC dur=${DUR}s" > "$BUILD_DIR/STATUS_FAIL"
  echo "== FALHOU no build (rc=$RC, ${DUR}s) ==" | tee -a "$LOG"
  exit 1
fi
echo "== FIM $(date -Is) ==" | tee -a "$LOG"
