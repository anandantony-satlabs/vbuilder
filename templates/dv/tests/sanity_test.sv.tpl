// ============================================================================
// {{TEST}} — sanity test
// ----------------------------------------------------------------------------
// Added by vbuilder. Extend {{BASE_TEST}}, drive a short known-good sequence
// through the agent's sequencer. Objections are held only while the sequence
// runs (event-based, not time-based). Auto-registered: `make run-{{TEST}}`.
// ============================================================================

class {{TEST}} extends {{BASE_TEST}};
    `uvm_component_utils({{TEST}})

    function new(string name = "{{TEST}}", uvm_component parent);
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
        seq.start(sqr);
        phase.drop_objection(this);
    endtask
endclass
