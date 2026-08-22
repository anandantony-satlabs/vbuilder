#!/usr/bin/env bash
# ============================================================================
# {{PROJECT}} — DV regression runner
# ----------------------------------------------------------------------------
# Thin wrapper around `make regression`. vbuilder add-test inserts test lines
# between the REGRESSION_START / REGRESSION_END anchors below.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== {{PROJECT}} regression =="
# {{VBUILDER:REGRESSION_START}}
make run-{{MODULE}}_sanity_test
make run-{{MODULE}}_random_test
# {{VBUILDER:REGRESSION_END}}
echo "== regression complete =="
