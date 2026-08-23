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
