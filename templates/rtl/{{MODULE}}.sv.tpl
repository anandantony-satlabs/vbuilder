// ============================================================================
// {{TITLE}} — top-level RTL module
// ----------------------------------------------------------------------------
// Project: {{PROJECT}}
// Module:  {{MODULE}}
//
// This is a skeleton stamped by vbuilder. Fill the datapath; keep the interface.
// Submodules added via `vbuilder add-module` may be instantiated below at the
// {{VBUILDER:INSTANCES}} anchor if `addToTop` is used.
// ============================================================================

// package constants — compiled separately (see filelist.f), import don't include
// to avoid MODDUP when both the pkg and this file are on the command line.

module {{MODULE}} #(
{{PARAMS_SV}}
)(
{{PORTS_SV}}
);

    import {{MODULE}}_pkg::*;

    // ------------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------------

    // {{VBUILDER:INSTANCES}}
    // Submodule instances are auto-inserted here when add-module --addToTop.

    // ------------------------------------------------------------------
    // Datapath (TODO: implement per microarchitecture doc)
    // ------------------------------------------------------------------



endmodule
