// ============================================================
// Testbench: tb_attention_top
// Full system test of attention_top.v
//
// Test case: Professor's slide
//   Q = [[1,0],[0,1],[1,1]]   N=3, DK=2
//   K = [[1,0],[0,1],[1,1]]   (K=Q for this example)
//   V = [[1,0],[0,1],[1,1]]
//
// Expected output (Python fixed-point model):
//   Out[0] = [0x64, 0x4A]  = [0.391, 0.289]
//   Out[1] = [0x4A, 0x64]  = [0.289, 0.391]
//   Out[2] = [0x74, 0x74]  = [0.453, 0.453]
//
// Also tests:
//   - done fires exactly once
//   - output is stable after done
// ============================================================
`timescale 1ns/1ps
module tb_attention_top;

    parameter DW = 16;
    parameter N  = 8;

    reg clk, rst_n, start;
    reg [3:0] n_valid, dk_valid;
    initial clk=0; always #5 clk=~clk;
    integer pass_count, fail_count;

    // ── Q matrix ports ────────────────────────────────────────
    reg [DW-1:0] Q_00,Q_01,Q_02,Q_03,Q_04,Q_05,Q_06,Q_07;
    reg [DW-1:0] Q_10,Q_11,Q_12,Q_13,Q_14,Q_15,Q_16,Q_17;
    reg [DW-1:0] Q_20,Q_21,Q_22,Q_23,Q_24,Q_25,Q_26,Q_27;
    reg [DW-1:0] Q_30,Q_31,Q_32,Q_33,Q_34,Q_35,Q_36,Q_37;
    reg [DW-1:0] Q_40,Q_41,Q_42,Q_43,Q_44,Q_45,Q_46,Q_47;
    reg [DW-1:0] Q_50,Q_51,Q_52,Q_53,Q_54,Q_55,Q_56,Q_57;
    reg [DW-1:0] Q_60,Q_61,Q_62,Q_63,Q_64,Q_65,Q_66,Q_67;
    reg [DW-1:0] Q_70,Q_71,Q_72,Q_73,Q_74,Q_75,Q_76,Q_77;

    // ── K matrix ports ────────────────────────────────────────
    reg [DW-1:0] K_00,K_01,K_02,K_03,K_04,K_05,K_06,K_07;
    reg [DW-1:0] K_10,K_11,K_12,K_13,K_14,K_15,K_16,K_17;
    reg [DW-1:0] K_20,K_21,K_22,K_23,K_24,K_25,K_26,K_27;
    reg [DW-1:0] K_30,K_31,K_32,K_33,K_34,K_35,K_36,K_37;
    reg [DW-1:0] K_40,K_41,K_42,K_43,K_44,K_45,K_46,K_47;
    reg [DW-1:0] K_50,K_51,K_52,K_53,K_54,K_55,K_56,K_57;
    reg [DW-1:0] K_60,K_61,K_62,K_63,K_64,K_65,K_66,K_67;
    reg [DW-1:0] K_70,K_71,K_72,K_73,K_74,K_75,K_76,K_77;

    // ── V matrix ports ────────────────────────────────────────
    reg [DW-1:0] V_00,V_01,V_02,V_03,V_04,V_05,V_06,V_07;
    reg [DW-1:0] V_10,V_11,V_12,V_13,V_14,V_15,V_16,V_17;
    reg [DW-1:0] V_20,V_21,V_22,V_23,V_24,V_25,V_26,V_27;
    reg [DW-1:0] V_30,V_31,V_32,V_33,V_34,V_35,V_36,V_37;
    reg [DW-1:0] V_40,V_41,V_42,V_43,V_44,V_45,V_46,V_47;
    reg [DW-1:0] V_50,V_51,V_52,V_53,V_54,V_55,V_56,V_57;
    reg [DW-1:0] V_60,V_61,V_62,V_63,V_64,V_65,V_66,V_67;
    reg [DW-1:0] V_70,V_71,V_72,V_73,V_74,V_75,V_76,V_77;

    // ── Output ports ─────────────────────────────────────────
    wire [DW-1:0] out_00,out_01,out_02,out_03,out_04,out_05,out_06,out_07;
    wire [DW-1:0] out_10,out_11,out_12,out_13,out_14,out_15,out_16,out_17;
    wire [DW-1:0] out_20,out_21,out_22,out_23,out_24,out_25,out_26,out_27;
    wire [DW-1:0] out_30,out_31,out_32,out_33,out_34,out_35,out_36,out_37;
    wire [DW-1:0] out_40,out_41,out_42,out_43,out_44,out_45,out_46,out_47;
    wire [DW-1:0] out_50,out_51,out_52,out_53,out_54,out_55,out_56,out_57;
    wire [DW-1:0] out_60,out_61,out_62,out_63,out_64,out_65,out_66,out_67;
    wire [DW-1:0] out_70,out_71,out_72,out_73,out_74,out_75,out_76,out_77;
    wire done;

    // ── DUT ──────────────────────────────────────────────────
    attention_top #(.N(N),.DK(8),.DW(DW)) DUT (
        .clk(clk),.rst_n(rst_n),.start(start),
        .n_valid(n_valid),.dk_valid(dk_valid),
        .Q_00(Q_00),.Q_01(Q_01),.Q_02(Q_02),.Q_03(Q_03),
        .Q_04(Q_04),.Q_05(Q_05),.Q_06(Q_06),.Q_07(Q_07),
        .Q_10(Q_10),.Q_11(Q_11),.Q_12(Q_12),.Q_13(Q_13),
        .Q_14(Q_14),.Q_15(Q_15),.Q_16(Q_16),.Q_17(Q_17),
        .Q_20(Q_20),.Q_21(Q_21),.Q_22(Q_22),.Q_23(Q_23),
        .Q_24(Q_24),.Q_25(Q_25),.Q_26(Q_26),.Q_27(Q_27),
        .Q_30(Q_30),.Q_31(Q_31),.Q_32(Q_32),.Q_33(Q_33),
        .Q_34(Q_34),.Q_35(Q_35),.Q_36(Q_36),.Q_37(Q_37),
        .Q_40(Q_40),.Q_41(Q_41),.Q_42(Q_42),.Q_43(Q_43),
        .Q_44(Q_44),.Q_45(Q_45),.Q_46(Q_46),.Q_47(Q_47),
        .Q_50(Q_50),.Q_51(Q_51),.Q_52(Q_52),.Q_53(Q_53),
        .Q_54(Q_54),.Q_55(Q_55),.Q_56(Q_56),.Q_57(Q_57),
        .Q_60(Q_60),.Q_61(Q_61),.Q_62(Q_62),.Q_63(Q_63),
        .Q_64(Q_64),.Q_65(Q_65),.Q_66(Q_66),.Q_67(Q_67),
        .Q_70(Q_70),.Q_71(Q_71),.Q_72(Q_72),.Q_73(Q_73),
        .Q_74(Q_74),.Q_75(Q_75),.Q_76(Q_76),.Q_77(Q_77),
        .K_00(K_00),.K_01(K_01),.K_02(K_02),.K_03(K_03),
        .K_04(K_04),.K_05(K_05),.K_06(K_06),.K_07(K_07),
        .K_10(K_10),.K_11(K_11),.K_12(K_12),.K_13(K_13),
        .K_14(K_14),.K_15(K_15),.K_16(K_16),.K_17(K_17),
        .K_20(K_20),.K_21(K_21),.K_22(K_22),.K_23(K_23),
        .K_24(K_24),.K_25(K_25),.K_26(K_26),.K_27(K_27),
        .K_30(K_30),.K_31(K_31),.K_32(K_32),.K_33(K_33),
        .K_34(K_34),.K_35(K_35),.K_36(K_36),.K_37(K_37),
        .K_40(K_40),.K_41(K_41),.K_42(K_42),.K_43(K_43),
        .K_44(K_44),.K_45(K_45),.K_46(K_46),.K_47(K_47),
        .K_50(K_50),.K_51(K_51),.K_52(K_52),.K_53(K_53),
        .K_54(K_54),.K_55(K_55),.K_56(K_56),.K_57(K_57),
        .K_60(K_60),.K_61(K_61),.K_62(K_62),.K_63(K_63),
        .K_64(K_64),.K_65(K_65),.K_66(K_66),.K_67(K_67),
        .K_70(K_70),.K_71(K_71),.K_72(K_72),.K_73(K_73),
        .K_74(K_74),.K_75(K_75),.K_76(K_76),.K_77(K_77),
        .V_00(V_00),.V_01(V_01),.V_02(V_02),.V_03(V_03),
        .V_04(V_04),.V_05(V_05),.V_06(V_06),.V_07(V_07),
        .V_10(V_10),.V_11(V_11),.V_12(V_12),.V_13(V_13),
        .V_14(V_14),.V_15(V_15),.V_16(V_16),.V_17(V_17),
        .V_20(V_20),.V_21(V_21),.V_22(V_22),.V_23(V_23),
        .V_24(V_24),.V_25(V_25),.V_26(V_26),.V_27(V_27),
        .V_30(V_30),.V_31(V_31),.V_32(V_32),.V_33(V_33),
        .V_34(V_34),.V_35(V_35),.V_36(V_36),.V_37(V_37),
        .V_40(V_40),.V_41(V_41),.V_42(V_42),.V_43(V_43),
        .V_44(V_44),.V_45(V_45),.V_46(V_46),.V_47(V_47),
        .V_50(V_50),.V_51(V_51),.V_52(V_52),.V_53(V_53),
        .V_54(V_54),.V_55(V_55),.V_56(V_56),.V_57(V_57),
        .V_60(V_60),.V_61(V_61),.V_62(V_62),.V_63(V_63),
        .V_64(V_64),.V_65(V_65),.V_66(V_66),.V_67(V_67),
        .V_70(V_70),.V_71(V_71),.V_72(V_72),.V_73(V_73),
        .V_74(V_74),.V_75(V_75),.V_76(V_76),.V_77(V_77),
        .out_00(out_00),.out_01(out_01),.out_02(out_02),.out_03(out_03),
        .out_04(out_04),.out_05(out_05),.out_06(out_06),.out_07(out_07),
        .out_10(out_10),.out_11(out_11),.out_12(out_12),.out_13(out_13),
        .out_14(out_14),.out_15(out_15),.out_16(out_16),.out_17(out_17),
        .out_20(out_20),.out_21(out_21),.out_22(out_22),.out_23(out_23),
        .out_24(out_24),.out_25(out_25),.out_26(out_26),.out_27(out_27),
        .out_30(out_30),.out_31(out_31),.out_32(out_32),.out_33(out_33),
        .out_34(out_34),.out_35(out_35),.out_36(out_36),.out_37(out_37),
        .out_40(out_40),.out_41(out_41),.out_42(out_42),.out_43(out_43),
        .out_44(out_44),.out_45(out_45),.out_46(out_46),.out_47(out_47),
        .out_50(out_50),.out_51(out_51),.out_52(out_52),.out_53(out_53),
        .out_54(out_54),.out_55(out_55),.out_56(out_56),.out_57(out_57),
        .out_60(out_60),.out_61(out_61),.out_62(out_62),.out_63(out_63),
        .out_64(out_64),.out_65(out_65),.out_66(out_66),.out_67(out_67),
        .out_70(out_70),.out_71(out_71),.out_72(out_72),.out_73(out_73),
        .out_74(out_74),.out_75(out_75),.out_76(out_76),.out_77(out_77),
        .done(done)
    );

    // ── Helpers ──────────────────────────────────────────────
    function [DW-1:0] q88;
        input integer v; begin q88 = v*256; end
    endfunction

    task chk;
        input [DW-1:0] got;
        input integer   exp_v;
        input [8*30-1:0] nm;
        integer diff;
        begin
            diff = $signed(got) - exp_v;
            if (diff<0) diff=-diff;
            if (diff<=8) begin
                $display("  PASS | %s | 0x%04h (%.3f)",
                          nm, got, $itor(got)/256.0);
                pass_count=pass_count+1;
            end else begin
                $display("  FAIL | %s | got=0x%04h exp=0x%04X diff=%0d",
                          nm, got, exp_v, diff);
                fail_count=fail_count+1;
            end
        end
    endtask

    // ── Zero all matrices ────────────────────────────────────
    task zero_all;
        begin
            Q_00=0;Q_01=0;Q_02=0;Q_03=0;Q_04=0;Q_05=0;Q_06=0;Q_07=0;
            Q_10=0;Q_11=0;Q_12=0;Q_13=0;Q_14=0;Q_15=0;Q_16=0;Q_17=0;
            Q_20=0;Q_21=0;Q_22=0;Q_23=0;Q_24=0;Q_25=0;Q_26=0;Q_27=0;
            Q_30=0;Q_31=0;Q_32=0;Q_33=0;Q_34=0;Q_35=0;Q_36=0;Q_37=0;
            Q_40=0;Q_41=0;Q_42=0;Q_43=0;Q_44=0;Q_45=0;Q_46=0;Q_47=0;
            Q_50=0;Q_51=0;Q_52=0;Q_53=0;Q_54=0;Q_55=0;Q_56=0;Q_57=0;
            Q_60=0;Q_61=0;Q_62=0;Q_63=0;Q_64=0;Q_65=0;Q_66=0;Q_67=0;
            Q_70=0;Q_71=0;Q_72=0;Q_73=0;Q_74=0;Q_75=0;Q_76=0;Q_77=0;
            K_00=0;K_01=0;K_02=0;K_03=0;K_04=0;K_05=0;K_06=0;K_07=0;
            K_10=0;K_11=0;K_12=0;K_13=0;K_14=0;K_15=0;K_16=0;K_17=0;
            K_20=0;K_21=0;K_22=0;K_23=0;K_24=0;K_25=0;K_26=0;K_27=0;
            K_30=0;K_31=0;K_32=0;K_33=0;K_34=0;K_35=0;K_36=0;K_37=0;
            K_40=0;K_41=0;K_42=0;K_43=0;K_44=0;K_45=0;K_46=0;K_47=0;
            K_50=0;K_51=0;K_52=0;K_53=0;K_54=0;K_55=0;K_56=0;K_57=0;
            K_60=0;K_61=0;K_62=0;K_63=0;K_64=0;K_65=0;K_66=0;K_67=0;
            K_70=0;K_71=0;K_72=0;K_73=0;K_74=0;K_75=0;K_76=0;K_77=0;
            V_00=0;V_01=0;V_02=0;V_03=0;V_04=0;V_05=0;V_06=0;V_07=0;
            V_10=0;V_11=0;V_12=0;V_13=0;V_14=0;V_15=0;V_16=0;V_17=0;
            V_20=0;V_21=0;V_22=0;V_23=0;V_24=0;V_25=0;V_26=0;V_27=0;
            V_30=0;V_31=0;V_32=0;V_33=0;V_34=0;V_35=0;V_36=0;V_37=0;
            V_40=0;V_41=0;V_42=0;V_43=0;V_44=0;V_45=0;V_46=0;V_47=0;
            V_50=0;V_51=0;V_52=0;V_53=0;V_54=0;V_55=0;V_56=0;V_57=0;
            V_60=0;V_61=0;V_62=0;V_63=0;V_64=0;V_65=0;V_66=0;V_67=0;
            V_70=0;V_71=0;V_72=0;V_73=0;V_74=0;V_75=0;V_76=0;V_77=0;
        end
    endtask

    integer done_cnt, cycle_cnt;

    initial begin
        pass_count=0; fail_count=0;
        zero_all;
        start=0; n_valid=3; dk_valid=2;

        // CRITICAL: zero inputs before reset
        rst_n=0;
        repeat(5)@(posedge clk);
        rst_n=1;
        repeat(5)@(posedge clk); #1;

        $display("==============================================");
        $display("  Testbench: attention_top");
        $display("  Q=K=[[1,0],[0,1],[1,1]] V=[[1,0],[0,1],[1,1]]");
        $display("  N=3  DK=2");
        $display("==============================================");

        // ── Load Q, K, V ─────────────────────────────────────
        // Q[i][k]: row i, col k
        Q_00=q88(1);Q_01=q88(0);  // row 0: [1,0]
        Q_10=q88(0);Q_11=q88(1);  // row 1: [0,1]
        Q_20=q88(1);Q_21=q88(1);  // row 2: [1,1]

        // K = Q for this test
        K_00=q88(1);K_01=q88(0);
        K_10=q88(0);K_11=q88(1);
        K_20=q88(1);K_21=q88(1);

        // V[k][j]: row k, col j
        V_00=q88(1);V_01=q88(0);  // row 0: [1,0]
        V_10=q88(0);V_11=q88(1);  // row 1: [0,1]
        V_20=q88(1);V_21=q88(1);  // row 2: [1,1]

        $display("\n  Firing start...");
        start=1; @(posedge clk);#1; start=0;

        // Wait for done
        done_cnt=0; cycle_cnt=0;
        while(!done && cycle_cnt<5000) begin
            @(posedge clk);#1;
            cycle_cnt=cycle_cnt+1;
        end
        if(done) done_cnt=1;

        $display("  Done fired after %0d cycles", cycle_cnt);

        if(done_cnt==1) begin
            $display("  PASS | done fired");
            pass_count=pass_count+1;
        end else begin
            $display("  FAIL | done never fired (timeout)");
            fail_count=fail_count+1;
        end

        // ── Check output against Python hw model ──────────────
        $display("\n--- Output check (Python fixed-point reference) ---");
        $display("  Out[0] = [%04h, %04h]  expected [0x64, 0x4A]",out_00,out_01);
        $display("  Out[1] = [%04h, %04h]  expected [0x4A, 0x64]",out_10,out_11);
        $display("  Out[2] = [%04h, %04h]  expected [0x74, 0x74]",out_20,out_21);

        chk(out_00,16'h0064,"Out[0][0]=0.391");
        chk(out_01,16'h004A,"Out[0][1]=0.289");
        chk(out_10,16'h004A,"Out[1][0]=0.289");
        chk(out_11,16'h0064,"Out[1][1]=0.391");
        chk(out_20,16'h0074,"Out[2][0]=0.453");
        chk(out_21,16'h0074,"Out[2][1]=0.453");

        // ── Check done fires only once ────────────────────────
        $display("\n--- done fires exactly once ---");
        begin : once_check
            integer dc;
            dc = done_cnt;
            repeat(200) begin @(posedge clk);#1; if(done) dc=dc+1; end
            if(dc==1) begin
                $display("  PASS | done=1 exactly once");
                pass_count=pass_count+1;
            end else begin
                $display("  FAIL | done fired %0d times", dc);
                fail_count=fail_count+1;
            end
        end

        // ── Summary ──────────────────────────────────────────
        $display("\n==============================================");
        $display("  Results: %0d PASSED, %0d FAILED",
                  pass_count,fail_count);
        if(fail_count==0)
            $display("  ALL TESTS PASSED — attention_top verified ✓");
        else
            $display("  SOME TESTS FAILED");
        $display("==============================================");
        $finish;
    end

    initial begin $dumpfile("tb_top.vcd"); $dumpvars(0,tb_attention_top); end
    initial begin #100000000; $display("TIMEOUT"); $finish; end
endmodule
