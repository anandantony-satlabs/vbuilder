# ============================================================================
// {{PROJECT}} — DV compile list (ordered)
// ----------------------------------------------------------------------------
// Order: package(s) first → env components → tests → tb_top last.
// Maintained by vbuilder add-module / add_test (idempotent, anchor-patched).
//
// CRITICAL: Test .sv files are NOT listed here — they are `included inside
// {{MODULE}}_pkg.sv so the UVM factory registers them in the package
// compilation unit. Listing them as standalone files causes NOCOMP.
// ============================================================================

# --- packages (always first) ---
common/{{MODULE}}_pkg.sv

# --- env components ---
# {{VBUILDER:DV_ENV}}

# --- tests ---
# (test .sv files are `included inside {{MODULE}}_pkg.sv — do NOT list here)
# {{VBUILDER:DV_TESTS}}

# --- tb top (always last) ---
tb/{{MODULE}}_tb_top.sv
