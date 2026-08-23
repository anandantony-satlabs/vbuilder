# ============================================================================
# vbuilder DV Flow — flow.mk
# ============================================================================
# Simulator-agnostic build/run targets. A project's dv/Makefile declares a few
# variables (SIM, TB_TOP, DUT, TESTS) then does:
#
#     include $(FLOW_DIR)/flow.mk
#
# Backends live in backends/$(SIM).mk and supply the *_CMD macros.
# This file is part of the vendored flow snapshot (see vbuilder upgrade-flow).
# Flow version: see FLOW_VERSION below (single source of truth).
# ============================================================================

FLOW_VERSION := 0.2.0
FLOW_DIR     ?= flow

# Default simulator. Override with: make regression SIM=vcs
SIM          ?= verilator

# Defaults that the backend (loaded next) depends on. A project may override
# any of these before `include $(FLOW_DIR)/flow.mk`.
FILELIST     ?= filelist.f
BUILD_DIR    ?= obj_dir
SIM_DIR      ?= sim
SEED         ?= 0
VERBOSITY    ?= UVM_LOW
# Extra plusargs passed through to the binary on run-% (e.g. PLUSARGS=+NOVCD)
PLUSARGS     ?=

# Load the backend (supplies COMPILE_CMD, RUN_CMD, COV_CMD, WAVE_CMD, LINT_CMD).
-include $(FLOW_DIR)/backends/$(SIM).mk

ifndef TB_TOP
$(error TB_TOP must be set in the project Makefile (e.g. ccsds_tx_tb_top))
endif

# Load the contract: reads FILELIST + TESTS, validates ordering.
-include $(FLOW_DIR)/contract.mk

.PHONY: compile run-% regression cov wave lint list-tests clean clean-sim flow-version help

# ----------------------------------------------------------------------------
# Standard target set — the stable DV flow ABI
# ----------------------------------------------------------------------------

# Compile RTL + DV into a simulator binary. Idempotent across targets.
compile:
	@echo "== flow $(FLOW_VERSION) / $(SIM): compile =="
	$(COMPILE_CMD)

# Run a single test by name:  make run-sanity_test
# CRITICAL: $* (make's stem) is used directly in the recipe — NOT $(TEST).
# The old form passed TEST=$* as a shell arg AFTER RUN_CMD, but RUN_CMD uses
# $(TEST) (a make variable) which expanded empty → +UVM_TESTNAME= → NOCOMP.
# Fix: inline the run command with $* directly.
run-%: compile
	@echo "== flow $(FLOW_VERSION) / $(SIM): run $* =="
	mkdir -p $(SIM_DIR)
	cd $(SIM_DIR) && ../$(BUILD_DIR)/V$(TB_TOP) \
		+UVM_TESTNAME=$* \
		+UVM_VERBOSITY=$(VERBOSITY) \
		+ntb_random_seed=$(SEED) \
		+seq_count=$(SEQ_COUNT) \
		$(PLUSARGS)

# Run every test in TESTS — the regression fan-out.
regression: $(TESTS:%=run-%)
	@echo "== flow $(FLOW_VERSION): regression complete ($(words $(TESTS)) tests) =="

# Coverage merge/report (backend-defined; no-op if unsupported).
cov:
	$(COV_CMD)

# Open waveform viewer for last sim.
wave:
	$(WAVE_CMD)

# Lint RTL only (fast gate, no sim).
lint:
	$(LINT_CMD)

# List registered tests (machine-readable).
list-tests:
	@echo $(TESTS)

clean:
	rm -rf $(BUILD_DIR) $(SIM_DIR) *.fst *.vcd *.log
	rm -rf coverage

clean-sim:
	rm -rf $(SIM_DIR) *.fst *.vcd

flow-version:
	@echo "vbuilder flow $(FLOW_VERSION)"

help:
	@echo "vbuilder DV flow $(FLOW_VERSION) [SIM=$(SIM)]"
	@echo ""
	@echo "Targets:"
	@echo "  compile       Compile RTL + DV"
	@echo "  run-<test>    Run one test (e.g. make run-sanity_test)"
	@echo "  regression    Run all tests in TESTS"
	@echo "  cov           Coverage report"
	@echo "  wave          Open waveform viewer"
	@echo "  lint          Lint RTL only (verilator --lint-only)"
	@echo "  list-tests    Print registered test names"
	@echo "  clean         Remove all build artifacts"
	@echo "  flow-version  Print flow version"
	@echo ""
	@echo "Variables:"
	@echo "  SIM=$(SIM)  TB_TOP=$(TB_TOP)  DUT=$(DUT)"
	@echo "  TESTS=$(TESTS)"
	@echo "  SEED=$(SEED)  VERBOSITY=$(VERBOSITY)"
