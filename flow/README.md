# vbuilder DV Flow

A reusable, simulator-agnostic build/run flow for SystemVerilog UVM verification
projects. Vendored into each project by `vbuilder init` and maintained via
`vbuilder upgrade-flow`.

## The contract

A project conforms to the vbuilder DV flow by maintaining three things:

| File | Purpose | Maintained by |
|------|---------|---------------|
| `dv/filelist.f` | Ordered compile list (`*_pkg.sv` first, `tb_top` last) | `vbuilder add-module` |
| `dv/common/<module>_pkg.sv` | UVM component visibility via `` `include `` (anchored) | `vbuilder add-module` / `add-test` |
| `dv/Makefile` | Declares `SIM`, `TB_TOP`, `DUT`, `TESTS`, then `include`s `flow.mk` | hand-edited (thin) |

`vbuilder`'s `add-module` / `add-test` actions keep the filelist ordering and
package includes correct (idempotent, anchor-patched) so this flow Just Works.

## The standard target set

Every DV project (regardless of simulator) exposes:

| Target | What it does |
|--------|--------------|
| `make compile` | Compile RTL + DV into a sim binary |
| `make run-<test>` | Run one test (e.g. `make run-sanity_test`) |
| `make regression` | Run all tests in `TESTS` |
| `make cov` | Coverage report |
| `make wave` | Open waveform viewer |
| `make lint` | RTL-only lint (`verilator --lint-only`) |
| `make list-tests` | Print registered tests |
| `make clean` | Remove all build artifacts |
| `make flow-version` | Print flow version |

Switch simulator: `make regression SIM=vcs` (when implemented).

## Backends

| Backend | Status | File |
|---------|--------|------|
| Verilator + UVM 2017 | ✅ implemented | `backends/verilator.mk` |
| Synopsys VCS | 🔲 stub | `backends/vcs.mk` |
| Mentor Questa | 🔲 stub | `backends/questa.mk` |
| Cadence Xcelium | 🔲 stub | `backends/xcelium.mk` |

A backend implements five macros — `COMPILE_CMD`, `RUN_CMD`, `COV_CMD`,
`WAVE_CMD`, `LINT_CMD` — against the contract variables (`SV_SRCS`, `TESTS`,
`TB_TOP`, `DUT`). That is the stable ABI.

## Vendoring & upgrades

`vbuilder init` copies a versioned snapshot of this directory into the project.
`vbuilder status --check-flow` reports drift; `vbuilder upgrade-flow` re-vendors.

Flow version: see `flow.mk` (`FLOW_VERSION`, currently 0.1.1).
