#!/usr/bin/env bash
# ============================================================================
# {{PROJECT}} — golden check
# ----------------------------------------------------------------------------
# FACTORY.md §5 invariant: RTL sim output == golden model output.
# Default (file mode): run the Python golden model, run the standalone RTL TB,
# diff the outputs. PASS/FAIL.
# ============================================================================

set -euo pipefail
cd "$(dirname "$0")/.."

V=${V:-0}
PYTHON=${PYTHON:-python3}

echo "== golden check: running Python golden model =="
GOLDEN_ERR=$(mktemp)
if ! make -C golden vectors >"$GOLDEN_ERR" 2>&1; then
    echo "NOT RUN: golden vectors could not be generated (golden/model.py or its input"
    echo "       samples not implemented yet — see golden/Makefile TODO)."
    echo "       Cause (first lines):"
    sed -n '1,5p' "$GOLDEN_ERR"
    rm -f "$GOLDEN_ERR"
    echo "NOTRUN"
    exit 1
fi
rm -f "$GOLDEN_ERR"

echo "== golden check: running RTL standalone TB =="
make -C rtl/tb sim >/dev/null 2>&1 || {
    echo "FAIL: RTL TB did not complete"; exit 1
}

GOLDEN=golden/vectors/golden_output.txt
RTL=rtl/tb/obj_dir/rtl_output.txt  # TODO: TB writes here

if [ ! -f "$GOLDEN" ]; then
    echo "FAIL: golden output missing ($GOLDEN)"; exit 1
fi

if [ ! -f "$RTL" ]; then
    echo "NOT RUN: RTL output file not yet emitted by TB ($RTL)."
    echo "       Golden model output is in $GOLDEN — wire the TB to write $RTL then re-run."
    echo "NOTRUN"
    exit 1
fi

echo "== golden check: diffing (comment lines stripped) =="
if diff -q <(grep -v '^#' "$GOLDEN") <(grep -v '^#' "$RTL") >/dev/null 2>&1; then
    echo "PASS: RTL matches golden model"
    exit 0
else
    echo "FAIL: RTL != golden"
    diff <(grep -v '^#' "$GOLDEN") <(grep -v '^#' "$RTL") | head -20
    exit 1
fi
