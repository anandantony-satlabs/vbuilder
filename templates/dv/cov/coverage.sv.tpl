// ============================================================================
// {{TITLE}} — functional coverage model
// ============================================================================

class {{MODULE}}_coverage extends uvm_component;
    `uvm_component_utils({{MODULE}}_coverage)

    uvm_analysis_imp #({{MODULE}}_seq_item, {{MODULE}}_coverage) analysis_export;

    function new(string name = "{{MODULE}}_coverage", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
    endfunction

    virtual function void write({{MODULE}}_seq_item t);
        // TODO: sample covergroups with transaction fields.
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "=== Coverage Report ===", UVM_LOW)
    endfunction
endclass
