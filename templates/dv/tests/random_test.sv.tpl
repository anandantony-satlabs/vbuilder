// ============================================================================
// {{TITLE}} — random test
// ----------------------------------------------------------------------------
// Extended by vbuilder add-test when no custom base is requested.
// ============================================================================

class {{MODULE}}_random_test extends {{MODULE}}_base_test;
    `uvm_component_utils({{MODULE}}_random_test)

    function new(string name = "{{MODULE}}_random_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "Random test built", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        {{MODULE}}_seq seq;
        phase.raise_objection(this);
        `uvm_info(get_type_name(), "=== Random Test ===", UVM_NONE)
        seq = {{MODULE}}_seq::type_id::create("seq");
        seq.num_trans = 5000;
        seq.start(sqr);
        phase.drop_objection(this);
    endtask
endclass
