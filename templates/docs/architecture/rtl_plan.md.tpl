# {{TITLE}} — RTL Plan

## Coding guidelines
- SystemVerilog (`.sv`), `always_ff` for sequential, `assign` for comb.
- Constants in `{{MODULE}}_pkg.sv` — never re-derived inline.
- Each module passes `verilator --lint-only` before commit.

## Hierarchy
```
{{MODULE}} (top)
├── <submodule>   # add via vbuilder add-module
```

## Build order
Bottom-up: each submodule reaches `golden_check` PASS before the next starts
(FACTORY.md §5 S2 gate).
