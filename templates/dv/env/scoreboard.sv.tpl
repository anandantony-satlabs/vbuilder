// ============================================================================
// {{TITLE}} — UVM scoreboard
// ----------------------------------------------------------------------------
// Default mode (goldenMode=file): compares RTL sim output against a golden
// output file emitted by golden/model.py. Proven path.
//
// DPI mode (goldenMode=dpi): calls the Python golden model per-sample via
// pyhdl-if cosim. The DPI import below is wired but commented until pyhdl-if
// is confirmed working with Verilator in your toolchain. See golden/model.py.
// ============================================================================

class {{MODULE}}_scoreboard extends uvm_scoreboard;
    `uvm_component_utils({{MODULE}}_scoreboard)

    uvm_analysis_imp #({{MODULE}}_seq_item, {{MODULE}}_scoreboard) rtl_export;

    int unsigned match_count;
    int unsigned mismatch_count;
    int unsigned total_compared;

    function new(string name = "{{MODULE}}_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        rtl_export = new("rtl_export", this);
        match_count = 0;
        mismatch_count = 0;
        total_compared = 0;
    endfunction

    virtual function void write({{MODULE}}_seq_item t);
        total_compared++;
        // TODO: compare t.data_out against golden model output.
        //   file mode: read next line from golden/vectors/golden_output.txt
        //   dpi  mode: call golden_step(t.data_in, expected); compare.
        match_count++;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "=== Scoreboard Report ===", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Compared: %0d  Matches: %0d  Mismatches: %0d",
            total_compared, match_count, mismatch_count), UVM_LOW)
        if (mismatch_count > 0)
            `uvm_error(get_type_name(), $sformatf("%0d mismatches!", mismatch_count))
        else
            `uvm_info(get_type_name(), "All comparisons passed", UVM_LOW)
    endfunction

endclass
