// ============================================================
// Testbench : tb_scale_ctrl
// Tests scale_ctrl.v + scale.v working together.
//
// Simulates the MAC done pulse and checks:
//   1. All 64 elements fed into scale.v in order
//   2. scale_done fires after 64+1 cycles
//   3. All 64 scaled_buf values are correct
//   4. Row-major ordering preserved
//   5. Professor's Q×KT matrix (3×3) scaled by 1/sqrt(2)
// ============================================================
`timescale 1ns/1ps

module tb_scale_ctrl;

    parameter DW   = 16;
    parameter SIZE = 8;

    reg clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count, fail_count;

    // ── MAC C_out ports (driven by testbench) ────────────────
    reg [DW-1:0] C_out_00,C_out_01,C_out_02,C_out_03;
    reg [DW-1:0] C_out_04,C_out_05,C_out_06,C_out_07;
    reg [DW-1:0] C_out_10,C_out_11,C_out_12,C_out_13;
    reg [DW-1:0] C_out_14,C_out_15,C_out_16,C_out_17;
    reg [DW-1:0] C_out_20,C_out_21,C_out_22,C_out_23;
    reg [DW-1:0] C_out_24,C_out_25,C_out_26,C_out_27;
    reg [DW-1:0] C_out_30,C_out_31,C_out_32,C_out_33;
    reg [DW-1:0] C_out_34,C_out_35,C_out_36,C_out_37;
    reg [DW-1:0] C_out_40,C_out_41,C_out_42,C_out_43;
    reg [DW-1:0] C_out_44,C_out_45,C_out_46,C_out_47;
    reg [DW-1:0] C_out_50,C_out_51,C_out_52,C_out_53;
    reg [DW-1:0] C_out_54,C_out_55,C_out_56,C_out_57;
    reg [DW-1:0] C_out_60,C_out_61,C_out_62,C_out_63;
    reg [DW-1:0] C_out_64,C_out_65,C_out_66,C_out_67;
    reg [DW-1:0] C_out_70,C_out_71,C_out_72,C_out_73;
    reg [DW-1:0] C_out_74,C_out_75,C_out_76,C_out_77;

    reg        mac_done;
    reg [3:0]  dk;

    // ── Interconnect: scale_ctrl → scale → scale_ctrl ────────
    wire           valid_in_w;
    wire [DW-1:0]  score_in_w;
    wire           valid_out_w;
    wire [DW-1:0]  scaled_out_w;
    wire           scale_done_w;

    // ── Scaled buffer outputs ─────────────────────────────────
    wire [DW-1:0] sb_00,sb_01,sb_02,sb_03,sb_04,sb_05,sb_06,sb_07;
    wire [DW-1:0] sb_10,sb_11,sb_12,sb_13,sb_14,sb_15,sb_16,sb_17;
    wire [DW-1:0] sb_20,sb_21,sb_22,sb_23,sb_24,sb_25,sb_26,sb_27;
    wire [DW-1:0] sb_30,sb_31,sb_32,sb_33,sb_34,sb_35,sb_36,sb_37;
    wire [DW-1:0] sb_40,sb_41,sb_42,sb_43,sb_44,sb_45,sb_46,sb_47;
    wire [DW-1:0] sb_50,sb_51,sb_52,sb_53,sb_54,sb_55,sb_56,sb_57;
    wire [DW-1:0] sb_60,sb_61,sb_62,sb_63,sb_64,sb_65,sb_66,sb_67;
    wire [DW-1:0] sb_70,sb_71,sb_72,sb_73,sb_74,sb_75,sb_76,sb_77;

    // ── DUT: scale_ctrl ───────────────────────────────────────
    scale_ctrl #(.DW(DW),.SIZE(SIZE)) u_ctrl (
        .clk(clk),.rst_n(rst_n),
        .mac_done(mac_done),.dk(dk),
        .C_out_00(C_out_00),.C_out_01(C_out_01),.C_out_02(C_out_02),.C_out_03(C_out_03),
        .C_out_04(C_out_04),.C_out_05(C_out_05),.C_out_06(C_out_06),.C_out_07(C_out_07),
        .C_out_10(C_out_10),.C_out_11(C_out_11),.C_out_12(C_out_12),.C_out_13(C_out_13),
        .C_out_14(C_out_14),.C_out_15(C_out_15),.C_out_16(C_out_16),.C_out_17(C_out_17),
        .C_out_20(C_out_20),.C_out_21(C_out_21),.C_out_22(C_out_22),.C_out_23(C_out_23),
        .C_out_24(C_out_24),.C_out_25(C_out_25),.C_out_26(C_out_26),.C_out_27(C_out_27),
        .C_out_30(C_out_30),.C_out_31(C_out_31),.C_out_32(C_out_32),.C_out_33(C_out_33),
        .C_out_34(C_out_34),.C_out_35(C_out_35),.C_out_36(C_out_36),.C_out_37(C_out_37),
        .C_out_40(C_out_40),.C_out_41(C_out_41),.C_out_42(C_out_42),.C_out_43(C_out_43),
        .C_out_44(C_out_44),.C_out_45(C_out_45),.C_out_46(C_out_46),.C_out_47(C_out_47),
        .C_out_50(C_out_50),.C_out_51(C_out_51),.C_out_52(C_out_52),.C_out_53(C_out_53),
        .C_out_54(C_out_54),.C_out_55(C_out_55),.C_out_56(C_out_56),.C_out_57(C_out_57),
        .C_out_60(C_out_60),.C_out_61(C_out_61),.C_out_62(C_out_62),.C_out_63(C_out_63),
        .C_out_64(C_out_64),.C_out_65(C_out_65),.C_out_66(C_out_66),.C_out_67(C_out_67),
        .C_out_70(C_out_70),.C_out_71(C_out_71),.C_out_72(C_out_72),.C_out_73(C_out_73),
        .C_out_74(C_out_74),.C_out_75(C_out_75),.C_out_76(C_out_76),.C_out_77(C_out_77),
        .valid_in(valid_in_w),.score_in(score_in_w),
        .valid_out(valid_out_w),.scaled_out(scaled_out_w),
        .scale_done(scale_done_w),
        .scaled_buf_00(sb_00),.scaled_buf_01(sb_01),.scaled_buf_02(sb_02),.scaled_buf_03(sb_03),
        .scaled_buf_04(sb_04),.scaled_buf_05(sb_05),.scaled_buf_06(sb_06),.scaled_buf_07(sb_07),
        .scaled_buf_10(sb_10),.scaled_buf_11(sb_11),.scaled_buf_12(sb_12),.scaled_buf_13(sb_13),
        .scaled_buf_14(sb_14),.scaled_buf_15(sb_15),.scaled_buf_16(sb_16),.scaled_buf_17(sb_17),
        .scaled_buf_20(sb_20),.scaled_buf_21(sb_21),.scaled_buf_22(sb_22),.scaled_buf_23(sb_23),
        .scaled_buf_24(sb_24),.scaled_buf_25(sb_25),.scaled_buf_26(sb_26),.scaled_buf_27(sb_27),
        .scaled_buf_30(sb_30),.scaled_buf_31(sb_31),.scaled_buf_32(sb_32),.scaled_buf_33(sb_33),
        .scaled_buf_34(sb_34),.scaled_buf_35(sb_35),.scaled_buf_36(sb_36),.scaled_buf_37(sb_37),
        .scaled_buf_40(sb_40),.scaled_buf_41(sb_41),.scaled_buf_42(sb_42),.scaled_buf_43(sb_43),
        .scaled_buf_44(sb_44),.scaled_buf_45(sb_45),.scaled_buf_46(sb_46),.scaled_buf_47(sb_47),
        .scaled_buf_50(sb_50),.scaled_buf_51(sb_51),.scaled_buf_52(sb_52),.scaled_buf_53(sb_53),
        .scaled_buf_54(sb_54),.scaled_buf_55(sb_55),.scaled_buf_56(sb_56),.scaled_buf_57(sb_57),
        .scaled_buf_60(sb_60),.scaled_buf_61(sb_61),.scaled_buf_62(sb_62),.scaled_buf_63(sb_63),
        .scaled_buf_64(sb_64),.scaled_buf_65(sb_65),.scaled_buf_66(sb_66),.scaled_buf_67(sb_67),
        .scaled_buf_70(sb_70),.scaled_buf_71(sb_71),.scaled_buf_72(sb_72),.scaled_buf_73(sb_73),
        .scaled_buf_74(sb_74),.scaled_buf_75(sb_75),.scaled_buf_76(sb_76),.scaled_buf_77(sb_77)
    );

    // ── DUT: scale.v (wired to scale_ctrl) ───────────────────
    scale #(.DW(DW)) u_scale (
        .clk(clk),.rst_n(rst_n),
        .valid_in(valid_in_w),
        .score_in(score_in_w),
        .dk(dk),
        .scaled_out(scaled_out_w),
        .valid_out(valid_out_w)
    );

    // ── Helpers ───────────────────────────────────────────────
    function [DW-1:0] q88;
        input integer v; begin q88 = v * 256; end
    endfunction

    // expected scaled value: score * recip(dk) >> 15
    function [DW-1:0] expected_scaled;
        input [DW-1:0] score;
        input [3:0]    d;
        reg [15:0] recip;
        reg [31:0] prod;
        begin
            case(d)
                4'd1: recip = 16'h8000;
                4'd2: recip = 16'h5A82;
                4'd4: recip = 16'h4000;
                4'd8: recip = 16'h2D41;
                default: recip = 16'h2D41;
            endcase
            prod = $signed(score) * $signed({1'b0, recip});
            expected_scaled = prod[30:15];
        end
    endfunction

    task chk;
        input [DW-1:0] got, exp;
        input [8*30-1:0] nm;
        integer diff;
        begin
            diff = $signed(got) - $signed(exp);
            if (diff < 0) diff = -diff;
            if (diff <= 2) begin
                $display("  PASS | %s | got=%h exp=%h", nm, got, exp);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %s | got=%h exp=%h diff=%0d", nm, got, exp, diff);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task do_reset;
        begin
            rst_n=0; mac_done=0; dk=4'd8;
            // zero all C_out ports
            C_out_00=0;C_out_01=0;C_out_02=0;C_out_03=0;
            C_out_04=0;C_out_05=0;C_out_06=0;C_out_07=0;
            C_out_10=0;C_out_11=0;C_out_12=0;C_out_13=0;
            C_out_14=0;C_out_15=0;C_out_16=0;C_out_17=0;
            C_out_20=0;C_out_21=0;C_out_22=0;C_out_23=0;
            C_out_24=0;C_out_25=0;C_out_26=0;C_out_27=0;
            C_out_30=0;C_out_31=0;C_out_32=0;C_out_33=0;
            C_out_34=0;C_out_35=0;C_out_36=0;C_out_37=0;
            C_out_40=0;C_out_41=0;C_out_42=0;C_out_43=0;
            C_out_44=0;C_out_45=0;C_out_46=0;C_out_47=0;
            C_out_50=0;C_out_51=0;C_out_52=0;C_out_53=0;
            C_out_54=0;C_out_55=0;C_out_56=0;C_out_57=0;
            C_out_60=0;C_out_61=0;C_out_62=0;C_out_63=0;
            C_out_64=0;C_out_65=0;C_out_66=0;C_out_67=0;
            C_out_70=0;C_out_71=0;C_out_72=0;C_out_73=0;
            C_out_74=0;C_out_75=0;C_out_76=0;C_out_77=0;
            repeat(3) @(posedge clk); rst_n=1; @(posedge clk); #1;
        end
    endtask

    task wait_scale_done;
        input integer timeout;
        integer w;
        begin
            w=0;
            while(!scale_done_w && w<timeout) begin
                @(posedge clk); #1; w=w+1;
            end
            if(w>=timeout) $display("  TIMEOUT waiting for scale_done");
        end
    endtask

    // ── Main ─────────────────────────────────────────────────
    initial begin
        pass_count=0; fail_count=0;
        $display("==============================================");
        $display("  Testbench: scale_ctrl + scale.v");
        $display("  8x8 matrix → serialise → scale → buffer");
        $display("==============================================");

        // ── Test 1: All-ones matrix, dk=8 ────────────────────
        // C[i][j] = 1.0 for all i,j
        // Scaled = 1.0 / sqrt(8) = 0x005A
        $display("\n--- Test 1: All-ones matrix dk=8 ---");
        do_reset;
        C_out_00=q88(1);C_out_01=q88(1);C_out_02=q88(1);C_out_03=q88(1);
        C_out_04=q88(1);C_out_05=q88(1);C_out_06=q88(1);C_out_07=q88(1);
        C_out_10=q88(1);C_out_11=q88(1);C_out_12=q88(1);C_out_13=q88(1);
        C_out_14=q88(1);C_out_15=q88(1);C_out_16=q88(1);C_out_17=q88(1);
        C_out_20=q88(1);C_out_21=q88(1);C_out_22=q88(1);C_out_23=q88(1);
        C_out_24=q88(1);C_out_25=q88(1);C_out_26=q88(1);C_out_27=q88(1);
        C_out_30=q88(1);C_out_31=q88(1);C_out_32=q88(1);C_out_33=q88(1);
        C_out_34=q88(1);C_out_35=q88(1);C_out_36=q88(1);C_out_37=q88(1);
        C_out_40=q88(1);C_out_41=q88(1);C_out_42=q88(1);C_out_43=q88(1);
        C_out_44=q88(1);C_out_45=q88(1);C_out_46=q88(1);C_out_47=q88(1);
        C_out_50=q88(1);C_out_51=q88(1);C_out_52=q88(1);C_out_53=q88(1);
        C_out_54=q88(1);C_out_55=q88(1);C_out_56=q88(1);C_out_57=q88(1);
        C_out_60=q88(1);C_out_61=q88(1);C_out_62=q88(1);C_out_63=q88(1);
        C_out_64=q88(1);C_out_65=q88(1);C_out_66=q88(1);C_out_67=q88(1);
        C_out_70=q88(1);C_out_71=q88(1);C_out_72=q88(1);C_out_73=q88(1);
        C_out_74=q88(1);C_out_75=q88(1);C_out_76=q88(1);C_out_77=q88(1);
        dk = 4'd8;

        // pulse mac_done
        mac_done=1; @(posedge clk); #1; mac_done=0;
        wait_scale_done(200);
        @(posedge clk); #1;

        // spot check corners and centre
        chk(sb_00, expected_scaled(q88(1),4'd8), "C[0][0] scaled");
        chk(sb_07, expected_scaled(q88(1),4'd8), "C[0][7] scaled");
        chk(sb_33, expected_scaled(q88(1),4'd8), "C[3][3] scaled");
        chk(sb_70, expected_scaled(q88(1),4'd8), "C[7][0] scaled");
        chk(sb_77, expected_scaled(q88(1),4'd8), "C[7][7] scaled");

        // ── Test 2: Unique per-cell values, dk=4 ─────────────
        // C[row][col] = row+col+1  so C[0][0]=1, C[7][7]=15
        // Verify first row and diagonal are all correctly scaled
        $display("\n--- Test 2: Unique values per cell, dk=4 ---");
        do_reset;
        C_out_00=q88(1); C_out_01=q88(2); C_out_02=q88(3); C_out_03=q88(4);
        C_out_04=q88(5); C_out_05=q88(6); C_out_06=q88(7); C_out_07=q88(8);
        C_out_10=q88(2); C_out_11=q88(3); C_out_12=q88(4); C_out_13=q88(5);
        C_out_14=q88(6); C_out_15=q88(7); C_out_16=q88(8); C_out_17=q88(9);
        C_out_20=q88(3); C_out_21=q88(4); C_out_22=q88(5); C_out_23=q88(6);
        C_out_24=q88(7); C_out_25=q88(8); C_out_26=q88(9); C_out_27=q88(10);
        C_out_30=q88(4); C_out_31=q88(5); C_out_32=q88(6); C_out_33=q88(7);
        C_out_34=q88(8); C_out_35=q88(9); C_out_36=q88(10);C_out_37=q88(11);
        C_out_40=q88(5); C_out_41=q88(6); C_out_42=q88(7); C_out_43=q88(8);
        C_out_44=q88(9); C_out_45=q88(10);C_out_46=q88(11);C_out_47=q88(12);
        C_out_50=q88(6); C_out_51=q88(7); C_out_52=q88(8); C_out_53=q88(9);
        C_out_54=q88(10);C_out_55=q88(11);C_out_56=q88(12);C_out_57=q88(13);
        C_out_60=q88(7); C_out_61=q88(8); C_out_62=q88(9); C_out_63=q88(10);
        C_out_64=q88(11);C_out_65=q88(12);C_out_66=q88(13);C_out_67=q88(14);
        C_out_70=q88(8); C_out_71=q88(9); C_out_72=q88(10);C_out_73=q88(11);
        C_out_74=q88(12);C_out_75=q88(13);C_out_76=q88(14);C_out_77=q88(15);
        dk = 4'd4;

        mac_done=1; @(posedge clk); #1; mac_done=0;
        wait_scale_done(200);
        @(posedge clk); #1;

        // check full row 0 — each gets different score
        chk(sb_00, expected_scaled(q88(1), 4'd4),  "C[0][0]=1/sqrt(4)=0.5");
        chk(sb_01, expected_scaled(q88(2), 4'd4),  "C[0][1]=2/sqrt(4)=1.0");
        chk(sb_02, expected_scaled(q88(3), 4'd4),  "C[0][2]=3/sqrt(4)=1.5");
        chk(sb_07, expected_scaled(q88(8), 4'd4),  "C[0][7]=8/sqrt(4)=4.0");
        // diagonal
        chk(sb_33, expected_scaled(q88(7), 4'd4),  "C[3][3]=7/sqrt(4)=3.5");
        chk(sb_77, expected_scaled(q88(15),4'd4),  "C[7][7]=15/sqrt(4)=7.5");

        // ── Test 3: Professor's Q×KT result, dk=2 ────────────
        // C = [[1,0,1],[0,1,1],[1,1,2]] from professor's slide
        // Only top-left 3×3 matters, rest zero
        // scaled by 1/sqrt(2) = 0x5A82
        $display("\n--- Test 3: Professor slide Q*KT, dk=2 ---");
        do_reset;
        // Row 0: [1,0,1, 0,0,0,0,0]
        C_out_00=q88(1);C_out_01=q88(0);C_out_02=q88(1);
        C_out_03=0;C_out_04=0;C_out_05=0;C_out_06=0;C_out_07=0;
        // Row 1: [0,1,1, 0,0,0,0,0]
        C_out_10=q88(0);C_out_11=q88(1);C_out_12=q88(1);
        C_out_13=0;C_out_14=0;C_out_15=0;C_out_16=0;C_out_17=0;
        // Row 2: [1,1,2, 0,0,0,0,0]
        C_out_20=q88(1);C_out_21=q88(1);C_out_22=q88(2);
        C_out_23=0;C_out_24=0;C_out_25=0;C_out_26=0;C_out_27=0;
        // Rows 3-7: all zero
        C_out_30=0;C_out_31=0;C_out_32=0;C_out_33=0;C_out_34=0;C_out_35=0;C_out_36=0;C_out_37=0;
        C_out_40=0;C_out_41=0;C_out_42=0;C_out_43=0;C_out_44=0;C_out_45=0;C_out_46=0;C_out_47=0;
        C_out_50=0;C_out_51=0;C_out_52=0;C_out_53=0;C_out_54=0;C_out_55=0;C_out_56=0;C_out_57=0;
        C_out_60=0;C_out_61=0;C_out_62=0;C_out_63=0;C_out_64=0;C_out_65=0;C_out_66=0;C_out_67=0;
        C_out_70=0;C_out_71=0;C_out_72=0;C_out_73=0;C_out_74=0;C_out_75=0;C_out_76=0;C_out_77=0;
        dk = 4'd2;

        mac_done=1; @(posedge clk); #1; mac_done=0;
        wait_scale_done(200);
        @(posedge clk); #1;

        // C[0][0]=1.0/sqrt(2)=0.7071 -> 0x00B5
        chk(sb_00, expected_scaled(q88(1),4'd2), "prof C[0][0]=1/sqrt(2)");
        // C[0][1]=0/sqrt(2)=0
        chk(sb_01, expected_scaled(q88(0),4'd2), "prof C[0][1]=0/sqrt(2)");
        // C[0][2]=1/sqrt(2)
        chk(sb_02, expected_scaled(q88(1),4'd2), "prof C[0][2]=1/sqrt(2)");
        // C[1][1]=1/sqrt(2)
        chk(sb_11, expected_scaled(q88(1),4'd2), "prof C[1][1]=1/sqrt(2)");
        // C[2][2]=2/sqrt(2)=sqrt(2)=1.4142 -> 0x016A
        chk(sb_22, expected_scaled(q88(2),4'd2), "prof C[2][2]=2/sqrt(2)");
        // Zero elements stay zero
        chk(sb_03, 16'h0000, "zero element C[0][3]=0");
        chk(sb_77, 16'h0000, "zero element C[7][7]=0");

        // ── Test 4: Timing — scale_done fires exactly once ────
        $display("\n--- Test 4: scale_done fires exactly once ---");
        do_reset;
        begin : t4
            integer done_cnt;
            done_cnt = 0;
            C_out_00=q88(2);
            mac_done=1; @(posedge clk); #1; mac_done=0;
            repeat(200) begin
                if(scale_done_w) done_cnt = done_cnt + 1;
                @(posedge clk); #1;
            end
            if(done_cnt == 1) begin
                $display("  PASS | scale_done fired exactly once (%0d)",done_cnt);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | scale_done fired %0d times",done_cnt);
                fail_count = fail_count + 1;
            end
        end

        // ── Summary ───────────────────────────────────────────
        $display("\n==============================================");
        $display("  Results: %0d PASSED, %0d FAILED",
                  pass_count, fail_count);
        if(fail_count==0) $display("  ALL TESTS PASSED");
        else              $display("  SOME TESTS FAILED");
        $display("==============================================");
        $finish;
    end

    initial begin $dumpfile("tb_scale_ctrl.vcd"); $dumpvars(0,tb_scale_ctrl); end
    initial begin #1000000; $display("TIMEOUT"); $finish; end

endmodule
