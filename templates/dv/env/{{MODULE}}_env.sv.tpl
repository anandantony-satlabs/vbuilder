// ============================================================================
// {{TITLE}} — UVM environment
// ----------------------------------------------------------------------------
// Holds agent, scoreboard, coverage. vbuilder auto-inserts component handles
// at the {{VBUILDER:ENV_FIELDS}} / {{VBUILDER:ENV_BUILD}} anchors.
// ============================================================================

class {{MODULE}}_env extends uvm_env;
    `uvm_component_utils({{MODULE}}_env)

    // {{VBUILDER:ENV_FIELDS}}
    // component handles auto-inserted here by add-module --alsoDv

    function new(string name = "{{MODULE}}_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // {{VBUILDER:ENV_BUILD}}
        // component creation auto-inserted here
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // TODO: connect monitor ports to scoreboard / coverage.
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "=== Environment Report ===", UVM_LOW)
    endfunction

endclass
