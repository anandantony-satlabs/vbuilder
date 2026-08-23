// ============================================================================
// {{TITLE}} — functional coverage collector
// ----------------------------------------------------------------------------
// Subscribes to the monitor stream via uvm_subscriber (analysis_export).
// Instantiated and connected by {{MODULE}}_env out of the box.
//
// TODO: add covergroups here once you target a simulator with full
// functional-coverage support (covergroup support in open simulators is
// limited). Until then this component tracks simple counters so the
// analysis chain is exercised.
// ============================================================================

class {{MODULE}}_coverage extends uvm_subscriber #({{MODULE}}_seq_item);
    `uvm_component_utils({{MODULE}}_coverage)

    int unsigned sampled_count;

    function new(string name = "{{MODULE}}_coverage", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sampled_count = 0;
    endfunction

    virtual function void write({{MODULE}}_seq_item t);
        // TODO: sample covergroups with transaction fields here.
        sampled_count++;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), $sformatf("=== Coverage Report: %0d transactions observed ===",
            sampled_count), UVM_LOW)
    endfunction
endclass
