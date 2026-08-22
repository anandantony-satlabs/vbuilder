# vbuilder

A pi extension that **stamps out a complete RTL verification project** (golden
model → RTL → UVM → regression) from a config, and **auto-wires** new modules
and tests into the build/run cycle. Ships a reusable, simulator-agnostic DV
build/run flow.

Built per `FACTORY.md` (the RTL Software Factory): the scaffolded structure is
the **L1 product**; the flow library and auto-wiring are **L3 tooling**, reusable
across every future module.

## Install

Already at `.pi/extensions/vbuilder/` (project-local, auto-loaded by pi).

## The single tool: `vbuilder`

One tool, an `action` enum:

| action | what it does |
|--------|--------------|
| `init` | Scaffold a full new project (tree + templates + vendored flow + git) |
| `add_module` | Add one RTL module (+ optional TB / DV component), auto-wired |
| `add_test` | Add a UVM test, auto-wired into pkg + filelist + Makefile + regression |
| `status` | Presence-based project health check (S0–S4) + flow drift |
| `upgrade-flow` | Re-vendor the DV flow snapshot into a project |

### Example: init

```json
{
  "action": "init",
  "project": "ccsds_tx",
  "module": "ccsds_tx",
  "targetDir": "~/SATLABS/payload_fpga/ccsds_tx",
  "dataWidth": 8,
  "ports": [
    {"name": "clk", "dir": "input", "width": 1},
    {"name": "rst_n", "dir": "input", "width": 1},
    {"name": "data_in", "dir": "input", "width": 8},
    {"name": "data_out", "dir": "output", "width": 8}
  ],
  "goldenMode": "file",
  "gitInit": true
}
```

### Example: add a test (auto-wired)

```json
{
  "action": "add_test",
  "projectDir": "~/SATLABS/payload_fpga/ccsds_tx",
  "test": "error_injection_test",
  "desc": "injects correctable errors"
}
```

This single call:
1. writes `dv/tests/error_injection_test.sv`
2. inserts `` `include `` into `dv/common/<module>_pkg.sv`
3. appends to `dv/filelist.f`
4. appends to `TESTS` in `dv/Makefile`
5. inserts `make run-error_injection_test` into `dv/regression/run_all.sh`

All idempotent and order-correct (pkg first, per IEEE 1800-2017 §26.3).

## What gets scaffolded

```
<project>/
├── Makefile                 # top-level gate: lint / tb / golden / uvm / regress
├── config.mk / .gitignore / README.md / PROJECT_PLAN.md
├── scripts/                 # lint.sh, golden_check.sh
├── rtl/                     # <module>.sv, _pkg.sv, filelist.f (ordered), tb/
├── dv/                      # UVM env (Verilator UVM 2017), tests, cov, regression
│   ├── flow/                # ← vendored standardized DV flow (see below)
│   └── Makefile             # thin: declares SIM/TB_TOP/TESTS, includes flow
├── golden/                  # model.py (executable spec), vectors/ (clean + error)
├── docs/                    # architecture/, review/, handoffs/, release_notes, user_guide
└── handoffs/                # HANDOFF_TEMPLATE.md (70%-context protocol)
```

## The standardized DV flow

The build/run pattern is a **reusable library**, not frozen per-project text.

`dv/flow/` (vendored at init):

| file | role |
|------|------|
| `flow.mk` | simulator-agnostic targets: `compile`, `run-%`, `regression`, `cov`, `wave`, `lint`, `list-tests` |
| `contract.mk` | loads + validates the ordered `filelist.f` and `TESTS` |
| `backends/verilator.mk` | ✅ Verilator + UVM 2017 (the five `*_CMD` macros) |
| `backends/{vcs,questa,xcelium}.mk` | 🔲 stubs (document the contract) |

A project's `dv/Makefile` is thin:
```make
SIM    ?= verilator
TB_TOP ?= ccsds_tx_tb_top
TESTS   = ccsds_tx_sanity_test ccsds_tx_random_test
FLOW_DIR = flow
include $(FLOW_DIR)/flow.mk
```

Switch simulator: `make regression SIM=vcs` (when implemented). No file edits.

**Vendoring & upgrades:** `init` copies a versioned snapshot; `status` reports
drift; `upgrade-flow` re-vendors. Tagged releases use the flow they were
validated against (reproducibility), but upgrades are opt-in and never silent.

## Auto-wiring contract

vbuilder owns anchor markers and maintains them idempotently:

| registry | file | patched by |
|----------|------|------------|
| RTL compile list | `rtl/filelist.f` | `add_module` |
| DV compile list | `dv/filelist.f` | `add_module`/`add_test` |
| UVM class visibility | `dv/common/<module>_pkg.sv` | `add_module`/`add_test` |
| Test registry | `dv/Makefile` `TESTS` | `add_test` |
| Regression runner | `dv/regression/run_all.sh` | `add_test` |

If a human deletes an anchor, the patcher **fails loudly** rather than silently
mis-wire.

## Golden model

Python (`golden/model.py`) — the executable spec. Two modes:

- **`file` (default, proven):** CLI reads input samples, writes golden output;
  `scripts/golden_check.sh` diffs RTL vs golden.
- **`dpi` (opt-in):** pyhdl-if cosim — the SV scoreboard calls the Python model
  per-sample via DPI. Wired but not the default (de-risked; matches FACTORY.md D5).

Per FACTORY.md §5.1, the model ships **clean + error-injected** vectors and
must clear a validation gate before RTL is checked against it.

## Testing

Two layers (per the extension_creator skill):

- **Layer 1 — extension_sandbox** (`tests/fixtures/*.json`): end-to-end smoke
  tests. Run:
  ```
  extension_sandbox(extension="./", fixturesDir="./tests/fixtures", outputDir="./.sandbox-out")
  ```
- **Layer 2 — vitest** (`tests/vbuilder.test.ts`): unit tests for the template
  engine + patcher (substitution, idempotency, loud-fail on missing anchors). Run:
  ```
  npx vitest run
  ```

## Reload safety

The single tool is registered once in the factory function (no `session_start`
registration, no timers, no sockets). Survives `/reload` with no duplicates.

## Status vs FACTORY.md

This extension is the **L3 Tooling** scaffolding asset (Factory MVP scope):
- ✅ SystemVerilog module templates (header / pkg / module / tb skeletons)
- ✅ Makefile with `lint` / `tb` / `golden` / `uvm` / `regress` phony targets
- ✅ DV build/run flow (reusable, simulator-agnostic)
- ✅ Handoff protocol template

Not included (separate, per FACTORY.md build order): the `golden` *extension*
(`golden_check` tool), the domain skills (`ccsds-codec`, `rs-bm-decoder`,
`rtl-factory`). vbuilder stamps the skeletons those will later fill.
