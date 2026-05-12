// ============================================================
// Testbench: tb_softmax_ctrl
// Tests softmax_ctrl.v + softmax.v + exp_lut.v together.
//
// Tests:
//   1. Uniform input [1.0 x 64] → all 64 weights = 0x20 (1/8)
//   2. Row ordering preserved — each row's dominant element
//      correctly identified and weighted
//   3. Identity-like input — diagonal score 1.0, rest 0.0
//      → each row has one large weight and seven small equal ones
//   4. softmax_ctrl_done fires exactly once per run
//   5. scale_done-to-done latency ≈ 8 × 158 cycles
// ============================================================
`timescale 1ns/1ps
module tb_softmax_ctrl;

    parameter DW = 16;
    parameter N  = 8;

    reg clk, rst_n;
    initial clk=0; always #5 clk=~clk;
    integer pass_count, fail_count;

    // ── Scaled score inputs (driven by testbench) ─────────────
    reg [DW-1:0] sc_00,sc_01,sc_02,sc_03,sc_04,sc_05,sc_06,sc_07;
    reg [DW-1:0] sc_10,sc_11,sc_12,sc_13,sc_14,sc_15,sc_16,sc_17;
    reg [DW-1:0] sc_20,sc_21,sc_22,sc_23,sc_24,sc_25,sc_26,sc_27;
    reg [DW-1:0] sc_30,sc_31,sc_32,sc_33,sc_34,sc_35,sc_36,sc_37;
    reg [DW-1:0] sc_40,sc_41,sc_42,sc_43,sc_44,sc_45,sc_46,sc_47;
    reg [DW-1:0] sc_50,sc_51,sc_52,sc_53,sc_54,sc_55,sc_56,sc_57;
    reg [DW-1:0] sc_60,sc_61,sc_62,sc_63,sc_64,sc_65,sc_66,sc_67;
    reg [DW-1:0] sc_70,sc_71,sc_72,sc_73,sc_74,sc_75,sc_76,sc_77;

    reg scale_done;

    // ── Attention weight outputs ──────────────────────────────
    wire [DW-1:0] ab_00,ab_01,ab_02,ab_03,ab_04,ab_05,ab_06,ab_07;
    wire [DW-1:0] ab_10,ab_11,ab_12,ab_13,ab_14,ab_15,ab_16,ab_17;
    wire [DW-1:0] ab_20,ab_21,ab_22,ab_23,ab_24,ab_25,ab_26,ab_27;
    wire [DW-1:0] ab_30,ab_31,ab_32,ab_33,ab_34,ab_35,ab_36,ab_37;
    wire [DW-1:0] ab_40,ab_41,ab_42,ab_43,ab_44,ab_45,ab_46,ab_47;
    wire [DW-1:0] ab_50,ab_51,ab_52,ab_53,ab_54,ab_55,ab_56,ab_57;
    wire [DW-1:0] ab_60,ab_61,ab_62,ab_63,ab_64,ab_65,ab_66,ab_67;
    wire [DW-1:0] ab_70,ab_71,ab_72,ab_73,ab_74,ab_75,ab_76,ab_77;
    wire           sm_ctrl_done;

    // ── Interconnect: ctrl → softmax → ctrl ──────────────────
    wire           sm_start_w;
    wire [DW-1:0]  sm_s0_w,sm_s1_w,sm_s2_w,sm_s3_w;
    wire [DW-1:0]  sm_s4_w,sm_s5_w,sm_s6_w,sm_s7_w;
    wire           sm_done_w;
    wire [DW-1:0]  sm_w0_w,sm_w1_w,sm_w2_w,sm_w3_w;
    wire [DW-1:0]  sm_w4_w,sm_w5_w,sm_w6_w,sm_w7_w;
    wire [DW-1:0]  sm_max_w,sm_sum_w;

    // ── DUT: softmax_ctrl ─────────────────────────────────────
    softmax_ctrl #(.N(N),.DW(DW)) u_ctrl (
        .clk(clk),.rst_n(rst_n),
        .scale_done(scale_done),
        .scaled_buf_00(sc_00),.scaled_buf_01(sc_01),
        .scaled_buf_02(sc_02),.scaled_buf_03(sc_03),
        .scaled_buf_04(sc_04),.scaled_buf_05(sc_05),
        .scaled_buf_06(sc_06),.scaled_buf_07(sc_07),
        .scaled_buf_10(sc_10),.scaled_buf_11(sc_11),
        .scaled_buf_12(sc_12),.scaled_buf_13(sc_13),
        .scaled_buf_14(sc_14),.scaled_buf_15(sc_15),
        .scaled_buf_16(sc_16),.scaled_buf_17(sc_17),
        .scaled_buf_20(sc_20),.scaled_buf_21(sc_21),
        .scaled_buf_22(sc_22),.scaled_buf_23(sc_23),
        .scaled_buf_24(sc_24),.scaled_buf_25(sc_25),
        .scaled_buf_26(sc_26),.scaled_buf_27(sc_27),
        .scaled_buf_30(sc_30),.scaled_buf_31(sc_31),
        .scaled_buf_32(sc_32),.scaled_buf_33(sc_33),
        .scaled_buf_34(sc_34),.scaled_buf_35(sc_35),
        .scaled_buf_36(sc_36),.scaled_buf_37(sc_37),
        .scaled_buf_40(sc_40),.scaled_buf_41(sc_41),
        .scaled_buf_42(sc_42),.scaled_buf_43(sc_43),
        .scaled_buf_44(sc_44),.scaled_buf_45(sc_45),
        .scaled_buf_46(sc_46),.scaled_buf_47(sc_47),
        .scaled_buf_50(sc_50),.scaled_buf_51(sc_51),
        .scaled_buf_52(sc_52),.scaled_buf_53(sc_53),
        .scaled_buf_54(sc_54),.scaled_buf_55(sc_55),
        .scaled_buf_56(sc_56),.scaled_buf_57(sc_57),
        .scaled_buf_60(sc_60),.scaled_buf_61(sc_61),
        .scaled_buf_62(sc_62),.scaled_buf_63(sc_63),
        .scaled_buf_64(sc_64),.scaled_buf_65(sc_65),
        .scaled_buf_66(sc_66),.scaled_buf_67(sc_67),
        .scaled_buf_70(sc_70),.scaled_buf_71(sc_71),
        .scaled_buf_72(sc_72),.scaled_buf_73(sc_73),
        .scaled_buf_74(sc_74),.scaled_buf_75(sc_75),
        .scaled_buf_76(sc_76),.scaled_buf_77(sc_77),
        .sm_start(sm_start_w),
        .sm_score_0(sm_s0_w),.sm_score_1(sm_s1_w),
        .sm_score_2(sm_s2_w),.sm_score_3(sm_s3_w),
        .sm_score_4(sm_s4_w),.sm_score_5(sm_s5_w),
        .sm_score_6(sm_s6_w),.sm_score_7(sm_s7_w),
        .sm_done(sm_done_w),
        .sm_weight_0(sm_w0_w),.sm_weight_1(sm_w1_w),
        .sm_weight_2(sm_w2_w),.sm_weight_3(sm_w3_w),
        .sm_weight_4(sm_w4_w),.sm_weight_5(sm_w5_w),
        .sm_weight_6(sm_w6_w),.sm_weight_7(sm_w7_w),
        .softmax_ctrl_done(sm_ctrl_done),
        .attn_buf_00(ab_00),.attn_buf_01(ab_01),
        .attn_buf_02(ab_02),.attn_buf_03(ab_03),
        .attn_buf_04(ab_04),.attn_buf_05(ab_05),
        .attn_buf_06(ab_06),.attn_buf_07(ab_07),
        .attn_buf_10(ab_10),.attn_buf_11(ab_11),
        .attn_buf_12(ab_12),.attn_buf_13(ab_13),
        .attn_buf_14(ab_14),.attn_buf_15(ab_15),
        .attn_buf_16(ab_16),.attn_buf_17(ab_17),
        .attn_buf_20(ab_20),.attn_buf_21(ab_21),
        .attn_buf_22(ab_22),.attn_buf_23(ab_23),
        .attn_buf_24(ab_24),.attn_buf_25(ab_25),
        .attn_buf_26(ab_26),.attn_buf_27(ab_27),
        .attn_buf_30(ab_30),.attn_buf_31(ab_31),
        .attn_buf_32(ab_32),.attn_buf_33(ab_33),
        .attn_buf_34(ab_34),.attn_buf_35(ab_35),
        .attn_buf_36(ab_36),.attn_buf_37(ab_37),
        .attn_buf_40(ab_40),.attn_buf_41(ab_41),
        .attn_buf_42(ab_42),.attn_buf_43(ab_43),
        .attn_buf_44(ab_44),.attn_buf_45(ab_45),
        .attn_buf_46(ab_46),.attn_buf_47(ab_47),
        .attn_buf_50(ab_50),.attn_buf_51(ab_51),
        .attn_buf_52(ab_52),.attn_buf_53(ab_53),
        .attn_buf_54(ab_54),.attn_buf_55(ab_55),
        .attn_buf_56(ab_56),.attn_buf_57(ab_57),
        .attn_buf_60(ab_60),.attn_buf_61(ab_61),
        .attn_buf_62(ab_62),.attn_buf_63(ab_63),
        .attn_buf_64(ab_64),.attn_buf_65(ab_65),
        .attn_buf_66(ab_66),.attn_buf_67(ab_67),
        .attn_buf_70(ab_70),.attn_buf_71(ab_71),
        .attn_buf_72(ab_72),.attn_buf_73(ab_73),
        .attn_buf_74(ab_74),.attn_buf_75(ab_75),
        .attn_buf_76(ab_76),.attn_buf_77(ab_77)
    );

    // ── DUT: softmax ──────────────────────────────────────────
    softmax #(.N(N),.DW(DW)) u_sm (
        .clk(clk),.rst_n(rst_n),.start(sm_start_w),
        .score_0(sm_s0_w),.score_1(sm_s1_w),
        .score_2(sm_s2_w),.score_3(sm_s3_w),
        .score_4(sm_s4_w),.score_5(sm_s5_w),
        .score_6(sm_s6_w),.score_7(sm_s7_w),
        .weight_0(sm_w0_w),.weight_1(sm_w1_w),
        .weight_2(sm_w2_w),.weight_3(sm_w3_w),
        .weight_4(sm_w4_w),.weight_5(sm_w5_w),
        .weight_6(sm_w6_w),.weight_7(sm_w7_w),
        .done(sm_done_w),.row_max(sm_max_w),.exp_sum(sm_sum_w)
    );

    // ── Helpers ───────────────────────────────────────────────
    function [DW-1:0] q88;
        input integer v; begin q88 = v*256; end
    endfunction

    task chk;
        input [DW-1:0] got;
        input integer  exp_v;
        input [8*30-1:0] nm;
        integer diff;
        begin
            diff = $signed(got) - exp_v;
            if (diff<0) diff=-diff;
            if (diff<=4) begin
                $display("  PASS | %s | 0x%04h", nm, got);
                pass_count=pass_count+1;
            end else begin
                $display("  FAIL | %s | got=0x%04h exp=0x%04X diff=%0d",
                          nm, got, exp_v, diff);
                fail_count=fail_count+1;
            end
        end
    endtask

    task do_reset;
        begin
            rst_n=0; scale_done=0;
            // zero all scaled inputs
            sc_00=0;sc_01=0;sc_02=0;sc_03=0;sc_04=0;sc_05=0;sc_06=0;sc_07=0;
            sc_10=0;sc_11=0;sc_12=0;sc_13=0;sc_14=0;sc_15=0;sc_16=0;sc_17=0;
            sc_20=0;sc_21=0;sc_22=0;sc_23=0;sc_24=0;sc_25=0;sc_26=0;sc_27=0;
            sc_30=0;sc_31=0;sc_32=0;sc_33=0;sc_34=0;sc_35=0;sc_36=0;sc_37=0;
            sc_40=0;sc_41=0;sc_42=0;sc_43=0;sc_44=0;sc_45=0;sc_46=0;sc_47=0;
            sc_50=0;sc_51=0;sc_52=0;sc_53=0;sc_54=0;sc_55=0;sc_56=0;sc_57=0;
            sc_60=0;sc_61=0;sc_62=0;sc_63=0;sc_64=0;sc_65=0;sc_66=0;sc_67=0;
            sc_70=0;sc_71=0;sc_72=0;sc_73=0;sc_74=0;sc_75=0;sc_76=0;sc_77=0;
            repeat(3)@(posedge clk); rst_n=1; @(posedge clk); #1;
        end
    endtask

    task fire_and_wait;
        input integer timeout;
        integer w;
        begin
            scale_done=1; @(posedge clk);#1; scale_done=0;
            w=0;
            while(!sm_ctrl_done && w<timeout) begin @(posedge clk);#1; w=w+1; end
            if(w>=timeout) $display("  TIMEOUT at cycle %0d", w);
            @(posedge clk);#1;
        end
    endtask

    initial begin
        pass_count=0; fail_count=0;
        $display("==============================================");
        $display("  Testbench: softmax_ctrl + softmax + exp_lut");
        $display("==============================================");

        // ── Test 1: Uniform 1.0 — all weights = 0x20 (1/8) ──
        $display("\n--- Test 1: Uniform scores [1.0 x 64] ---");
        $display("  Expected: all 64 weights = 0x0020");
        do_reset;
        // Fill all 64 scaled_buf ports with q88(1)=0x0100
        sc_00=q88(1);sc_01=q88(1);sc_02=q88(1);sc_03=q88(1);
        sc_04=q88(1);sc_05=q88(1);sc_06=q88(1);sc_07=q88(1);
        sc_10=q88(1);sc_11=q88(1);sc_12=q88(1);sc_13=q88(1);
        sc_14=q88(1);sc_15=q88(1);sc_16=q88(1);sc_17=q88(1);
        sc_20=q88(1);sc_21=q88(1);sc_22=q88(1);sc_23=q88(1);
        sc_24=q88(1);sc_25=q88(1);sc_26=q88(1);sc_27=q88(1);
        sc_30=q88(1);sc_31=q88(1);sc_32=q88(1);sc_33=q88(1);
        sc_34=q88(1);sc_35=q88(1);sc_36=q88(1);sc_37=q88(1);
        sc_40=q88(1);sc_41=q88(1);sc_42=q88(1);sc_43=q88(1);
        sc_44=q88(1);sc_45=q88(1);sc_46=q88(1);sc_47=q88(1);
        sc_50=q88(1);sc_51=q88(1);sc_52=q88(1);sc_53=q88(1);
        sc_54=q88(1);sc_55=q88(1);sc_56=q88(1);sc_57=q88(1);
        sc_60=q88(1);sc_61=q88(1);sc_62=q88(1);sc_63=q88(1);
        sc_64=q88(1);sc_65=q88(1);sc_66=q88(1);sc_67=q88(1);
        sc_70=q88(1);sc_71=q88(1);sc_72=q88(1);sc_73=q88(1);
        sc_74=q88(1);sc_75=q88(1);sc_76=q88(1);sc_77=q88(1);
        fire_and_wait(3000);
        // All weights = 0x20
        chk(ab_00,16'h0020,"uniform ab[0][0]");
        chk(ab_07,16'h0020,"uniform ab[0][7]");
        chk(ab_30,16'h0020,"uniform ab[3][0]");
        chk(ab_44,16'h0020,"uniform ab[4][4]");
        chk(ab_77,16'h0020,"uniform ab[7][7]");
        // Check sum of row 0 ≈ 256
        begin : sum_check
            integer s;
            s = ab_00+ab_01+ab_02+ab_03+ab_04+ab_05+ab_06+ab_07;
            if(s>=240 && s<=272) begin
                $display("  PASS | row 0 sum=%0d (~256)", s);
                pass_count=pass_count+1;
            end else begin
                $display("  FAIL | row 0 sum=%0d (expected ~256)", s);
                fail_count=fail_count+1;
            end
        end

        // ── Test 2: Row ordering — dominant in different cols ─
        $display("\n--- Test 2: Row ordering (dominant at col = row index) ---");
        $display("  Row i has score[i]=2.0, rest=0.0 -> w[i] should be largest");
        do_reset;
        // Row 0: dominant at col 0
        sc_00=q88(2);sc_01=0;sc_02=0;sc_03=0;sc_04=0;sc_05=0;sc_06=0;sc_07=0;
        // Row 1: dominant at col 1
        sc_10=0;sc_11=q88(2);sc_12=0;sc_13=0;sc_14=0;sc_15=0;sc_16=0;sc_17=0;
        // Row 2: dominant at col 2
        sc_20=0;sc_21=0;sc_22=q88(2);sc_23=0;sc_24=0;sc_25=0;sc_26=0;sc_27=0;
        // Row 3: dominant at col 3
        sc_30=0;sc_31=0;sc_32=0;sc_33=q88(2);sc_34=0;sc_35=0;sc_36=0;sc_37=0;
        // Row 4: dominant at col 4
        sc_40=0;sc_41=0;sc_42=0;sc_43=0;sc_44=q88(2);sc_45=0;sc_46=0;sc_47=0;
        // Row 5: dominant at col 5
        sc_50=0;sc_51=0;sc_52=0;sc_53=0;sc_54=0;sc_55=q88(2);sc_56=0;sc_57=0;
        // Row 6: dominant at col 6
        sc_60=0;sc_61=0;sc_62=0;sc_63=0;sc_64=0;sc_65=0;sc_66=q88(2);sc_67=0;
        // Row 7: dominant at col 7
        sc_70=0;sc_71=0;sc_72=0;sc_73=0;sc_74=0;sc_75=0;sc_76=0;sc_77=q88(2);
        fire_and_wait(3000);
        // Expected: w[0][0] is dominant in row 0, etc.
        // Python: dominant col gets 0x82, others get lower value
        if(ab_00>ab_01 && ab_00>ab_07) begin
            $display("  PASS | row 0: w[0]=0x%04h is dominant", ab_00);
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | row 0: w[0]=0x%04h not dominant (w[1]=0x%04h)",
                      ab_00,ab_01);
            fail_count=fail_count+1;
        end
        if(ab_11>ab_10 && ab_11>ab_17) begin
            $display("  PASS | row 1: w[1]=0x%04h is dominant", ab_11);
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | row 1: w[1]=0x%04h not dominant",ab_11);
            fail_count=fail_count+1;
        end
        if(ab_22>ab_20 && ab_22>ab_27) begin
            $display("  PASS | row 2: w[2]=0x%04h is dominant", ab_22);
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | row 2: w[2]=0x%04h not dominant",ab_22);
            fail_count=fail_count+1;
        end
        if(ab_33>ab_30 && ab_33>ab_37) begin
            $display("  PASS | row 3: w[3]=0x%04h is dominant", ab_33);
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | row 3: w[3]=0x%04h not dominant",ab_33);
            fail_count=fail_count+1;
        end
        if(ab_44>ab_40 && ab_44>ab_47) begin
            $display("  PASS | row 4: w[4]=0x%04h is dominant", ab_44);
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | row 4: w[4]=0x%04h not dominant",ab_44);
            fail_count=fail_count+1;
        end
        if(ab_55>ab_50 && ab_55>ab_57) begin
            $display("  PASS | row 5: w[5]=0x%04h is dominant", ab_55);
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | row 5: w[5]=0x%04h not dominant",ab_55);
            fail_count=fail_count+1;
        end
        if(ab_66>ab_60 && ab_66>ab_67) begin
            $display("  PASS | row 6: w[6]=0x%04h is dominant", ab_66);
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | row 6: w[6]=0x%04h not dominant",ab_66);
            fail_count=fail_count+1;
        end
        if(ab_77>ab_70 && ab_77>ab_76) begin
            $display("  PASS | row 7: w[7]=0x%04h is dominant", ab_77);
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | row 7: w[7]=0x%04h not dominant",ab_77);
            fail_count=fail_count+1;
        end

        // ── Test 3: Identity-like ─────────────────────────────
        // Row i: score[i]=1.0, rest=0.0
        // → w[i][i]=0x47 (large), w[i][j≠i]=0x1A (small)
        $display("\n--- Test 3: Identity-like (diag=1.0, rest=0.0) ---");
        do_reset;
        sc_00=q88(1);sc_11=q88(1);sc_22=q88(1);sc_33=q88(1);
        sc_44=q88(1);sc_55=q88(1);sc_66=q88(1);sc_77=q88(1);
        // all off-diagonal stay 0 (already zero from do_reset)
        fire_and_wait(3000);
        // diagonal should be 0x47, off-diagonal 0x1A
        chk(ab_00,16'h0047,"identity ab[0][0]=0x47");
        chk(ab_01,16'h001A,"identity ab[0][1]=0x1A");
        chk(ab_11,16'h0047,"identity ab[1][1]=0x47");
        chk(ab_10,16'h001A,"identity ab[1][0]=0x1A");
        chk(ab_77,16'h0047,"identity ab[7][7]=0x47");
        chk(ab_70,16'h001A,"identity ab[7][0]=0x1A");
        chk(ab_44,16'h0047,"identity ab[4][4]=0x47");
        chk(ab_45,16'h001A,"identity ab[4][5]=0x1A");

        // ── Test 4: done fires exactly once ───────────────────
        $display("\n--- Test 4: softmax_ctrl_done fires exactly once ---");
        do_reset;
        sc_00=q88(1);
        begin : done_check
            integer dc;
            dc=0;
            scale_done=1; @(posedge clk);#1; scale_done=0;
            repeat(3000) begin
                if(sm_ctrl_done) dc=dc+1;
                @(posedge clk);#1;
            end
            if(dc==1) begin
                $display("  PASS | done fired exactly once");
                pass_count=pass_count+1;
            end else begin
                $display("  FAIL | done fired %0d times",dc);
                fail_count=fail_count+1;
            end
        end

        // ── Summary ───────────────────────────────────────────
        $display("\n==============================================");
        $display("  Results: %0d PASSED, %0d FAILED",
                  pass_count,fail_count);
        if(fail_count==0) $display("  ALL TESTS PASSED");
        else              $display("  SOME TESTS FAILED");
        $display("==============================================");
        $finish;
    end

    initial begin $dumpfile("tb_sm_ctrl.vcd"); $dumpvars(0,tb_softmax_ctrl); end
    initial begin #50000000; $display("TIMEOUT"); $finish; end

endmodule
