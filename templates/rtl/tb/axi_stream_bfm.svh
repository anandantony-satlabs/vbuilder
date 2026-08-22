// ============================================================================
// axi_stream_bfm.svh — Reusable AXI-Stream Bus Functional Model
// ----------------------------------------------------------------------------
// Provides standard driver macros + monitor pattern for AXI-Stream-like byte
// streams with valid/ready handshake. Encapsulates the timing convention so
// TBs don't reinvent the handshake stimulus each time.
//
// Two patterns:
//   1. AXI_SEND_BYTE  — full AXI-Stream with backpressure (TX modules)
//      Signals: data_in, data_valid, data_ready, start_of_packet, end_of_packet
//   2. STREAM_SEND_BYTE — pure streaming, no backpressure (RX modules)
//      Signals: data_in, data_valid, frame_start
//      The RX pipeline (frame_sync → descrambler → RS decoder → validator)
//      is pure streaming — no data_ready. Use STREAM_SEND_BYTE for these.
//
// IMPORTANT: Uses MACROS (not tasks) for the driver because Verilator
// schedules @(posedge clk) inside tasks differently than inline code.
// Macros expand inline, preserving the correct scheduling order.
//
// Usage (in a TB):
//   `include "axi_stream_bfm.svh"
//
//   // TX (backpressure handshake):
//   `AXI_SEND_BYTE(data_in, data_valid, data_ready, start_of_packet,
//                  end_of_packet, byte_value, 1'b1, 1'b0)
//
//   // RX (streaming, no backpressure):
//   `STREAM_SEND_BYTE(data_in, data_valid, frame_start, byte_value, 1'b1)
//
//   // Monitor: capture bytes (in always block)
//   always @(posedge clk) begin
//       if (data_out_valid) begin
//           out_stream[out_count] = data_out;
//           out_count = out_count + 1;
//       end
//   end
//
// Design rules (learned the hard way):
//   - Use macros, NOT tasks (Verilator task @(posedge clk) scheduling differs)
//   - Blocking assignments for driving (immediate, before posedge)
//   - Clocking block NOT needed for basic driving (blocking assignments work)
// ============================================================================

`ifndef AXI_STREAM_BFM_SVH
`define AXI_STREAM_BFM_SVH

// ---------------------------------------------------------------------------
// Macro: AXI_SEND_BYTE
//   Sends one byte with proper AXI-Stream handshake.
//   Expands inline (NOT a task — Verilator schedules task @(posedge clk)
//   differently than inline code, causing timing issues).
//
// Arguments:
//   din, dvalid, dready — the AXI-Stream input signals
//   dsop, deop          — start_of_packet / end_of_packet
//   val                 — byte value to send
//   first               — set sop=1 on this byte
//   last                — set eop=1 on this byte
// ---------------------------------------------------------------------------
`define AXI_SEND_BYTE(din, dvalid, dready, dsop, deop, val, first, last) \
    begin \
        din = val; \
        dvalid = 1'b1; \
        dsop = first; \
        deop = last; \
        @(posedge clk); \
        while (!dready) @(posedge clk); \
    end

// ---------------------------------------------------------------------------
// Macro: AXI_SEND_BURST
//   Sends an array of bytes as a contiguous burst with sop on first byte.
//   Requires a local variable `i` to be declared.
// ---------------------------------------------------------------------------
`define AXI_SEND_BURST(din, dvalid, dready, dsop, deop, values, n) \
    begin \
        int i; \
        for (i = 0; i < n; i++) begin \
            `AXI_SEND_BYTE(din, dvalid, dready, dsop, deop, \
                          values[i], (i == 0), (i == n - 1)) \
        end \
    end

// ---------------------------------------------------------------------------
// Macro: STREAM_SEND_BYTE
//   Sends one byte on a pure streaming interface (no backpressure).
//   Use this for RX modules (frame_sync, descrambler, rs_decoder, validator)
//   which have data_in + data_valid + frame_start but NO data_ready.
//
//   The byte is driven immediately, then advances one clock.
//   No handshake wait — data flows every cycle.
//
// Arguments:
//   din, dvalid, dframe_start — the streaming input signals
//   val                       — byte value to send
//   first                     — set frame_start=1 on this byte
// ---------------------------------------------------------------------------
`define STREAM_SEND_BYTE(din, dvalid, dframe_start, val, first) \
    begin \
        din = val; \
        dvalid = 1'b1; \
        dframe_start = first; \
        @(posedge clk); \
    end

// ---------------------------------------------------------------------------
// Macro: STREAM_SEND_BURST
//   Sends an array of bytes as a contiguous stream with frame_start on first.
//   No backpressure — one byte per clock cycle.
// ---------------------------------------------------------------------------
`define STREAM_SEND_BURST(din, dvalid, dframe_start, values, n) \
    begin \
        int i; \
        for (i = 0; i < n; i++) begin \
            `STREAM_SEND_BYTE(din, dvalid, dframe_start, \
                             values[i], (i == 0)) \
        end \
    end

// ---------------------------------------------------------------------------
// Macro: STREAM_SEND_IDLE
//   Sends one idle cycle (data_valid=0, no frame_start).
//   Useful for inserting inter-frame gaps in RX tests.
// ---------------------------------------------------------------------------
`define STREAM_SEND_IDLE(din, dvalid, dframe_start) \
    begin \
        din = 8'h00; \
        dvalid = 1'b0; \
        dframe_start = 1'b0; \
        @(posedge clk); \
    end

// ---------------------------------------------------------------------------
// Macro: AXI_CHECK_RESULT
//   Compares captured output against an expected array.
//   Prints OK/FAIL per byte and increments `errors`.
//   Works for both AXI-Stream (TX) and streaming (RX) monitors.
// ---------------------------------------------------------------------------
`define AXI_CHECK_RESULT(stream, count, expected, n, errors, label) \
    begin \
        int i; \
        $display("--- %s: %0d bytes ---", label, n); \
        if (count < n) begin \
            $display("FAIL: only %0d bytes captured (expected %0d)", count, n); \
            errors++; \
        end else begin \
            for (i = 0; i < n; i++) begin \
                if (stream[i] !== expected[i]) begin \
                    $display("FAIL: byte %0d: got 0x%02h, expected 0x%02h", \
                             i, stream[i], expected[i]); \
                    errors++; \
                end else begin \
                    $display("OK:   byte %0d = 0x%02h", i, stream[i]); \
                end \
            end \
        end \
    end

`endif
