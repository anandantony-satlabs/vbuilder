# vbuilder UVM Hardening Plan

> **Goal:** Make `vbuilder init` produce a UVM testbench that actually *runs*
> (calls `run_test()`, drives the DUT, checks results) out of the box — not a
> "happy-path" stub that prints PASS without testing anything. The fixes must
> be generic (work for any new project, not just CCSDS) and proven against
> the real Verilator 5.051 + UVM 1800.2 toolchain.

---

## Problem Statement

The current `vbuilder init` scaffold has three categories of defects that
were discovered (the hard way) during the CCSDS RX UVM work:

### Category 1: The "False Green" (most dangerous)

The init-only scaffold compiles and prints `*** TEST PASSED ***` without:
- Calling `run_test()` (the tb_top uses a bare `$finish` after a delay)
- Instantiating the DUT (it's commented out)
- Driving any sequence
- Running any scoreboard comparison

**Impact:** `test_runner` reports PASS on a project that has verified nothing.
This gave false confidence that the UVM flow was working, when in fact the
first real `run_test()` call hit a compile-breaking `process` class bug that
the scaffold never exposed.

### Category 2: Verilator+UVM Compile Bugs

The `verilator.mk` backend has three flags that trigger the
`Can't find typedef/interface: 'process'` error in UVM 1800.2:

| Flag | Why it breaks | Evidence |
|------|--------------|----------|
| `--timing` | Activates Verilator's `process` built-in class path, which conflicts with UVM's `process::self()` | Antmicro UVM example compiles + runs WITHOUT `--timing` |
| `-CFLAGS -DUVM_OBJECT_MUST_HAVE_CONSTRUCTOR` | Triggers the same `process` path | Removing it fixes the error |
| `+define+UVM_REPORT_DISABLE_FILE` | Triggers the same `process` path | Removing it fixes the error |

Additionally, the `COMPILE_CMD` puts `uvm_pkg.sv` **after** `-f filelist.f`,
which causes the `process` built-in to be undefined when project packages
`import uvm_pkg::*`. The fix: `uvm_pkg.sv` must come **before** the filelist.

### Category 3: Broken `run-%` Target (NOCOMP)

The `flow.mk` `run-%` target passes `TEST=$*` as a shell argument **after**
the `RUN_CMD` expansion, but `RUN_CMD` uses `$(TEST)` (a make variable) which
expands to empty at recipe-expansion time:

```makefile
# BROKEN: $(TEST) is empty when RUN_CMD is expanded
run-%: compile
    $(RUN_CMD) TEST=$* SEED=$(SEED)
# RUN_CMD = ... +UVM_TESTNAME=$(TEST) ...
# Result: +UVM_TESTNAME= → NOCOMP fatal
```

---

## Fix Plan (7 changes, ordered by impact)

### Fix 1: Make the tb_top template call `run_test()` (Category 1)

**File:** `templates/dv/tb/{{MODULE}}_tb_top.sv.tpl`

**Change:** Replace the happy-path `$finish` block with a real `run_test()`
call. Keep the DUT instantiation as a commented-out template (since the ports
aren't known at init time), but make the *UVM infrastructure* real.

The key insight: `run_test()` works even without a DUT — UVM will instantiate
the test class, run phases, and the test's `report_phase` will print PASS/FAIL
based on `UVM_ERROR` count. This is a **true green** — it proves UVM compiles,
the factory works, and phases execute.

**New template (key section):**
```systemverilog
    // --- Config DB + run_test ---
    // The virtual interface is set into config_db by tests that need it.
    // run_test() reads +UVM_TESTNAME to select the test class.
    initial begin
        run_test();
    end
```

The DUT instantiation stays as a comment with a clear `TODO` — the user
uncomments and wires it when they fill in the RTL. But the UVM machinery is
real from day one.

**Validation:** `test_runner <module>_sanity_test` on a fresh init must:
1. Compile (proving the `process` bug is fixed — see Fix 3).
2. Run `run_test()`, instantiate the sanity test, execute phases.
3. Print `*** TEST PASSED ***` via the test's `report_phase` (not a bare
   `$finish`).
4. Exit 0.

### Fix 2: Make the base_test + sanity_test a real UVM test (Category 1)

**Files:** `templates/dv/tests/base_test.sv.tpl`, `templates/dv/tests/sanity_test.sv.tpl`

**Change:** The current templates have `// seq.start(sqr); // TODO: once
sequencer wired` — the sequence never runs. The sanity test should actually
*do something* minimal: raise an objection, wait a few cycles, drop it. This
proves the objection mechanism works and the test doesn't hang.

The base_test's `report_phase` is already correct (checks `UVM_ERROR` count).
The sanity_test just needs to actually raise/drop objections properly (it
already does, but the `run_test()` call in tb_top is what was missing).

No template change needed here if Fix 1 is applied — the existing templates
are structurally correct, they just weren't being reached because `run_test()`
was never called.

### Fix 3: Fix the Verilator backend flags (Category 2)

**File:** `flow/backends/verilator.mk`

**Changes:**
1. Remove `--timing` from `VERILATOR_FLAGS`.
2. Remove `-DUVM_OBJECT_MUST_HAVE_CONSTRUCTOR` from `UVM_CFLAGS`.
3. Remove `+define+UVM_REPORT_DISABLE_FILE` from `UVM_DEFINES`.
4. Reorder `COMPILE_CMD`: put `$(UVM_HOME)/uvm_pkg.sv` **before** `-f $(FILELIST)`.

**Rationale:** The Antmicro `verilator-uvm-example` (the canonical reference)
compiles and runs UVM without `--timing` and with only `+define+UVM_NO_DPI`.
Event controls at the top of processes (`@(posedge clk)`, `forever`) work
under the default timing model. The `--timing` flag is only needed for
`fork..join` with multiple statements, which UVM's internal `process` class
usage conflicts with.

**New `COMPILE_CMD`:**
```makefile
COMPILE_CMD  := $(VERILATOR) $(VERILATOR_FLAGS) $(INC_DIRS) \
                  $(UVM_HOME)/uvm_pkg.sv \
                  -f $(FILELIST) \
                  +define+UVM_NO_DPI
```

**Validation:** A fresh `vbuilder init` project must compile without any
`process` errors. The Antmicro example is the proof-of-concept.

### Fix 4: Fix the `run-%` target in flow.mk (Category 3)

**File:** `flow/flow.mk`

**Change:** The `run-%` target must pass the test name into `RUN_CMD` via a
make variable, not a shell argument. The cleanest fix: set `TEST` as a
make-scoped variable in the `run-%` recipe before invoking `RUN_CMD`:

```makefile
# Run a single test by name:  make run-sanity_test
run-%: compile
	@echo "== flow $(FLOW_VERSION) / $(SIM): run $* =="
	mkdir -p $(SIM_DIR)
	$(MAKE) -f $(FLOW_DIR)/flow.mk _run-one \
		TEST=$* SEED=$(SEED) VERBOSITY=$(VERBOSITY) \
		--no-print-directory

_run-one:
	$(RUN_CMD)
```

Alternatively (simpler, avoids recursive make): inline the run command in
`run-%` and use `$*` directly:

```makefile
run-%: compile
	@echo "== flow $(FLOW_VERSION) / $(SIM): run $* =="
	mkdir -p $(SIM_DIR)
	cd $(SIM_DIR) && ../$(BUILD_DIR)/V$(TB_TOP) \
		+UVM_TESTNAME=$* \
		+UVM_VERBOSITY=$(VERBOSITY) \
		+ntb_random_seed=$(SEED) \
		+seq_count=$(SEQ_COUNT)
```

This makes `RUN_CMD` a variable that backends *may* override, but the default
`run-%` recipe uses `$*` (make's stem) directly — which is correct.

**Validation:** `make run-<module>_sanity_test` must pass `+UVM_TESTNAME=<name>`
correctly. The sim log must show `[RNTST] Running test <name>...` (not
`NOCOMP`).

### Fix 5: Include test files in the package (Category 1, factory registration)

**File:** `templates/dv/common/{{MODULE}}_pkg.sv.tpl`

**Change:** The current template has `// {{VBUILDER:PKG_TESTS}}` anchor but
the test files are separate `.sv` files in `dv/tests/`. UVM's factory
registration requires all classes to be in one compilation unit. The
`addtest.ts` logic already does `\`include "../tests/${test}.sv"` in the
package — this is correct. But the *init* template should include the
base_test and sanity_test by default so they work from the first `init`:

**New template (key section):**
```systemverilog
    // --- tests ---
    // {{VBUILDER:PKG_TESTS}}
    `include "../tests/base_test.sv"
    `include "../tests/sanity_test.sv"
    `include "../tests/random_test.sv"

endpackage
```

And the `dv/filelist.f` template must **not** list test `.sv` files (they're
included in the package, not standalone compilation units):

**New `filelist.f.tpl` (tests section):**
```
# --- tests ---
# (test .sv files are `included inside {{MODULE}}_pkg.sv so the factory
#  registers them in the package compilation unit — do NOT list them here)
# {{VBUILDER:DV_TESTS}}
```

**Validation:** `make run-<module>_sanity_test` must find the test class (no
`NOCOMP` fatal).

### Fix 6: Add a virtual interface template (Category 1, completeness)

**New file:** `templates/dv/common/{{MODULE}}_if.sv.tpl`

The current scaffold has no interface file. Every real UVM testbench needs a
virtual interface. The template should stamp a minimal interface with
clocking blocks that the user fills in:

```systemverilog
`timescale 1ns/1ps

interface {{MODULE}}_if (
    input logic clk,
    input logic rst_n
);
    // TODO: Add DUT signals here (mirror {{MODULE}}'s port list)

    // --- Driver clocking block ---
    clocking cb_drv @(posedge clk);
        // output data_in;
        // output valid;
    endclocking

    // --- Monitor clocking block ---
    clocking cb_mon @(posedge clk);
        // input data_out;
        // input valid;
    endclocking

endinterface
```

**Validation:** The interface compiles. The tb_top sets it in `config_db`. The
driver/monitor can retrieve it (even if the signals are commented out, the
`config_db` set/get mechanism works).

### Fix 7: Update the scaffold audit to catch false greens (Category 1, guard)

**File:** `~/.agents/skills/rtl-verify-recipe/scripts/scaffold_audit.sh`

**Change:** Add a check (A5) that the tb_top calls `run_test()`:

```sh
# --- A5: tb_top must call run_test() (not a bare $finish false green) -----
if [ -f "$PROJ/dv/tb" ]; then
    for f in "$PROJ"/dv/tb/*_tb_top.sv; do
        [ -f "$f" ] || continue
        if ! grep -qE 'run_test\s*\(' "$f" 2>/dev/null; then
            err "tb_top '$f' does not call run_test() — false green (prints PASS without testing):"
            grep -n 'TEST PASSED\|\$finish' "$f" 2>/dev/null | sed 's/^/    /' >&2
        fi
    done
fi
```

And a check (A6) that the Verilator backend doesn't use the known-bad flags:

```sh
# --- A6: verilator backend must not use --timing or UVM_OBJECT_MUST_HAVE_CONSTRUCTOR ---
vk="$PROJ/dv/flow/backends/verilator.mk"
if [ -f "$vk" ]; then
    if grep -qE '\-\-timing' "$vk"; then
        err "verilator.mk uses --timing (triggers UVM 'process' class bug)"
    fi
    if grep -qE 'UVM_OBJECT_MUST_HAVE_CONSTRUCTOR' "$vk"; then
        err "verilator.mk uses UVM_OBJECT_MUST_HAVE_CONSTRUCTOR (triggers 'process' bug)"
    fi
    if grep -qE 'UVM_REPORT_DISABLE_FILE' "$vk"; then
        err "verilator.mk uses UVM_REPORT_DISABLE_FILE (triggers 'process' bug)"
    fi
fi
```

---

## Implementation Order

1. **Fix 3** (backend flags) — unblocks compilation. Without this, nothing
   compiles with `run_test()`.
2. **Fix 4** (`run-%` target) — unblocks test execution. Without this,
   `make run-<test>` passes an empty test name.
3. **Fix 1** (tb_top `run_test()`) — the core fix. Makes the scaffold a true
   green.
4. **Fix 5** (package includes) — without this, the factory can't find tests.
5. **Fix 6** (interface template) — completeness, not blocking.
6. **Fix 2** (base_test) — already correct if Fix 1 is applied.
7. **Fix 7** (audit) — regression guard, prevents backsliding.

## Testing Strategy

After each fix, run the `extension_sandbox` with a fixture that:
1. Calls `vbuilder init` to stamp a fresh project.
2. Runs `make -C dv compile` — must succeed (no `process` errors).
3. Runs `make -C dv run-<module>_sanity_test` — must PASS (not NOCOMP).
4. Checks the sim log for `[RNTST] Running test <name>...` (proves
   `run_test()` worked).
5. Checks the sim log for `*** TEST PASSED ***` from the test's
   `report_phase` (not from a bare `$finish`).

The existing `tests/vbuilder.test.ts` suite should be extended with a new
test case: `init_produces_runnable_uvm` that validates the above.

## Generality

All fixes are generic — they don't reference CCSDS, RS, or any project-specific
concept. They fix the UVM *infrastructure* (compile flags, make targets,
factory registration, tb_top pattern) that every project needs. A new
`vbuilder init` for any module (UART, FIFO, DSP block) will produce a UVM
testbench that compiles, runs `run_test()`, and passes the sanity test — a
true green that proves the toolchain works before any RTL is written.

## Risk Assessment

| Fix | Risk | Mitigation |
|-----|------|------------|
| Remove `--timing` | Some RTL may need `--timing` for `fork..join` | User can re-add via `VERILATOR_FLAGS` override; UVM doesn't need it |
| Reorder `COMPILE_CMD` | None — `uvm_pkg.sv` first is the correct order per IEEE 1800-2017 §26.3 | None needed |
| `run-%` rewrite | Changes the flow ABI | Keep `RUN_CMD` as an overridable variable; only the default recipe changes |
| Package `\`include` | None — this is the Antmicro-proven pattern | None needed |
| `run_test()` in tb_top | Test runs even without DUT | This is the *point* — it proves UVM works; the test's `report_phase` handles the pass/fail |
