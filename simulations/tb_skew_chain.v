// ============================================================
// Testbench : tb_skew_chain
// File      : tb_skew_chain.v
//
// Tests:
//   Test 1 - out_0 passes through in_0 immediately (0 delay)
//   Test 2 - out_1 delayed exactly 1 cycle
//   Test 3 - out_2 delayed exactly 2 cycles
//   Test 4 - out_7 delayed exactly 7 cycles
//   Test 5 - simultaneous pulse on all lanes — verify each
//             output appears at correct cycle offset
// ============================================================
`timescale 1ns/1ps
 
module tb_skew_chain;
 
    parameter DW = 16;
 
    reg          clk, rst_n;
    reg  [DW-1:0] in_0,in_1,in_2,in_3,in_4,in_5,in_6,in_7;
    wire [DW-1:0] out_0,out_1,out_2,out_3,out_4,out_5,out_6,out_7;
 
    integer pass_count, fail_count;
 
    skew_chain #(.DW(DW)) DUT (
        .clk(clk), .rst_n(rst_n),
        .in_0(in_0),.in_1(in_1),.in_2(in_2),.in_3(in_3),
        .in_4(in_4),.in_5(in_5),.in_6(in_6),.in_7(in_7),
        .out_0(out_0),.out_1(out_1),.out_2(out_2),.out_3(out_3),
        .out_4(out_4),.out_5(out_5),.out_6(out_6),.out_7(out_7)
    );
 
    initial clk = 0;
    always #5 clk = ~clk;
 
    task check;
        input [DW-1:0] got, exp;
        input [8*32-1:0] name;
        begin
            if (got === exp) begin
                $display("  PASS | %s | got=%h exp=%h", name, got, exp);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %s | got=%h exp=%h", name, got, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask
 
    integer k;
    reg [DW-1:0] capture [0:7];  // capture out_N at each cycle
 
    initial begin
        pass_count = 0; fail_count = 0;
        in_0=0;in_1=0;in_2=0;in_3=0;
        in_4=0;in_5=0;in_6=0;in_7=0;
        rst_n = 0;
        repeat(2) @(posedge clk); rst_n = 1;
        @(posedge clk); #1;
 
        $display("==============================================");
        $display("  Testbench: skew_chain");
        $display("==============================================");
 
        // ── Test 1: Lane 0 is a direct wire — same cycle ──
        $display("\n--- Test 1: Lane 0 zero delay ---");
        in_0 = 16'hAAAA;
        #1; // combinational — check immediately after assign
        check(out_0, 16'hAAAA, "lane0 direct wire");
        in_0 = 0;
 
        // ── Test 2: Lane 1 appears after 1 clock ──────────
        $display("\n--- Test 2: Lane 1 = 1 cycle delay ---");
        in_1 = 16'h1111;
        @(posedge clk); #1;
        in_1 = 0;
        check(out_1, 16'h1111, "lane1 after 1 cycle");
 
        // ── Test 3: Lane 2 appears after 2 clocks ─────────
        $display("\n--- Test 3: Lane 2 = 2 cycle delay ---");
        in_2 = 16'h2222;
        @(posedge clk); #1; // cycle 1
        @(posedge clk); #1; // cycle 2
        in_2 = 0;
        check(out_2, 16'h2222, "lane2 after 2 cycles");
 
        // ── Test 4: Lane 7 appears after 7 clocks ─────────
        $display("\n--- Test 4: Lane 7 = 7 cycle delay ---");
        in_7 = 16'h7777;
        repeat(7) @(posedge clk); #1;
        in_7 = 0;
        check(out_7, 16'h7777, "lane7 after 7 cycles");
 
        // ── Test 5: simultaneous pulse on all 8 lanes ─────
        // Send 0xBBBB on ALL lanes at the same moment.
        // out_0 should show it at cycle 0 (combinational).
        // out_1 at cycle 1, out_2 at cycle 2, ..., out_7 at cycle 7.
        $display("\n--- Test 5: All-lane simultaneous pulse ---");
        @(posedge clk); #1; // clean start
 
        // Drive all lanes with 0xBBBB for one cycle
        in_0=16'hBBBB; in_1=16'hBBBB; in_2=16'hBBBB; in_3=16'hBBBB;
        in_4=16'hBBBB; in_5=16'hBBBB; in_6=16'hBBBB; in_7=16'hBBBB;
        #1; // wait 1ps for combinational wire out_0 to propagate
 
        // out_0 immediately visible (combinational)
        check(out_0, 16'hBBBB, "all-pulse lane0 cycle0");
 
        // Clock once — out_1 should appear
        @(posedge clk); #1;
        in_0=0;in_1=0;in_2=0;in_3=0;in_4=0;in_5=0;in_6=0;in_7=0;
        check(out_1, 16'hBBBB, "all-pulse lane1 cycle1");
 
        // Clock again — out_2
        @(posedge clk); #1;
        check(out_2, 16'hBBBB, "all-pulse lane2 cycle2");
 
        // Clock again — out_3
        @(posedge clk); #1;
        check(out_3, 16'hBBBB, "all-pulse lane3 cycle3");
 
        // Clock again — out_4
        @(posedge clk); #1;
        check(out_4, 16'hBBBB, "all-pulse lane4 cycle4");
 
        // Clock again — out_5
        @(posedge clk); #1;
        check(out_5, 16'hBBBB, "all-pulse lane5 cycle5");
 
        // Clock again — out_6
        @(posedge clk); #1;
        check(out_6, 16'hBBBB, "all-pulse lane6 cycle6");
 
        // Clock again — out_7
        @(posedge clk); #1;
        check(out_7, 16'hBBBB, "all-pulse lane7 cycle7");
 
        // ── Summary ───────────────────────────────────────
        $display("\n==============================================");
        $display("  Results: %0d PASSED, %0d FAILED",
                  pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");
        $display("==============================================");
        $finish;
    end
 
    initial begin
        $dumpfile("tb_skew_chain.vcd");
        $dumpvars(0, tb_skew_chain);
    end
 
    initial begin #50000; $display("TIMEOUT"); $finish; end
 
endmodule