# {{TITLE}} — Test Plan

## Verification strategy
Golden-model-first: the UVM scoreboard compares RTL output against the Python
golden model. Default = file-mode diff; opt-in = pyhdl-if DPI per-sample cosim.

## Test scenarios
| Test | Description | Pass criterion |
|------|-------------|----------------|
| `{{MODULE}}_sanity_test` | basic reset + enable + data flow | no UVM_ERROR |
| `{{MODULE}}_random_test` | random stimulus, 5000 trans | no UVM_ERROR, scoreboard match |

(Add more via `vbuilder add-test <name>` — auto-wired into regression.)

## Coverage targets
- Functional: ≥90%
- Reset/enable states covered
- (per module) corner cases listed here

## Regression
`make regress` runs lint → tb → golden → uvm. CI runs this on every push.
