# ============================================================================
# vbuilder DV Flow — backend: verilator (UVM 2017)
# ============================================================================
# Requires: Verilator 5.051+ with UVM 2017 support.
# Ref: https://antmicro.com/blog/2025/10/support-for-upstream-uvm-2017-in-verilator
# Ref: verilator-uvm-example (Antmicro) — the canonical build idiom.
#
# Key insights (validated against the Antmicro verilator-uvm-example):
#   +define+UVM_NO_DPI  compiles out uvm_hdl_* / uvm_dpi_* (which are VPI-based
#   and have no Verilator vendor backend). UVM's backdoor HDL access isn't needed
#   for scoreboard-based verification. This is the Antmicro-endorsed approach.
#
#   --binary  auto-generates a C++ main() — no separate sim_main.cpp needed.
#
# CRITICAL: Do NOT use --timing with UVM 1800.2. It triggers a Verilator bug
# where the `process` built-in class (used by uvm_coreservice.svh) is not
# found. The Antmicro UVM example compiles + runs WITHOUT --timing; event
# controls at the top of processes (@(posedge clk), forever) work under the
# default timing model. --timing is only needed for fork..join with multiple
# statements, which conflicts with UVM's process class usage.
#
# CRITICAL: Do NOT use -DUVM_OBJECT_MUST_HAVE_CONSTRUCTOR or
# +define+UVM_REPORT_DISABLE_FILE — both trigger the same process class bug.
#
# CRITICAL: uvm_pkg.sv MUST be compiled BEFORE project files (-f filelist.f)
# so the `process` built-in is defined when project packages import uvm_pkg::*.
# The COMPILE_CMD below puts uvm_pkg.sv first.
# ============================================================================

VERILATOR    ?= verilator

# UVM_HOME: the 1800.2 UVM source tree (must contain uvm_pkg.sv).
# Default matches requirements_verilator.sh (Accellera 1800.2-2017-1.0 → ~/tools).
# Fallback: first installed 1800.2-* tree, so a different edition still works.
UVM_HOME     ?= $(HOME)/tools/1800.2-2017-1.0/src
ifeq ($(wildcard $(UVM_HOME)/uvm_pkg.sv),)
UVM_HOME      = $(shell ls -d $(HOME)/tools/1800.2-*/src 2>/dev/null | head -1)
endif

# --- VERILATOR_FLAGS (hardened, Antmicro idiom) ----------------------------
#   --binary          : auto-generate C++ main() + link in one step
#   -j 0              : parallel verilation + C++ build (all cores)
#   -Wno-fatal        : don't treat UVM's benign warnings as fatal
#   -Wno-IMPORTSTAR   : UVM's `import uvm_pkg::*` is intentional
#   -Wno-MODDUP       : pkg may appear in both rtl/ and dv/ filelists
#   -Wno-TIMESCALEMOD : UVM + project timescale coexistence
#   --trace (VCD)     : FST needs lz4-dev headers; VCD is universal
#
# NOTE: --timing is intentionally OMITTED. It triggers the UVM 'process' class
# bug. See comment block above.
VERILATOR_FLAGS ?= --binary \
                   -j 0 \
                   -Wno-DECLFILENAME -Wno-UNUSED \
                   -Wno-IMPORTSTAR -Wno-MODDUP -Wno-TIMESCALEMOD -Wno-fatal \
                   --trace \
                   --Mdir $(BUILD_DIR) \
                   --top-module $(TB_TOP)

# +incdir+ for UVM package + macros + project dirs
INC_DIRS     := +incdir+$(UVM_HOME) +incdir+$(CURDIR)/common +incdir+$(CURDIR)/env +incdir+$(CURDIR)/tests +incdir+$(CURDIR)/../rtl

# +define+UVM_NO_DPI: compile out UVM's VPI-based HDL backdoor (no Verilator
# vendor backend exists). Required for UVM to link on Verilator.
# NOTE: UVM_REPORT_DISABLE_FILE is intentionally OMITTED — it triggers the
# process class bug.
UVM_DEFINES  := +define+UVM_NO_DPI

# --- The five backend macros the flow contract requires ----------------------

# COMPILE_CMD: one Verilator invocation. SV_SRCS comes from contract.mk.
# CRITICAL: uvm_pkg.sv MUST come BEFORE -f $(FILELIST) so the `process`
# built-in class is defined when project packages import uvm_pkg::*.
COMPILE_CMD  := $(VERILATOR) $(VERILATOR_FLAGS) $(INC_DIRS) \
                  $(UVM_HOME)/uvm_pkg.sv \
                  -f $(FILELIST) \
                  $(UVM_DEFINES)

# RUN_CMD: execute the built binary. $(TEST) is the test name (from run-%).
# NOTE: The flow.mk run-% target passes TEST=$* as a shell arg, which does NOT
# expand $(TEST) in this make variable. The run-% target in flow.mk handles
# this by inlining the command with $* directly. This RUN_CMD is kept for
# backends that set TEST as a make variable before invoking.
RUN_CMD      := cd $(SIM_DIR) && ../$(BUILD_DIR)/V$(TB_TOP) \
                  +UVM_TESTNAME=$(TEST) \
                  +UVM_VERBOSITY=$(VERBOSITY) \
                  +ntb_random_seed=$(SEED) \
                  +seq_count=$(SEQ_COUNT)

# COV_CMD: Verilator coverage is limited; report the generated dir.
COV_CMD      := @echo "[verilator] coverage in $(SIM_DIR)/coverage/ (use --coverage at compile)"

# WAVE_CMD: open the VCD from the last sim in gtkwave.
WAVE_CMD     := gtkwave $(SIM_DIR)/$(TB_TOP).vcd 2>/dev/null || echo "[verilator] no waveform; run with --trace"

# LINT_CMD: fast RTL-only lint gate (no sim, no DV).
LINT_CMD     := cd ../rtl && $(VERILATOR) --Wall -Wno-fatal --lint-only -f filelist.f

# Optional sequence length override
SEQ_COUNT    ?= 1000
