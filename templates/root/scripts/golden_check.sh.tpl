#!/usr/bin/env bash
# ============================================================================
# {{PROJECT}} — golden check (per-vector mode + G-mod hash-lock)
# ----------------------------------------------------------------------------
# FACTORY.md §5 invariant: RTL sim output == golden model output.
#
# Two modes:
#   1. per-vector (when golden/vectors/V-*.exp exist): for each vector, run the
#      standalone TB (target from the vector's '# tb: <name>' header comment,
#      falling back to $TB_TARGET) with +VEC/+SPS/+OUT and diff against .exp.
#      `sps=` in the header is passed as +SPS when present.
#   2. top-level (no .exp files): diff golden_output.txt against the top TB's
#      rtl_output.txt (rtl/tb/obj_dir/rtl_output.txt).
#
# Hash-lock (dv-flow.md G-mod invariant): a SHA-256 manifest over the committed
# vectors is verified before diffing; regenerate with `make -C golden manifest`
# after any (re)generation, and commit it with the vectors.
#
# Vector file format: '#' comments are skipped on both sides; input lines and
# output lines are plain integers (or space-separated tuples, matching golden
# and TB conventions documented in golden/vectors/README.md).
# ============================================================================

set -euo pipefail
cd "$(dirname "$0")/.."

V=${V:-0}
PYTHON=${PYTHON:-python3}
TB_TARGET=${TB_TARGET:-}   # fallback TB make target (sim-<name>); header tb: wins

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

# G-mod hash-lock: verify committed vectors against the manifest before diffing.
if [ -f golden/vectors/MANIFEST.sha256 ]; then
    if (cd golden/vectors && sha256sum -c MANIFEST.sha256 --quiet 2>/dev/null); then
        echo "== hash-lock: manifest OK =="
    else
        echo "FAIL: golden/vectors/MANIFEST.sha256 mismatch — committed vectors"
        echo "      were changed without regenerating the manifest."
        echo "      Fix: make -C golden manifest && commit"
        exit 1
    fi
else
    echo "WARN: no golden/vectors/MANIFEST.sha256 — hash-lock not armed yet"
    echo "      (generate: make -C golden manifest)"
fi

# ---------------------------------------------------------------------------
# Mode 1: per-vector
# ---------------------------------------------------------------------------
shopt -s nullglob
VECS=(golden/vectors/V-*.exp)
shopt -u nullglob

if [ ${#VECS[@]} -gt 0 ]; then
    echo "== golden check: per-vector mode, ${#VECS[@]} vectors =="
    fail=0
    for exp in "${VECS[@]}"; do
        vec_in="${exp%.exp}.in"
        base=$(basename "$exp" .exp)
        sps=$(grep -m1 -o 'sps=[0-9]*' "$exp" | cut -d= -f2 || true)
        tgt=$(grep -m1 -o 'tb=[A-Za-z0-9_]*' "$exp" | cut -d= -f2 || true)
        tgt=${tgt:-$TB_TARGET}
        if [ -z "$tgt" ]; then
            echo "FAIL: no TB target for $base (add '# tb: <target>' to the"
            echo "      vector header or export TB_TARGET)"; fail=1; continue
        fi
        out="rtl/tb/out_${base}.txt"
        vargs=(VEC="../../${vec_in}" OUT="$(basename "$out")")
        [ -n "${sps:-}" ] && vargs+=(SPS="$sps")
        if ! make -s -C rtl/tb "sim-${tgt}" "${vargs[@]}" >/dev/null 2>&1; then
            echo "  FAIL: $base (sps=${sps:-8}) — TB run failed"; fail=1; continue
        fi
        # NB: '{ diff || true; } | head' — plain 'diff | head' + pipefail turns
        # SIGPIPE into a script-killing exit 141, silently skipping the rest.
        if diff -q <(grep -v '^#' "$exp") "$out" >/dev/null 2>&1; then
            echo "  PASS: $base (sps=${sps:-8})"
        else
            echo "  FAIL: $base (sps=${sps:-8})"
            { diff <(grep -v '^#' "$exp") "$out" 2>/dev/null || true; } | head -10
            fail=1
        fi
    done
    if [ "$fail" -eq 0 ]; then
        echo "PASS: RTL matches golden model (all vectors)"
        exit 0
    fi
    exit 1
fi

# ---------------------------------------------------------------------------
# Mode 2: top-level fallback (no V-*.exp vectors)
# ---------------------------------------------------------------------------
echo "== golden check: running RTL standalone TB =="
make -C rtl/tb sim >/dev/null 2>&1 || {
    echo "FAIL: RTL TB did not complete"; exit 1
}

GOLDEN=golden/vectors/golden_output.txt
RTL=rtl/tb/obj_dir/rtl_output.txt  # TB writes here

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
    { diff <(grep -v '^#' "$GOLDEN") <(grep -v '^#' "$RTL") 2>/dev/null || true; } | head -20
    exit 1
fi
