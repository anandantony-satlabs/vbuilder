// ============================================================================
// {{TITLE}} — UVM Virtual Interface
// ----------------------------------------------------------------------------
// Mirrors the DUT's port list. Contains clocking blocks for the driver
// (output) and monitor (input).
//
// The interface is set into config_db by {{MODULE}}_tb_top and retrieved
// by the driver and monitor in their build_phase.
//
// To wire: uncomment the signals below and match the DUT's port list.
// ============================================================================

`timescale 1ns/1ps

interface {{MODULE}}_if (
    input logic clk,
    input logic rst_n
);

    // TODO: Add DUT signals here (mirror {{MODULE}}'s port list)
    // logic [{{DATA_WIDTH}}-1:0]  data_in;
    // logic                       data_valid;
    // logic [{{DATA_WIDTH}}-1:0]  data_out;
    // logic                       data_out_valid;

    // --- Driver clocking block (output to DUT) ---
    clocking cb_drv @(posedge clk);
        // output data_in;
        // output data_valid;
    endclocking

    // --- Monitor clocking block (input from DUT) ---
    clocking cb_mon @(posedge clk);
        // input data_out;
        // input data_out_valid;
    endclocking

endinterface
