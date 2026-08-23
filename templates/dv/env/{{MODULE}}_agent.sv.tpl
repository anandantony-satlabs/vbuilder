// ============================================================================
// {{TITLE}} — UVM agent (cfg + seq_item + driver + sequencer + monitor)
// ----------------------------------------------------------------------------
// The agent builds an {{MODULE}}_agent_cfg and publishes it to its children
// (driver, monitor) via uvm_config_db ("cfg"). The virtual interface comes
// from config_db key "vif" (set by <module>_tb_top) unless a full cfg object
// was provided by the test.
// ============================================================================

// --- Agent configuration object ---
class {{MODULE}}_agent_cfg extends uvm_object;
    `uvm_object_utils({{MODULE}}_agent_cfg)

    virtual {{MODULE}}_if   vif;
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    int unsigned            num_trans = 1000;

    function new(string name = "{{MODULE}}_agent_cfg");
        super.new(name);
    endfunction
endclass

// --- Sequence item ---
class {{MODULE}}_seq_item extends uvm_sequence_item;
    `uvm_object_utils({{MODULE}}_seq_item)

    rand bit [{{DATA_WIDTH}}-1:0] data_in;
    rand bit                      enable;
    rand int unsigned             delay_cycles;
    bit     [{{DATA_WIDTH}}-1:0]  data_out;

    constraint c_delay { delay_cycles inside {[0:10]}; }

    function new(string name = "{{MODULE}}_seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("data_in=%0d enable=%0b data_out=%0d",
                         data_in, enable, data_out);
    endfunction
endclass

// --- Driver ---
class {{MODULE}}_driver extends uvm_driver #({{MODULE}}_seq_item);
    `uvm_component_utils({{MODULE}}_driver)
    {{MODULE}}_agent_cfg cfg;

    function new(string name = "{{MODULE}}_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#({{MODULE}}_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal(get_type_name(), "agent cfg ('cfg') not found in uvm_config_db")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            // TODO: drive req fields onto the DUT via cfg.vif (use the cb_drv
            // clocking block for race-free signal driving), honoring
            // req.delay_cycles as idle cycles between transfers.
            @(posedge cfg.vif.clk);
            seq_item_port.item_done();
        end
    endtask
endclass

// --- Sequencer ---
class {{MODULE}}_sequencer extends uvm_sequencer #({{MODULE}}_seq_item);
    `uvm_component_utils({{MODULE}}_sequencer)
    function new(string name = "{{MODULE}}_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// --- Monitor ---
class {{MODULE}}_monitor extends uvm_monitor;
    `uvm_component_utils({{MODULE}}_monitor)
    {{MODULE}}_agent_cfg cfg;
    uvm_analysis_port #({{MODULE}}_seq_item) ap;

    function new(string name = "{{MODULE}}_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#({{MODULE}}_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal(get_type_name(), "agent cfg ('cfg') not found in uvm_config_db")
    endfunction

    virtual task run_phase(uvm_phase phase);
        {{MODULE}}_seq_item t;
        forever begin
            @(posedge cfg.vif.clk);
            // TODO: replace placeholder sampling below with real DUT output
            // sampling on cfg.vif.cb_mon (fill t.data_out etc. first).
            // The item IS published every clock so the analysis chain
            // (monitor -> scoreboard -> coverage) is live out of the box.
            t = {{MODULE}}_seq_item::type_id::create("t");
            ap.write(t);
        end
    endtask
endclass

// --- Agent ---
class {{MODULE}}_agent extends uvm_agent;
    `uvm_component_utils({{MODULE}}_agent)
    {{MODULE}}_agent_cfg  cfg;
    {{MODULE}}_driver     driver;
    {{MODULE}}_sequencer  sequencer;
    {{MODULE}}_monitor    monitor;

    function new(string name = "{{MODULE}}_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Use an externally supplied cfg if the test set one; otherwise build
        // a default one and pull the vif from config_db (key "vif", set by
        // tb_top). A missing vif is FATAL for the top-level DUT agent; but an
        // agent may also be stamped as an unwired skeleton (add-module
        // --alsoDv) — in that case warn once and idle instead of killing
        // every simulation in the project.
        if (!uvm_config_db#({{MODULE}}_agent_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = {{MODULE}}_agent_cfg::type_id::create("cfg");
            if (!uvm_config_db #(virtual {{MODULE}}_if)::get(this, "", "vif", cfg.vif)) begin
                `uvm_warning(get_type_name(),
                            "no 'vif' in uvm_config_db — agent idles until tb_top wires the interface")
                return; // skeleton mode: create no children this build
            end
        end
        // Publish cfg for the children, then respect it for active/passive.
        uvm_config_db#({{MODULE}}_agent_cfg)::set(this, "*", "cfg", cfg);
        is_active = cfg.is_active;

        monitor = {{MODULE}}_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = {{MODULE}}_driver::type_id::create("driver", this);
            sequencer = {{MODULE}}_sequencer::type_id::create("sequencer", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Handles may be null in skeleton mode (no vif wired yet).
        if (driver != null && sequencer != null)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass
