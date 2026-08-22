# ============================================================================
# {{PROJECT}} — RTL compile list (ordered)
# ----------------------------------------------------------------------------
# Order matters (IEEE 1800-2017 §26.3): packages first, then submodules, then
# top modules last. vbuilder maintains this via `add-module`.
# ============================================================================

# --- packages (always first) ---
{{MODULE}}_pkg.sv

# --- submodules ---
# {{VBUILDER:RTL_MODULES}}

# --- top modules (always last) ---
# {{VBUILDER:RTL_TOPS}}
{{MODULE}}.sv
