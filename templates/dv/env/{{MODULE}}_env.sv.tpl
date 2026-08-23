// ============================================================================
// {{TITLE}} — UVM environment
// ----------------------------------------------------------------------------
// Holds agent, predictor, scoreboard (comparator), coverage. vbuilder
// auto-inserts component handles / creation / connections at its owned
// anchor markers inside this file (do not delete the marker comments).
//
// Analysis topology (all live out of the box):
//   agent.monitor.ap --> sb.actual_export     (DUT output stream)
//   agent.monitor.ap --> predictor.in_export  (input-side stream)
//   agent.monitor.ap --> cov.analysis_export
//   predictor.expected_ap --> sb.expected_export
// ============================================================================

class {{MODULE}}_env extends uvm_env;
    `uvm_component_utils({{MODULE}}_env)

    {{MODULE}}_agent      agent;
    {{MODULE}}_predictor  predictor;
    {{MODULE}}_scoreboard sb;
    {{MODULE}}_coverage   cov;

    // {{VBUILDER:ENV_FIELDS}}
    // component handles auto-inserted here by add-module --alsoDv

    function new(string name = "{{MODULE}}_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent     = {{MODULE}}_agent::type_id::create("agent", this);
        predictor = {{MODULE}}_predictor::type_id::create("predictor", this);
        sb        = {{MODULE}}_scoreboard::type_id::create("sb", this);
        cov       = {{MODULE}}_coverage::type_id::create("cov", this);
        // {{VBUILDER:ENV_BUILD}}
        // component creation auto-inserted here
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(sb.actual_export);
        agent.monitor.ap.connect(predictor.in_export);
        agent.monitor.ap.connect(cov.analysis_export);
        predictor.expected_ap.connect(sb.expected_export);
        // {{VBUILDER:ENV_CONNECT}}
        // additional analysis connections auto-inserted by add-module --alsoDv
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
