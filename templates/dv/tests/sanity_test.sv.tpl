// ============================================================================
// {{TITLE}} — sanity test
// ----------------------------------------------------------------------------
// Added by vbuilder. Extend {{MODULE}}_base_test, run basic checks.
// Auto-registered: `make run-{{MODULE}}_sanity_test`.
// ============================================================================

class {{MODULE}}_sanity_test extends {{MODULE}}_base_test;
    `uvm_component_utils({{MODULE}}_sanity_test)

    function new(string name = "{{MODULE}}_sanity_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "Sanity test built", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        {{MODULE}}_seq seq;
        phase.raise_objection(this);
        `uvm_info(get_type_name(), "=== Sanity Test ===", UVM_NONE)
        seq = {{MODULE}}_seq::type_id::create("seq");
        // seq.start(sqr);  // TODO: once sequencer wired
        #10_000;
        phase.drop_objection(this);
    endtask
endclass
