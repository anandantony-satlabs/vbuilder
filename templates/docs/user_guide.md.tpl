# {{TITLE}} — User Guide

## Building
```bash
make regress   # full gate: lint -> tb -> golden -> uvm
```

## Running a single test
```bash
make -C dv run-{{MODULE}}_sanity_test
```

## Inspecting output
- RTL waveform: `rtl/tb/*.vcd` (gtkwave)
- UVM waveform: `dv/sim/*.fst` (gtkwave)
- Golden vectors: `golden/vectors/`
