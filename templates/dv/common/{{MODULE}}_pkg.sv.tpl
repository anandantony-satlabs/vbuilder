// ============================================================================
// {{TITLE}} — DV package (UVM class visibility)
// ----------------------------------------------------------------------------
// All UVM components are `included here so they share one compile unit.
// vbuilder maintains the {{VBUILDER:PKG_*}} anchors — do not delete them.
//
// CRITICAL: Test .sv files are `included here (NOT listed in dv/filelist.f)
// so the UVM factory registers them in the package compilation unit. This is
// the Antmicro-proven pattern — listing tests as standalone files in
// filelist.f causes NOCOMP (factory can't find the test class).
// ============================================================================

package {{MODULE}}_pkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    // --- env components ---
    // {{VBUILDER:PKG_ENV}}
    `include "../env/{{MODULE}}_agent.sv"
    `include "../env/{{MODULE}}_predictor.sv"
    `include "../env/scoreboard.sv"
    `include "../cov/coverage.sv"
    `include "../env/{{MODULE}}_env.sv"

    // --- tests ---
    // {{VBUILDER:PKG_TESTS}}
    `include "../tests/base_test.sv"
    `include "../tests/sanity_test.sv"
    `include "../tests/random_test.sv"

endpackage
