// ============================================================
// Testbench : tb_softmax
// Tests softmax.v — Q8.8 fixed-point softmax
//
// Tests:
//   1. Uniform scores [1.0 x8] -> all weights equal = 0x0020
//   2. One dominant score [4.0,0,0,0,0,0,0,0] -> w[0] >> rest
//   3. Sum of weights = 1.0 (256 in Q0.16) for all tests
//   4. done fires exactly once
//   5. Monotone: larger score -> larger weight
// ============================================================
`timescale 1ns/1ps

module tb_softmax;

    parameter DW = 16;
    parameter N  = 8;

    reg clk, rst_n, start;
    reg signed [DW-1:0] score_0,score_1,score_2,score_3;
    reg signed [DW-1:0] score_4,score_5,score_6,score_7;
    wire [DW-1:0] weight_0,weight_1,weight_2,weight_3;
    wire [DW-1:0] weight_4,weight_5,weight_6,weight_7;
    wire        done;
    wire signed [DW-1:0] row_max;
    wire [DW-1:0]        exp_sum;

    integer pass_count, fail_count;

    softmax #(.N(N),.DW(DW)) DUT (
        .clk(clk),.rst_n(rst_n),.start(start),
        .score_0(score_0),.score_1(score_1),
        .score_2(score_2),.score_3(score_3),
        .score_4(score_4),.score_5(score_5),
        .score_6(score_6),.score_7(score_7),
        .weight_0(weight_0),.weight_1(weight_1),
        .weight_2(weight_2),.weight_3(weight_3),
        .weight_4(weight_4),.weight_5(weight_5),
        .weight_6(weight_6),.weight_7(weight_7),
        .done(done),.row_max(row_max),.exp_sum(exp_sum)
    );

    initial clk=0; always #5 clk=~clk;

    function [DW-1:0] q88;
        input integer v; begin q88 = v * 256; end
    endfunction

    task do_reset;
        begin
            rst_n=0; start=0;
            score_0=0;score_1=0;score_2=0;score_3=0;
            score_4=0;score_5=0;score_6=0;score_7=0;
            repeat(3)@(posedge clk); rst_n=1; @(posedge clk); #1;
        end
    endtask

    task run_softmax;
        input integer timeout;
        integer w;
        begin
            start=1; @(posedge clk); #1; start=0;
            w=0;
            while(!done && w<timeout) begin @(posedge clk); #1; w=w+1; end
            if(w>=timeout) $display("  TIMEOUT");
            @(posedge clk); #1;
        end
    endtask

    // check weight with tolerance of 4 LSB
    task chk_weight;
        input [DW-1:0] got;
        input integer    exp_val;
        input [8*30-1:0] nm;
        integer diff;
        begin
            diff = $signed(got) - exp_val;
            if(diff < 0) diff = -diff;
            if(diff <= 4) begin
                $display("  PASS | %s | 0x%04h", nm, got);
                pass_count=pass_count+1;
            end else begin
                $display("  FAIL | %s | got=0x%04h exp=0x%04X diff=%0d",
                          nm, got, exp_val, diff);
                fail_count=fail_count+1;
            end
        end
    endtask

    task chk_sum;
        input [2*DW-1:0] w0,w1,w2,w3,w4,w5,w6,w7;
        integer s;
        begin
            s = w0+w1+w2+w3+w4+w5+w6+w7;
            // sum should be close to 256 (= 1.0 in Q0.16 at 8-bit precision)
            if(s >= 240 && s <= 272) begin
                $display("  PASS | sum_weights=%0d (expected ~256 = 1.0)", s);
                pass_count=pass_count+1;
            end else begin
                $display("  FAIL | sum_weights=%0d (expected ~256)", s);
                fail_count=fail_count+1;
            end
        end
    endtask

    initial begin
        pass_count=0; fail_count=0;
        $display("============================================");
        $display("  Testbench: softmax.v  Q8.8 fixed-point");
        $display("============================================");

        // ── Test 1: Uniform scores -> equal weights ───────────
        // All scores = 1.0, x-max = 0 for all
        // exp(0) = 1.0 = 0x0100, sum = 8*256 = 2048
        // recip = 65536/2048 = 32
        // weight = 256*32 >> 8 = 32 = 0x0020
        $display("\n--- Test 1: Uniform scores [1.0 x8] ---");
        do_reset;
        score_0=q88(1);score_1=q88(1);score_2=q88(1);score_3=q88(1);
        score_4=q88(1);score_5=q88(1);score_6=q88(1);score_7=q88(1);
        run_softmax(200);
        $display("  row_max=%h  exp_sum=%h", row_max, exp_sum);
        chk_weight(weight_0, 32, "w[0]=0x0020 (1/8)");
        chk_weight(weight_1, 32, "w[1]=0x0020 (1/8)");
        chk_weight(weight_4, 32, "w[4]=0x0020 (1/8)");
        chk_weight(weight_7, 32, "w[7]=0x0020 (1/8)");
        chk_sum(weight_0,weight_1,weight_2,weight_3,
                weight_4,weight_5,weight_6,weight_7);

        // ── Test 2: One dominant score ─────────────────────────
        // score[0]=4.0, rest=0.0
        // max=4.0, x[0]-max=0 -> exp=1.0, x[1..7]-max=-4 -> exp=0.018
        // w[0] should be ~0.886, rest ~0.016
        $display("\n--- Test 2: One dominant score [4.0, 0.0 x7] ---");
        do_reset;
        score_0=q88(4);score_1=0;score_2=0;score_3=0;
        score_4=0;     score_5=0;score_6=0;score_7=0;
        run_softmax(200);
        $display("  row_max=%h  exp_sum=%h", row_max, exp_sum);
        $display("  w[0]=0x%04h (dominant, expect ~0x00E1)", weight_0);
        $display("  w[1]=0x%04h (small,    expect ~0x0004)", weight_1);
        // check w[0] > all others
        if(weight_0 > weight_1 && weight_0 > weight_7) begin
            $display("  PASS | dominant score has largest weight");
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | dominant score should have largest weight");
            fail_count=fail_count+1;
        end
        chk_weight(weight_0, 32'hE1, "w[0]~=0x00E1 dominant");
        chk_sum(weight_0,weight_1,weight_2,weight_3,
                weight_4,weight_5,weight_6,weight_7);

        // ── Test 3: Two equal max scores ──────────────────────
        // score[0]=score[1]=2.0, rest=0.0
        // w[0]=w[1] > w[2..7]
        $display("\n--- Test 3: Two equal dominant [2.0,2.0,0,0,0,0,0,0] ---");
        do_reset;
        score_0=q88(2);score_1=q88(2);score_2=0;score_3=0;
        score_4=0;     score_5=0;     score_6=0;score_7=0;
        run_softmax(200);
        $display("  w[0]=0x%04h  w[1]=0x%04h  w[2]=0x%04h",
                  weight_0, weight_1, weight_2);
        if(weight_0 == weight_1 && weight_0 > weight_2) begin
            $display("  PASS | equal dominant scores have equal weights");
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | equal dominants should have equal weights");
            fail_count=fail_count+1;
        end
        chk_sum(weight_0,weight_1,weight_2,weight_3,
                weight_4,weight_5,weight_6,weight_7);

        // ── Test 4: Monotone property ─────────────────────────
        // Increasing scores -> increasing weights
        $display("\n--- Test 4: Monotone [0,1,2,3,4,5,6,7]/4 ---");
        do_reset;
        // step=0.5: 0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5
        // ensures no exp rounds to zero
        score_0=16'sh0000;score_1=16'sh0080;score_2=16'sh0100;score_3=16'sh0180;
        score_4=16'sh0200;score_5=16'sh0280;score_6=16'sh0300;score_7=16'sh0380;
        run_softmax(200);
        $display("  weights: %04h %04h %04h %04h %04h %04h %04h %04h",
                  weight_0,weight_1,weight_2,weight_3,
                  weight_4,weight_5,weight_6,weight_7);
        if(weight_0 < weight_1 && weight_1 < weight_2 &&
           weight_2 < weight_3 && weight_3 < weight_4 &&
           weight_4 < weight_5 && weight_5 < weight_6 &&
           weight_6 < weight_7) begin
            $display("  PASS | weights monotonically increasing");
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | weights not monotone");
            fail_count=fail_count+1;
        end
        chk_sum(weight_0,weight_1,weight_2,weight_3,
                weight_4,weight_5,weight_6,weight_7);

        // ── Test 5: done fires exactly once ───────────────────
        $display("\n--- Test 5: done fires exactly once ---");
        do_reset;
        begin : t5
            integer done_cnt;
            done_cnt=0;
            score_0=q88(1);score_1=q88(1);score_2=q88(1);score_3=q88(1);
            score_4=q88(1);score_5=q88(1);score_6=q88(1);score_7=q88(1);
            start=1; @(posedge clk); #1; start=0;
            repeat(200) begin
                if(done) done_cnt=done_cnt+1;
                @(posedge clk); #1;
            end
            if(done_cnt==1) begin
                $display("  PASS | done fired exactly once");
                pass_count=pass_count+1;
            end else begin
                $display("  FAIL | done fired %0d times", done_cnt);
                fail_count=fail_count+1;
            end
        end

        // ── Test 6: All zero scores ────────────────────────────
        // Same as uniform — all weights should be equal
        $display("\n--- Test 6: All zero scores ---");
        do_reset;
        score_0=0;score_1=0;score_2=0;score_3=0;
        score_4=0;score_5=0;score_6=0;score_7=0;
        run_softmax(200);
        chk_weight(weight_0, 32, "w[0]=1/8 for uniform zero");
        chk_sum(weight_0,weight_1,weight_2,weight_3,
                weight_4,weight_5,weight_6,weight_7);

        // Summary
        $display("\n============================================");
        $display("  Results: %0d PASSED, %0d FAILED",
                  pass_count,fail_count);
        if(fail_count==0) $display("  ALL TESTS PASSED");
        else              $display("  SOME TESTS FAILED");
        $display("============================================");
        $finish;
    end

    initial begin $dumpfile("tb_softmax.vcd"); $dumpvars(0,tb_softmax); end
    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
