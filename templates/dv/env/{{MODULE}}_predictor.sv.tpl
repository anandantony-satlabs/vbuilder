// ============================================================================
// {{TITLE}} — UVM predictor (golden-model adapter)
// ----------------------------------------------------------------------------
// Consumes input-side transactions and produces the EXPECTED output stream
// for the scoreboard. The golden reference is golden/model.py (the
// executable spec):
//
//   file mode: replay golden/vectors/golden_output.txt in transaction order
//   dpi  mode: import "DPI-C" golden_step(...) per sample
//
// The predictor is the ONLY place expected values are produced — keep the
// scoreboard a pure comparator so RTL/model disagreements stay attributable.
// ============================================================================

class {{MODULE}}_predictor extends uvm_component;
    `uvm_component_utils({{MODULE}}_predictor)

    // Input-side transactions (stimulus or monitor input sampling).
    uvm_analysis_imp #({{MODULE}}_seq_item, {{MODULE}}_predictor) in_export;
    // Expected output stream, fed to the scoreboard's expected_export.
    uvm_analysis_port #({{MODULE}}_seq_item) expected_ap;

    function new(string name = "{{MODULE}}_predictor", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        in_export   = new("in_export",   this);
        expected_ap = new("expected_ap", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        // Placeholder guard: until the golden hook below is implemented, the
        // expected stream MIRRORS the DUT output (identity mapping), so any
        // scoreboard comparison is a tautology. A PASS under this warning
        // proves infrastructure only — not RTL correctness. Remove this
        // warning when you implement the golden model.
        `uvm_warning("PREDICTOR_PLACEHOLDER",
            "predictor uses identity mapping (e.data_out = t.data_out); PASS proves infrastructure only — implement the golden-model hook")
    endfunction

    virtual function void write({{MODULE}}_seq_item t);
        {{MODULE}}_seq_item e;
        e = {{MODULE}}_seq_item::type_id::create("e");
        // TODO: compute e.data_out from t via the golden model:
        //   file mode: read the next value from golden/vectors/golden_output.txt
        //   dpi  mode: e.data_out = golden_step(t.data_in);
        e.data_out = t.data_out; // placeholder: identity mapping
        expected_ap.write(e);
    endfunction

endclass
