# {{TITLE}} — Module Interface

## Top-level: `{{MODULE}}`

### Ports
| Name | Dir | Width | Description |
|------|-----|-------|-------------|
{{PORTS_TABLE}}

### Parameters
| Name | Default | Description |
|------|---------|-------------|
{{PARAMS_TABLE}}

## Conventions
- `clk` / `rst_n` active-low synchronous reset (held low ≥2 cycles).
- All logic synchronous to rising edge.
