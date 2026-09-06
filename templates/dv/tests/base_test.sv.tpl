// ============================================================================
// {{TITLE}} — UVM base test + base sequence
// ============================================================================

class {{MODULE}}_base_test extends uvm_test;
    `uvm_component_utils({{MODULE}}_base_test)

    {{MODULE}}_env env;
    {{MODULE}}_sequencer sqr;

    function new(string name = "{{MODULE}}_base_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = {{MODULE}}_env::type_id::create("env", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        sqr = env.agent.sequencer;
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        // NOTE: uvm_top.print_topology() removed — Verilator cannot resolve the
        // package-scoped const `uvm_top` (see LESSONS.md L2/L10).
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info(get_type_name(), "Base test running", UVM_LOW)
        // TODO: start sequence(s).
        #100_000;
        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        super.report_phase(phase);
        // PASS/FAIL from the UVM report server's SEVERITY counters.
        // (get_id_count("UVM_ERROR") would count by message ID, which is the
        // reporting component's name — it returns ~0 always → false PASS.)
        svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_ERROR) > 0 ||
            svr.get_severity_count(UVM_FATAL) > 0)
            `uvm_info(get_type_name(), "*** TEST FAILED ***", UVM_NONE)
        else
            `uvm_info(get_type_name(), "*** TEST PASSED ***", UVM_NONE)
    endfunction
endclass

// --- Base sequence ---
class {{MODULE}}_seq extends uvm_sequence #({{MODULE}}_seq_item);
    `uvm_object_utils({{MODULE}}_seq)
    int unsigned num_trans = 1000;

    function new(string name = "{{MODULE}}_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), $sformatf("Sequence: %0d trans", num_trans), UVM_LOW)
        repeat(num_trans) begin
            `uvm_do(req)
        end
    endtask
endclass
