`timescale 1ns/1ps
module tb_scale;
    parameter DW = 16;

    reg              clk, rst_n, valid_in;
    reg  signed [DW-1:0] score_in;
    reg  [3:0]       dk;
    wire signed [DW-1:0] scaled_out;
    wire             valid_out;
    integer pass_count, fail_count;

    scale #(.DW(DW)) DUT (
        .clk(clk),.rst_n(rst_n),.valid_in(valid_in),
        .score_in(score_in),.dk(dk),
        .scaled_out(scaled_out),.valid_out(valid_out)
    );

    initial clk=0; always #5 clk=~clk;

    function [DW-1:0] q88;
        input integer v; begin q88 = v * 256; end
    endfunction

    task chk;
        input signed [DW-1:0] got, exp;
        input [8*45-1:0] nm;
        integer diff;
        begin
            diff = $signed(got) - $signed(exp);
            if (diff < 0) diff = -diff;
            if (diff <= 2) begin
                $display("  PASS | %s | got=%h exp=%h", nm, got, exp);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %s | got=%h exp=%h diff=%0d",
                          nm, got, exp, diff);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Send one score, read result on same posedge
    task send;
        input signed [DW-1:0] score;
        input [3:0] d;
        input signed [DW-1:0] expected;
        input [8*45-1:0] nm;
        begin
            score_in=score; dk=d; valid_in=1;
            @(posedge clk); #1;
            chk(scaled_out, expected, nm);
            valid_in=0; score_in=0;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        pass_count=0; fail_count=0;
        valid_in=0; score_in=0; dk=8;
        rst_n=0; repeat(3)@(posedge clk); rst_n=1; @(posedge clk); #1;

        $display("========================================");
        $display("  scale.v — full dk=1..8 test suite");
        $display("  Q8.8 × Q1.15 >> 15 = Q8.8");
        $display("========================================");

        // ── dk=8 (main use case) ──────────────────────
        $display("\n--- dk=8  (1/sqrt(8) = 0.3536) ---");
        send(16'sh0100, 4'd8, 16'sh005A, "1.0/sqrt(8)=0.3516");
        send(16'sh0200, 4'd8, 16'sh00B5, "2.0/sqrt(8)=0.7070");
        send(16'sh0400, 4'd8, 16'sh016A, "4.0/sqrt(8)=1.4141");
        send(16'sh0800, 4'd8, 16'sh02D4, "8.0/sqrt(8)=2.8281");

        // ── dk=4 ──────────────────────────────────────
        $display("\n--- dk=4  (1/sqrt(4) = 0.5000 exact) ---");
        send(16'sh0100, 4'd4, 16'sh0080, "1.0/sqrt(4)=0.5000");
        send(16'sh0200, 4'd4, 16'sh0100, "2.0/sqrt(4)=1.0000");
        send(16'sh0400, 4'd4, 16'sh0200, "4.0/sqrt(4)=2.0000");

        // ── dk=2 ──────────────────────────────────────
        $display("\n--- dk=2  (1/sqrt(2) = 0.7071) ---");
        send(16'sh0100, 4'd2, 16'sh00B5, "1.0/sqrt(2)=0.7070");
        send(16'sh0200, 4'd2, 16'sh016A, "2.0/sqrt(2)=1.4141");

        // ── dk=1 (passthrough) ────────────────────────
        $display("\n--- dk=1  (1/sqrt(1) = 1.0 exact) ---");
        send(16'sh0100, 4'd1, 16'sh0100, "1.0/sqrt(1)=1.0000");
        send(16'sh0300, 4'd1, 16'sh0300, "3.0/sqrt(1)=3.0000");

        // ── dk=3 (NEW) ────────────────────────────────
        // 1/sqrt(3)=0.5774  Q1.15=0x49E7=18919
        // 1.0 * 18919 >> 15 = 256*18919 >> 15 = 4843264 >> 15 = 147 = 0x0093
        $display("\n--- dk=3  (1/sqrt(3) = 0.5774) ---");
        send(16'sh0100, 4'd3, 16'sh0093, "1.0/sqrt(3)=0.5742");
        // 2.0 * 0x49E7 >> 15 = 512*18919>>15 = 295 = 0x0127
        send(16'sh0200, 4'd3, 16'sh0127, "2.0/sqrt(3)=1.1484");

        // ── dk=5 (NEW) ────────────────────────────────
        // 1/sqrt(5)=0.4472  Q1.15=0x393E=14654
        // 1.0 * 14654 >> 15 = 256*14654 >> 15 = 3751424 >> 15 = 114 = 0x0072
        $display("\n--- dk=5  (1/sqrt(5) = 0.4472) ---");
        send(16'sh0100, 4'd5, 16'sh0072, "1.0/sqrt(5)=0.4453");
        send(16'sh0200, 4'd5, 16'sh00E4, "2.0/sqrt(5)=0.8906");

        // ── dk=6 (NEW) ────────────────────────────────
        // 1/sqrt(6)=0.4082  Q1.15=0x3441=13377
        // 1.0 * 13377 >> 15 = 256*13377 >> 15 = 3424512 >> 15 = 104 = 0x0068
        $display("\n--- dk=6  (1/sqrt(6) = 0.4082) ---");
        send(16'sh0100, 4'd6, 16'sh0068, "1.0/sqrt(6)=0.4062");
        send(16'sh0200, 4'd6, 16'sh00D0, "2.0/sqrt(6)=0.8125");

        // ── dk=7 (NEW) ────────────────────────────────
        // 1/sqrt(7)=0.3780  Q1.15=0x3061=12385
        // 1.0 * 12385 >> 15 = 256*12385 >> 15 = 3170560 >> 15 = 96 = 0x0060
        $display("\n--- dk=7  (1/sqrt(7) = 0.3780) ---");
        send(16'sh0100, 4'd7, 16'sh0060, "1.0/sqrt(7)=0.3750");
        send(16'sh0200, 4'd7, 16'sh00C0, "2.0/sqrt(7)=0.7500");

        // ── Special cases ─────────────────────────────
        $display("\n--- Special cases ---");
        send(16'sh0000, 4'd8, 16'sh0000, "0.0/sqrt(8)=0.0000");
        send(16'shFF00, 4'd8, 16'shFFA5, "-1.0/sqrt(8) signed");
        send(16'shFE00, 4'd8, 16'shFF4A, "-2.0/sqrt(8) signed");

        // ── valid_out timing ──────────────────────────
        $display("\n--- Pipeline: valid_out=0 when no valid_in ---");
        valid_in=0; score_in=0; dk=4'd8;
        @(posedge clk);#1; @(posedge clk);#1;
        if(!valid_out) begin
            $display("  PASS | valid_out=0 when idle");
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | valid_out should be 0");
            fail_count=fail_count+1;
        end

        // ── Back-to-back stream ───────────────────────
        $display("\n--- Back-to-back stream dk=8 ---");
        dk=4'd8; valid_in=1;
        score_in=16'sh0100; @(posedge clk);#1;
        chk(scaled_out,16'sh005A,"stream 1.0/sqrt(8)");
        score_in=16'sh0200; @(posedge clk);#1;
        chk(scaled_out,16'sh00B5,"stream 2.0/sqrt(8)");
        score_in=16'sh0400; @(posedge clk);#1;
        chk(scaled_out,16'sh016A,"stream 4.0/sqrt(8)");
        score_in=16'sh0800; @(posedge clk);#1;
        chk(scaled_out,16'sh02D4,"stream 8.0/sqrt(8)");
        valid_in=0; score_in=0; @(posedge clk);#1;

        // ── Professor slide values ─────────────────────
        $display("\n--- Professor Q*KT scores scaled by 1/sqrt(2) ---");
        send(16'sh0100, 4'd2, 16'sh00B5, "score=1 dk=2 -> 0.7070");
        send(16'sh0000, 4'd2, 16'sh0000, "score=0 dk=2 -> 0.0000");
        send(16'sh0200, 4'd2, 16'sh016A, "score=2 dk=2 -> 1.4141");

        $display("\n========================================");
        $display("  Results: %0d PASSED, %0d FAILED",
                  pass_count,fail_count);
        if(fail_count==0) $display("  ALL TESTS PASSED");
        else              $display("  SOME TESTS FAILED");
        $display("========================================");
        $finish;
    end

    initial begin $dumpfile("tb_scale.vcd"); $dumpvars(0,tb_scale); end
    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
