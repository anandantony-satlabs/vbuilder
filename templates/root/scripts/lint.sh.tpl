#!/usr/bin/env bash
# {{PROJECT}} — lint wrapper (verilator --lint-only)
# Uses the same LINT_FLAGS as the TB Makefile for consistency.
set -euo pipefail
cd "$(dirname "$0")/.."

VERILATOR=${VERILATOR:-verilator}

# Standard lint flags (suppress noise, keep real errors)
LINT_FLAGS="-Wall -Wno-fatal -Wno-TIMESCALEMOD -Wno-DECLFILENAME -Wno-UNUSED"

# Lint the full RTL filelist
$VERILATOR $LINT_FLAGS --lint-only -Irtl +incdir+rtl/tb -f rtl/filelist.f

echo "[lint] clean"
