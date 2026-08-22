# {{TITLE}} — RTL Code Review

Reviewer: ______  Date: ______  Stage: ______

## Checklist
- [ ] Constants from `{{MODULE}}_pkg.sv`, not re-derived
- [ ] `verilator --lint-only` clean
- [ ] Registered outputs, no comb loops
- [ ] Reset path consistent (active-low, synchronous)
- [ ] Interface matches `docs/architecture/module_interface.md`

## Notes
