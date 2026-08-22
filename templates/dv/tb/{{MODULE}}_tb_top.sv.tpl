// ============================================================================
// {{TITLE}} — UVM testbench top
// ----------------------------------------------------------------------------
// DUT instantiation, clock/reset, virtual interface config_db, run_test().
// Target: Verilator with UVM 2017 support.
//
// This scaffold calls run_test() — a TRUE green. UVM will instantiate the
// test class (selected via +UVM_TESTNAME), run all phases, and the test's
// report_phase will print PASS/FAIL based on UVM_ERROR count. This proves
// the UVM toolchain works (compilation, factory, phases) before any RTL
// is written.
//
// To wire the real DUT:
//   1. Uncomment the DUT instantiation below and connect signals.
//   2. Uncomment the virtual interface in {{MODULE}}_if.sv.
//   3. Set the vif in config_db (already done below).
// ============================================================================

`timescale 1ns/1ps
`include "uvm_macros.svh"

import uvm_pkg::*;
import {{MODULE}}_pkg::*;

module {{MODULE}}_tb_top;

    localparam DATA_WIDTH = {{DATA_WIDTH}};
    localparam CLK_PERIOD  = 10;  // 100 MHz

    logic                    clk;
    logic                    rst_n;
    // TODO: DUT signals — mirror {{MODULE}}'s port list.

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

    // Virtual interface
    {{MODULE}}_if vif (.clk(clk), .rst_n(rst_n));

    // DUT — uncomment and wire when RTL is implemented
    // {{MODULE}} u_dut (
    //     .clk   (clk),
    //     .rst_n (rst_n)
    // );

    // Config DB + run_test — the UVM entry point.
    // +UVM_TESTNAME=<test_class> selects the test (set by make run-<test>).
    initial begin
        uvm_config_db #(virtual {{MODULE}}_if)::set(null, "*", "vif", vif);
        run_test();
    end

    // Waveform dump
    initial begin
        $dumpfile("{{MODULE}}_tb.vcd");
        $dumpvars(0, {{MODULE}}_tb_top);
    end

    // Timeout
    initial begin
        #(10_000_000);
        `uvm_fatal("TB_TOP", "Simulation timeout")
    end

endmodule
