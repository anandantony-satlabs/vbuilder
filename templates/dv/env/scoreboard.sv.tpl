// ============================================================================
// {{TITLE}} — UVM scoreboard (in-order comparator)
// ----------------------------------------------------------------------------
// Compares two transaction streams:
//   actual   — DUT outputs sampled by the monitor      (write_act)
//   expected — golden-model predictions, from the predictor (write_exp)
//
// The golden reference lives in golden/model.py:
//   file mode: the predictor replays golden/vectors/golden_output.txt
//   dpi  mode: the predictor calls golden_step() per sample
// The scoreboard itself only compares — never re-derives expected values.
// ============================================================================

// Distinct write methods per analysis imp (uvm_analysis_imp_decl).
// NOTE: UVM delivers analysis writes in LEXICOGRAPHIC ORDER of the connected
// imp's full name (m_imp_list is a string-keyed assoc array) — NOT connect()
// order, and NOT alphabetical-by-luck that survives renames. Both inputs are
// therefore queued and paired below, making this scoreboard correct
// regardless of which subscriber fires first.
`uvm_analysis_imp_decl(_act)
`uvm_analysis_imp_decl(_exp)

class {{MODULE}}_scoreboard extends uvm_scoreboard;
    `uvm_component_utils({{MODULE}}_scoreboard)

    // DUT output stream (from monitor).
    uvm_analysis_imp_act #({{MODULE}}_seq_item, {{MODULE}}_scoreboard) actual_export;
    // Golden prediction stream (from predictor).
    uvm_analysis_imp_exp #({{MODULE}}_seq_item, {{MODULE}}_scoreboard) expected_export;

    protected {{MODULE}}_seq_item expected_q[$];
    protected {{MODULE}}_seq_item actual_q[$];

    int unsigned match_count;
    int unsigned mismatch_count;
    int unsigned total_compared;

    function new(string name = "{{MODULE}}_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        actual_export   = new("actual_export",   this);
        expected_export = new("expected_export", this);
        match_count    = 0;
        mismatch_count = 0;
        total_compared = 0;
    endfunction

    // Drain all fully-paired (expected, actual) transactions. Whichever
    // stream arrives first is simply queued until its partner shows up, so
    // callback order between predictor and scoreboard cannot cause spurious
    // "no pending expectation" errors.
    protected function void try_match();
        {{MODULE}}_seq_item a, e;
        while (expected_q.size() > 0 && actual_q.size() > 0) begin
            e = expected_q.pop_front();
            a = actual_q.pop_front();
            total_compared++;
            // TODO: replace with spec-true field comparison (e.g. e.data_out vs
            // a.data_out, plus sideband checks). Placeholder compares data_out.
            if (e.data_out !== a.data_out) begin
                mismatch_count++;
                `uvm_error(get_type_name(), $sformatf("MISMATCH: expected=%0h actual=%0h (%s)",
                    e.data_out, a.data_out, a.convert2string()))
            end else begin
                match_count++;
            end
        end
    endfunction

    // Predictor output arrives here.
    virtual function void write_exp({{MODULE}}_seq_item t);
        expected_q.push_back(t);
        try_match();
    endfunction

    // DUT output arrives here — pair against the oldest expectation.
    virtual function void write_act({{MODULE}}_seq_item t);
        actual_q.push_back(t);
        try_match();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (expected_q.size() != 0) begin
            `uvm_error(get_type_name(), $sformatf("%0d expected transactions never matched (missing DUT outputs?)",
                expected_q.size()))
            mismatch_count += expected_q.size();
        end
        if (actual_q.size() != 0) begin
            `uvm_error(get_type_name(), $sformatf("%0d DUT outputs never matched (missing predictions?)",
                actual_q.size()))
            mismatch_count += actual_q.size();
        end
        `uvm_info(get_type_name(), "=== Scoreboard Report ===", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Compared: %0d  Matches: %0d  Mismatches: %0d",
            total_compared, match_count, mismatch_count), UVM_LOW)
        if (mismatch_count > 0)
            `uvm_error(get_type_name(), $sformatf("%0d mismatches!", mismatch_count))
        else
            `uvm_info(get_type_name(), "All comparisons passed", UVM_LOW)
    endfunction

endclass
