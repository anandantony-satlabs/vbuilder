// ============================================================================
// {{TITLE}} — UVM agent (seq_item + driver + sequencer + monitor)
// ============================================================================

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
        return $sformatf("data_in=%0d enable=%0b", data_in, enable);
    endfunction
endclass

// --- Driver ---
class {{MODULE}}_driver extends uvm_driver #({{MODULE}}_seq_item);
    `uvm_component_utils({{MODULE}}_driver)
    // virtual {{MODULE}}_if vif;  // TODO: connect via config_db
    function new(string name = "{{MODULE}}_driver", uvm_component parent);
        super.new(name, parent);
    endfunction
    virtual task run_phase(uvm_phase phase);
        // TODO: drive vif from seq_item_port.
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
    uvm_analysis_port #({{MODULE}}_seq_item) ap;
    function new(string name = "{{MODULE}}_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
    endfunction
    virtual task run_phase(uvm_phase phase);
        // TODO: sample DUT outputs and write to ap.
    endtask
endclass

// --- Agent ---
class {{MODULE}}_agent extends uvm_agent;
    `uvm_component_utils({{MODULE}}_agent)
    {{MODULE}}_driver    driver;
    {{MODULE}}_sequencer sequencer;
    {{MODULE}}_monitor   monitor;
    function new(string name = "{{MODULE}}_agent", uvm_component parent);
        super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = {{MODULE}}_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = {{MODULE}}_driver::type_id::create("driver", this);
            sequencer = {{MODULE}}_sequencer::type_id::create("sequencer", this);
        end
    endfunction
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass
