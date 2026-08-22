# ============================================================================
# {{PROJECT}} — RTL standalone TB Makefile (pre-UVM)
# ----------------------------------------------------------------------------
# Supports the default top-level TB (sim) and per-module smoke tests
# (sim-<module>) auto-wired by `vbuilder add-module`.
#
# The AXI-Stream BFM (axi_stream_bfm.svh) is included by default in the
# include path. --trace is passed so $dumpvars/$dumpfile generate VCDs.
# ============================================================================
VERILATOR ?= verilator
BUILD_DIR ?= obj_dir

# Standard lint flags (suppress noise, keep real errors)
LINT_FLAGS := -Wall -Wno-DECLFILENAME -Wno-UNUSED -Wno-fatal -Wno-TIMESCALEMOD

RTL_DIR := ..
# Prefix each source with RTL_DIR/ and add +incdir so the standalone TB
# (compiled from rtl/tb/) can find the DUT + its _pkg.sv in the parent rtl/.
RTL_SRCS := $(addprefix $(RTL_DIR)/,$(shell sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e '/^$$/d' $(RTL_DIR)/filelist.f))

.PHONY: sim compile clean

# --- Default: top-level {{MODULE}} TB ---
compile:
	$(VERILATOR) --binary --top-module {{MODULE}}_tb \
		$(LINT_FLAGS) --timing --trace --Mdir $(BUILD_DIR) \
		+incdir+$(RTL_DIR) +incdir+. \
		$(RTL_SRCS) {{MODULE}}_tb.sv

sim: compile
	./$(BUILD_DIR)/V{{MODULE}}_tb

# --- Per-module smoke tests (auto-wired by vbuilder add-module) ---
# Pattern: sim-<module> compiles <module>_pkg.sv + <module>.sv + <module>_tb.sv
# To add a new module target, run: vbuilder add-module --alsoTb
# {{VBUILDER:TB_TARGETS}}

clean:
	rm -rf $(BUILD_DIR) $(BUILD_DIR)_* *.vcd *.fst
