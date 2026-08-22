# ============================================================================
# {{PROJECT}} — top-level Makefile (the factory gate runner)
# ----------------------------------------------------------------------------
# FACTORY.md §8 step 4: lint / tb / golden / uvm / regress / clean.
# Each target delegates to its sub-tree. `regress` runs the full gate chain.
# ============================================================================

.PHONY: lint tb golden uvm regress clean help

lint:
	@echo "== {{PROJECT}}: lint (RTL) =="
	$(MAKE) -C rtl/tb clean >/dev/null 2>&1 || true
	cd rtl && verilator --Wall -Wno-fatal --lint-only -f filelist.f

tb:
	@echo "== {{PROJECT}}: standalone TB (pre-UVM) =="
	$(MAKE) -C rtl/tb sim

golden:
	@echo "== {{PROJECT}}: golden check =="
	scripts/golden_check.sh

uvm:
	@echo "== {{PROJECT}}: UVM regression =="
	$(MAKE) -C dv regression

regress: lint tb golden uvm
	@echo "== {{PROJECT}}: full regression gate PASSED =="

clean:
	$(MAKE) -C rtl/tb clean || true
	$(MAKE) -C dv clean || true
	$(MAKE) -C golden clean || true
	rm -rf obj_dir sim *.fst *.vcd *.log coverage

help:
	@echo "{{PROJECT}} gate targets:"
	@echo "  make lint     — verilator --lint-only on RTL"
	@echo "  make tb       — standalone sanity TB"
	@echo "  make golden   — golden model vs RTL diff"
	@echo "  make uvm      — UVM regression"
	@echo "  make regress  — full gate chain (lint->tb->golden->uvm)"
	@echo "  make clean    — remove all build artifacts"
