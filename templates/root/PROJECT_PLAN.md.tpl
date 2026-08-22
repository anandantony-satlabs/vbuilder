# {{TITLE}} — Project Plan

## Overview
| Item | Detail |
|------|--------|
| **Goal** | Design, verify, and deliver the {{MODULE}} RTL module |
| **Simulator** | Verilator with UVM 2017 support (flow/ backends extensible) |
| **Golden model** | Python (`golden/model.py`) — file-mode default, pyhdl-if DPI opt-in |

## Team / Roles (when multi-agent)
| Role | Owns | Skills |
|------|------|--------|
| Manager | orchestration, git, context monitoring, handoffs | rtl-factory, coms, herdr |
| Architect | docs, RTL plan, test plan, code review | ccsds-codec, rs-bm-decoder |
| RTL Engineer | SystemVerilog implementation | ccsds-codec |
| DV Engineer | UVM testbench + regression | rs-bm-decoder |
| Golden/Ref | Python golden model + vectors | rs-bm-decoder |

## Stages (FACTORY.md §5.2)
### ALPHA — Architecture & golden model
- Architecture docs complete (theory, interface, microarchitecture, RTL plan, test plan)
- Golden model passes §5.1 validation gate (clean + error-injected vectors)

### BETA — First RTL + UVM env
- RTL modules pass lint + standalone TB + `golden_check`
- UVM env compiles; scoreboard wired (file-mode default)

### GAMMA — Verification & sign-off
- UVM regression green, coverage targets met
- Final reviews, release notes, git tag

## Context-window protocol
If any agent exceeds 70% context, split across agents via `handoffs/` (see
HANDOFF_TEMPLATE.md). Rationale: COSTAS_LOOP precedent — single-agent overflow
caused a silent spec drift caught only at UVM regression.

## Exit criteria
- [ ] Architecture docs reviewed
- [ ] Golden model validation green (clean + error vectors)
- [ ] Each module: lint-clean + tb green + golden_check PASS
- [ ] UVM regression green (≥90% coverage target)
- [ ] Final RTL + test plan review signed off
- [ ] Release notes + user guide written
- [ ] Git tagged `v1.0.0`
