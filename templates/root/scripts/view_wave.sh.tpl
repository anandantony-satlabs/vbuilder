#!/usr/bin/env bash
# {{PROJECT}} — waveform viewer wrapper (gtkwave)
# ----------------------------------------------------------------------------
# Opens a VCD file in GTKWave. Searches common locations for VCDs generated
# by the TB Makefile (--trace) or the UVM DV flow.
#
# Usage:
#   scripts/view_wave.sh                          # auto-find most recent VCD
#   scripts/view_wave.sh path/to/waveform.vcd     # specific VCD
#   scripts/view_wave.sh rtl/tb                   # search a directory
# ============================================================================
set -euo pipefail

GTKWAVE=${GTKWAVE:-gtkwave}

# Find gtkwave
if ! command -v "$GTKWAVE" &>/dev/null; then
    echo "error: gtkwave not found. Install it or set GTKWAVE=/path/to/gtkwave" >&2
    exit 1
fi

VCD=""

if [ $# -ge 1 ]; then
    ARG="$1"
    if [ -f "$ARG" ]; then
        VCD="$ARG"
    elif [ -d "$ARG" ]; then
        # Search directory for VCDs
        VCD=$(find "$ARG" -name '*.vcd' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    else
        echo "error: $ARG is not a file or directory" >&2
        exit 1
    fi
else
    # Auto-find: search rtl/tb and dv/sim for the most recent VCD
    cd "$(dirname "$0")/.."
    VCD=$(find rtl/tb dv/sim -name '*.vcd' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [ -z "$VCD" ] || [ ! -f "$VCD" ]; then
    echo "error: no VCD file found. Run a simulation with --trace first." >&2
    echo "  try: make -C rtl/tb sim-<module>" >&2
    echo "  or:  test_runner <test> (UVM flow dumps VCDs in dv/sim/)" >&2
    exit 1
fi

echo "[view_wave] opening $VCD in gtkwave"
exec "$GTKWAVE" "$VCD" 2>/dev/null &
