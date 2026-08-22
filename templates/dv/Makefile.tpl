# ============================================================================
# {{PROJECT}} — DV Makefile (THIN)
# ----------------------------------------------------------------------------
# This file declares only project-specific variables; the build/run flow is
# the vendored vbuilder flow (see flow/). vbuilder maintains TESTS via add-test.
# ============================================================================

# Simulator (verilator | vcs | questa | xcelium). Override: make SIM=vcs
SIM    ?= verilator

# Top-level testbench module and DUT
TB_TOP ?= {{MODULE}}_tb_top
DUT    ?= {{MODULE}}

# Registered tests — vbuilder add-test appends here.
TESTS   = {{MODULE}}_sanity_test {{MODULE}}_random_test

# Where the vendored flow lives
FLOW_DIR = flow

# Load the standardized flow (compile / run-% / regression / cov / wave / lint)
include $(FLOW_DIR)/flow.mk
