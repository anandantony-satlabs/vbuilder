# {{TITLE}}

> RTL verification project scaffolded by **vbuilder**.

## What's here

| Path | Purpose |
|------|---------|
| `rtl/` | SystemVerilog modules + `_pkg.sv` constants + `filelist.f` + standalone TB |
| `dv/` | UVM env (Verilator UVM 2017) — agent/monitor/scoreboard, tests, coverage, vendored flow |
| `golden/` | Python golden model (the executable spec) + vectors (clean + error-injected) |
| `scripts/` | `lint.sh`, `golden_check.sh` |
| `docs/` | architecture, review, release notes, user guide |
| `handoffs/` | context-handoff template (70%-split protocol) |
| `Makefile` | top-level gate runner: `lint` / `tb` / `golden` / `uvm` / `regress` |

## Quick start

```bash
make lint      # verilator --lint-only on RTL
make tb        # standalone sanity TB
make golden    # run golden model + diff vs RTL
make uvm       # UVM regression (in dv/)
make regress   # full gate chain
```

## The pipeline

```
SPEC → golden/model.py (executable spec) → reference vectors
                ↓
        RTL (SystemVerilog) → compile → lint → standalone tb
                ↓
        golden_check: sim == golden?  → UVM regression → stage tag
```

Nothing reaches RTL until the golden model emits vectors (FACTORY.md §5).

## Stage gates

| Stage | Exit criterion | Tag |
|-------|----------------|-----|
| S0 Ingest | verified reference committed | `stage0-ingest` |
| S1 Golden | golden validation gate green | `stage1-golden` |
| S2 Module | lint-clean + tb green + golden_check PASS | `stage2-<module>` |
| S3 Integ | loopback green vs golden | `stage3-integ` |
| S4 UVM | UVM regression green | `stage4-uvm` |
| S5 Release | lint + full regression + docs | `v<major>.<minor>.<patch>` |

## Adding modules / tests

```bash
# (via the vbuilder extension tool)
vbuilder add-module  <name>   # → patches rtl/filelist.f + lint target
vbuilder add-test    <name>   # → patches dv pkg includes + Makefile TESTS + run_all.sh
```

Both are idempotent and order-correct — newly added artifacts are in the
build/run cycle immediately.
