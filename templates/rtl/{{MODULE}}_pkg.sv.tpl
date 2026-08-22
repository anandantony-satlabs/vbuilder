// ============================================================================
// {{TITLE}} — SystemVerilog package of constants
// ----------------------------------------------------------------------------
// Project: {{PROJECT}}
// Module:  {{MODULE}}
//
// Single source of truth for module constants. Per FACTORY.md §7-C, constants
// are declared here and checked against the golden model — never re-derived
// inline in RTL.
// ============================================================================

package {{MODULE}}_pkg;

    // ------------------------------------------------------------------
    // Data widths (edit to match the verified golden model)
    // ------------------------------------------------------------------
    localparam int DATA_WIDTH = {{DATA_WIDTH}};

    // ------------------------------------------------------------------
    // Protocol / algorithm constants
    // ------------------------------------------------------------------
    // TODO: fill from verified reference (golden/model.py), NOT hand-typed.
    // e.g. localparam [7:0] SYNC_PATTERN = 8'h1AC;

endpackage
