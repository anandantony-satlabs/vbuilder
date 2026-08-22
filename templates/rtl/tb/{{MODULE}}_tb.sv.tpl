// ============================================================================
// {{MODULE}} — standalone sanity testbench (pre-UVM)
// ----------------------------------------------------------------------------
// Quick RTL smoke test before the full UVM env is wired. Uses the shared
// AXI-Stream BFM for handshake timing. Run via:
//   make -C rtl/tb sim-{{MODULE}}
//
// The BFM (axi_stream_bfm.svh) encapsulates the #1 timing convention so you
// don't need to reinvent valid/ready stimulus. See tasks:
//   axi_send_byte(), axi_send_burst(), axi_check_result()
// ============================================================================

`timescale 1ns/1ps

`include "axi_stream_bfm.svh"  // shared BFM tasks
import {{MODULE}}_pkg::*;       // package constants (compiled separately)

module {{MODULE}}_tb;

    localparam CLK_PERIOD = 10;  // 100 MHz

    logic clk;
    logic rst_n;
    // TODO: connect to {{MODULE}} ports declared in the config.

    // Clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset
    initial begin
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
    end

    // DUT
    // {{MODULE}} u_dut (
    //     .clk    (clk),
    //     .rst_n  (rst_n)
    // );

    initial begin
        $dumpfile("{{MODULE}}_tb.vcd");
        $dumpvars(0, {{MODULE}}_tb);
        @(posedge rst_n);
        repeat(100) @(posedge clk);
        $display("[{{MODULE}}_tb] sanity complete");
        $display("*** TEST PASSED ***");
        $finish;
    end

endmodule
