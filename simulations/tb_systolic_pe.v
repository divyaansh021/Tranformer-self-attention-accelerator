// ============================================================
// Module  : tb_systolic_pe
// Project : Transformer Attention Block Accelerator
// File    : tb_systolic_pe.v
// Description:
//   Testbench for systolic_pe.v
//   Runs 5 test cases:
//     Test 1 - Basic multiply        : 2.0 * 3.0 = 6.0
//     Test 2 - Accumulation          : 1.0*1.0 + 2.0*2.0 + 3.0*3.0 = 14.0
//     Test 3 - Zero-skip on a_in     : 0 * 5.0 = skipped, acc stays 0
//     Test 4 - Zero-skip on b_in     : 3.0 * 0 = skipped, acc stays 0
//     Test 5 - Pass-through check    : a_out and b_out delayed by 1 cycle
//
//   Q8.8 encoding:
//     1.0  = 16'h0100  (256 in decimal)
//     2.0  = 16'h0200
//     3.0  = 16'h0300
//     0.5  = 16'h0080
//     0.0  = 16'h0000
//
//   Expected c_out values (Q8.8):
//     2.0 * 3.0        = 6.0   = 16'h0600
//     1+4+9            = 14.0  = 16'h0E00
// ============================================================

`timescale 1ns/1ps

module tb_systolic_pe;

    // --------------------------------------------------------
    // Parameters
    // --------------------------------------------------------
    parameter DW     = 16;
    parameter CLK_PERIOD = 10; // 10ns = 100MHz

    // --------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------
    reg              clk;
    reg              rst_n;
    reg              acc_clr;
    reg  [DW-1:0]    a_in;
    reg  [DW-1:0]    b_in;
    wire [DW-1:0]    a_out;
    wire [DW-1:0]    b_out;
    wire [DW-1:0]    c_out;
    wire             skipped;

    // --------------------------------------------------------
    // Test tracking
    // --------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // --------------------------------------------------------
    // DUT instantiation
    // --------------------------------------------------------
    systolic_pe #(.DW(DW)) DUT (
        .clk     (clk),
        .rst_n   (rst_n),
        .acc_clr (acc_clr),
        .a_in    (a_in),
        .b_in    (b_in),
        .a_out   (a_out),
        .b_out   (b_out),
        .c_out   (c_out),
        .skipped (skipped)
    );

    // --------------------------------------------------------
    // Clock generation
    // --------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // --------------------------------------------------------
    // Task: apply one cycle of inputs
    // --------------------------------------------------------
    task apply_inputs;
        input [DW-1:0] a;
        input [DW-1:0] b;
        input          clr;
        begin
            a_in    = a;
            b_in    = b;
            acc_clr = clr;
            @(posedge clk);
            #1; // small delay to let outputs settle
        end
    endtask

    // --------------------------------------------------------
    // Task: check c_out value
    // --------------------------------------------------------
    task check_result;
        input [DW-1:0]    expected;
        input [8*30-1:0]  test_name;
        begin
            if (c_out === expected) begin
                $display("  PASS | %s | c_out = %h (expected %h)",
                         test_name, c_out, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %s | c_out = %h (expected %h)",
                         test_name, c_out, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // --------------------------------------------------------
    // Task: reset the PE
    // --------------------------------------------------------
    task do_reset;
        begin
            rst_n   = 0;
            acc_clr = 0;
            a_in    = 0;
            b_in    = 0;
            @(posedge clk);
            @(posedge clk);
            rst_n = 1;
            @(posedge clk);
            #1;
        end
    endtask

    // --------------------------------------------------------
    // Task: clear accumulator between tests
    // --------------------------------------------------------
    task clear_acc;
        begin
            apply_inputs(0, 0, 1); // acc_clr = 1 for one cycle
            apply_inputs(0, 0, 0);
        end
    endtask

    // --------------------------------------------------------
    // Main test sequence
    // --------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("========================================");
        $display("  Testbench : systolic_pe");
        $display("  Format    : Q8.8 fixed-point (16-bit)");
        $display("  1.0 = 16'h0100, 2.0 = 16'h0200");
        $display("========================================");

        // ---- Reset ----
        do_reset;

        // ============================================
        // TEST 1: Basic single multiply
        // 2.0 * 3.0 = 6.0
        // Q8.8: 0x0200 * 0x0300
        // product = 0x00060000 (Q16.16)
        // c_out   = acc[23:8] = 0x0600
        // ============================================
        $display("\n--- Test 1: Basic multiply  2.0 x 3.0 = 6.0 ---");
        clear_acc;
        // drive inputs for one clock — product latches into acc on posedge
        a_in = 16'h0200; b_in = 16'h0300; acc_clr = 0;
        @(posedge clk); #1;  // acc captures product this edge
        // idle — c_out = acc[23:8] is now stable (combinational from acc reg)
        check_result(16'h0600, "2.0 x 3.0 = 6.0");
        $display("       skipped = %b (expect 0)", skipped);

        // ============================================
        // TEST 2: Accumulation over 3 cycles
        // cycle 1: 1.0 * 1.0 = 1.0   acc = 1.0
        // cycle 2: 2.0 * 2.0 = 4.0   acc = 5.0
        // cycle 3: 3.0 * 3.0 = 9.0   acc = 14.0
        // c_out = 14.0 = 0x0E00
        // ============================================
        $display("\n--- Test 2: Accumulation  1*1 + 2*2 + 3*3 = 14.0 ---");
        clear_acc;
        // each apply_inputs clocks one cycle and captures the product
        a_in=16'h0100; b_in=16'h0100; acc_clr=0; @(posedge clk); #1;
        a_in=16'h0200; b_in=16'h0200; acc_clr=0; @(posedge clk); #1;
        a_in=16'h0300; b_in=16'h0300; acc_clr=0; @(posedge clk); #1;
        // idle cycle — let last product settle into acc
        a_in=0; b_in=0; @(posedge clk); #1;
        check_result(16'h0E00, "1*1+2*2+3*3 = 14.0");

        // ============================================
        // TEST 3: Zero-skip when a_in = 0
        // 0 * 5.0 should be skipped — acc stays 0
        // skipped must be 1
        // ============================================
        $display("\n--- Test 3: Zero-skip  a_in=0, b_in=5.0 ---");
        clear_acc;
        a_in=16'h0000; b_in=16'h0500; acc_clr=0; @(posedge clk); #1;
        a_in=0; b_in=0; @(posedge clk); #1;
        check_result(16'h0000, "zero-skip a=0: acc stays 0");
        if (skipped === 1'b1) begin
            $display("  PASS | skipped = 1 (zero-skip fired correctly)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL | skipped = %b (expected 1)", skipped);
            fail_count = fail_count + 1;
        end

        // ============================================
        // TEST 4: Zero-skip when b_in = 0
        // 3.0 * 0 should be skipped — acc stays 0
        // ============================================
        $display("\n--- Test 4: Zero-skip  a_in=3.0, b_in=0 ---");
        clear_acc;
        a_in=16'h0300; b_in=16'h0000; acc_clr=0; @(posedge clk); #1;
        a_in=0; b_in=0; @(posedge clk); #1;
        check_result(16'h0000, "zero-skip b=0: acc stays 0");
        if (skipped === 1'b1) begin
            $display("  PASS | skipped = 1 (zero-skip fired correctly)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL | skipped = %b (expected 1)", skipped);
            fail_count = fail_count + 1;
        end

        // ============================================
        // TEST 5: Mixed — some zero, some nonzero
        // cycle 1: 2.0 * 0   = skip     acc = 0
        // cycle 2: 0   * 3.0 = skip     acc = 0
        // cycle 3: 2.0 * 3.0 = 6.0      acc = 6.0
        // c_out = 6.0 = 0x0600
        // ============================================
        $display("\n--- Test 5: Mixed zero/nonzero  ---");
        clear_acc;
        a_in=16'h0200; b_in=16'h0000; acc_clr=0; @(posedge clk); #1; // skip
        a_in=16'h0000; b_in=16'h0300; acc_clr=0; @(posedge clk); #1; // skip
        a_in=16'h0200; b_in=16'h0300; acc_clr=0; @(posedge clk); #1; // compute
        a_in=0; b_in=0; @(posedge clk); #1; // settle
        check_result(16'h0600, "mixed: only 2.0*3.0 accumulated");

        // ============================================
        // TEST 6: Pass-through check
        // a_out must equal a_in from the PREVIOUS cycle
        // b_out must equal b_in from the PREVIOUS cycle
        // ============================================
        $display("\n--- Test 6: Pass-through  a_out/b_out delayed 1 cycle ---");
        clear_acc;
        // drive known values
        a_in = 16'h0123;
        b_in = 16'h0456;
        acc_clr = 0;
        @(posedge clk); #1;
        // now a_out should be 0x0123, b_out should be 0x0456
        if (a_out === 16'h0123) begin
            $display("  PASS | a_out = %h (expected 0123)", a_out);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL | a_out = %h (expected 0123)", a_out);
            fail_count = fail_count + 1;
        end
        if (b_out === 16'h0456) begin
            $display("  PASS | b_out = %h (expected 0456)", b_out);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL | b_out = %h (expected 0456)", b_out);
            fail_count = fail_count + 1;
        end

        // ============================================
        // TEST 7: acc_clr functionality
        // accumulate 5.0, then clear, then check acc = 0
        // ============================================
        $display("\n--- Test 7: acc_clr clears accumulator ---");
        clear_acc;
        apply_inputs(16'h0100, 16'h0500, 0); // 1.0 * 5.0 = 5.0
        @(posedge clk); #1;
        // now clear
        apply_inputs(16'h0000, 16'h0000, 1); // acc_clr = 1
        @(posedge clk); #1;
        check_result(16'h0000, "acc_clr resets accumulator to 0");

        // ============================================
        // TEST 8: Negative numbers (signed Q8.8)
        // -1.0 = 16'hFF00  (two's complement)
        // -1.0 * 2.0 = -2.0 = 16'hFE00
        // ============================================
        $display("\n--- Test 8: Signed multiply  -1.0 x 2.0 = -2.0 ---");
        clear_acc;
        // -1.0 in Q8.8 = 0xFF00, 2.0 = 0x0200
        // product = (-256) * 512 = -131072 = 0xFFFE0000 (Q16.16)
        // c_out = acc[23:8] = 0xFE00 = -2.0 in Q8.8
        a_in=16'hFF00; b_in=16'h0200; acc_clr=0; @(posedge clk); #1;
        a_in=0; b_in=0; @(posedge clk); #1;
        check_result(16'hFE00, "-1.0 x 2.0 = -2.0");

        // ============================================
        // Final summary
        // ============================================
        $display("\n========================================");
        $display("  Results: %0d PASSED, %0d FAILED",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED — check waveform");
        $display("========================================");

        $finish;
    end

    // --------------------------------------------------------
    // Waveform dump for Vivado / GTKWave
    // --------------------------------------------------------
    initial begin
        $dumpfile("tb_systolic_pe.vcd");
        $dumpvars(0, tb_systolic_pe);
    end

    // --------------------------------------------------------
    // Timeout watchdog — stops sim if it hangs
    // --------------------------------------------------------
    initial begin
        #10000;
        $display("TIMEOUT — simulation exceeded 10000ns");
        $finish;
    end

endmodule
