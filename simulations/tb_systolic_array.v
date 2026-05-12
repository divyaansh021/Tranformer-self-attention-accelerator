`timescale 1ns/1ps
module tb_systolic_array;
    parameter DW=16; parameter SIZE=8;
    reg clk,rst_n,start;
    reg [3:0] n_valid,dk_valid;
    reg  [DW-1:0] A_in_0,A_in_1,A_in_2,A_in_3,A_in_4,A_in_5,A_in_6,A_in_7;
    reg  [DW-1:0] B_in_0,B_in_1,B_in_2,B_in_3,B_in_4,B_in_5,B_in_6,B_in_7;
    wire [DW-1:0] C_out_00,C_out_01,C_out_02,C_out_03,C_out_04,C_out_05,C_out_06,C_out_07;
    wire [DW-1:0] C_out_10,C_out_11,C_out_12,C_out_13,C_out_14,C_out_15,C_out_16,C_out_17;
    wire [DW-1:0] C_out_20,C_out_21,C_out_22,C_out_23,C_out_24,C_out_25,C_out_26,C_out_27;
    wire [DW-1:0] C_out_30,C_out_31,C_out_32,C_out_33,C_out_34,C_out_35,C_out_36,C_out_37;
    wire [DW-1:0] C_out_40,C_out_41,C_out_42,C_out_43,C_out_44,C_out_45,C_out_46,C_out_47;
    wire [DW-1:0] C_out_50,C_out_51,C_out_52,C_out_53,C_out_54,C_out_55,C_out_56,C_out_57;
    wire [DW-1:0] C_out_60,C_out_61,C_out_62,C_out_63,C_out_64,C_out_65,C_out_66,C_out_67;
    wire [DW-1:0] C_out_70,C_out_71,C_out_72,C_out_73,C_out_74,C_out_75,C_out_76,C_out_77;
    wire done,running; wire [31:0] skip_count;
    integer pass_count,fail_count;

    systolic_array #(.SIZE(SIZE),.DW(DW)) DUT (
        .clk(clk),.rst_n(rst_n),.start(start),
        .n_valid(n_valid),.dk_valid(dk_valid),
        .A_in_0(A_in_0),.A_in_1(A_in_1),.A_in_2(A_in_2),.A_in_3(A_in_3),
        .A_in_4(A_in_4),.A_in_5(A_in_5),.A_in_6(A_in_6),.A_in_7(A_in_7),
        .B_in_0(B_in_0),.B_in_1(B_in_1),.B_in_2(B_in_2),.B_in_3(B_in_3),
        .B_in_4(B_in_4),.B_in_5(B_in_5),.B_in_6(B_in_6),.B_in_7(B_in_7),
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
        .done(done),.running(running),.skip_count(skip_count)
    );

    initial clk=0; always #5 clk=~clk;

    task chk;
        input [DW-1:0] got,exp; input [8*30-1:0] nm;
        begin
            if(got===exp) begin $display("  PASS | %s | %h",nm,got); pass_count=pass_count+1; end
            else          begin $display("  FAIL | %s | got=%h exp=%h",nm,got,exp); fail_count=fail_count+1; end
        end
    endtask

    task clr_in;
        begin
            A_in_0=0;A_in_1=0;A_in_2=0;A_in_3=0;A_in_4=0;A_in_5=0;A_in_6=0;A_in_7=0;
            B_in_0=0;B_in_1=0;B_in_2=0;B_in_3=0;B_in_4=0;B_in_5=0;B_in_6=0;B_in_7=0;
        end
    endtask

    task do_reset;
        begin rst_n=0;start=0;clr_in; repeat(3)@(posedge clk); rst_n=1;@(posedge clk);#1; end
    endtask

    task wait_done;
        input integer t; integer w;
        begin w=0; while(!done&&w<t) begin @(posedge clk);#1;w=w+1; end
              if(w>=t) $display("  TIMEOUT after %0d cycles",t); end
    endtask

    reg [DW-1:0] A3[0:2][0:2]; reg [DW-1:0] B3[0:2][0:2];
    reg [DW-1:0] A8[0:7][0:7]; reg [DW-1:0] B8[0:7][0:7];

    // ─────────────────────────────────────────────────────
    // Timing: start -> CLEAR (acc_clr=1, combinational)
    //         posedge after start: state=CLEAR, acc_clr=1
    //         posedge after that: state=RUN, acc_clr=0
    //         We begin feeding data on the FIRST RUN posedge.
    //         After done fires, C_out is valid immediately
    //         (combinational from accumulators).
    // ─────────────────────────────────────────────────────
    task feed_3x3;
        input integer n_sz,dk_sz; integer kk;
        begin
            n_valid=n_sz; dk_valid=dk_sz;
            // pulse start
            start=1; @(posedge clk);#1; start=0;
            // wait through CLEAR state (1 cycle)
            @(posedge clk);#1;
            // feed DK data cycles into RUN state
            for(kk=0;kk<dk_sz;kk=kk+1) begin
                A_in_0=(0<n_sz)?A3[0][kk]:0; A_in_1=(1<n_sz)?A3[1][kk]:0;
                A_in_2=(2<n_sz)?A3[2][kk]:0;
                A_in_3=0;A_in_4=0;A_in_5=0;A_in_6=0;A_in_7=0;
                B_in_0=(0<n_sz)?B3[kk][0]:0; B_in_1=(1<n_sz)?B3[kk][1]:0;
                B_in_2=(2<n_sz)?B3[kk][2]:0;
                B_in_3=0;B_in_4=0;B_in_5=0;B_in_6=0;B_in_7=0;
                @(posedge clk);#1;
            end
            clr_in;
            // controller handles rest of pipeline drain — wait for done
            wait_done(200);
        end
    endtask

    task feed_8x8;
        integer kk;
        begin
            n_valid=8; dk_valid=8;
            start=1; @(posedge clk);#1; start=0;
            @(posedge clk);#1; // wait through CLEAR
            for(kk=0;kk<8;kk=kk+1) begin
                A_in_0=A8[0][kk];A_in_1=A8[1][kk];A_in_2=A8[2][kk];A_in_3=A8[3][kk];
                A_in_4=A8[4][kk];A_in_5=A8[5][kk];A_in_6=A8[6][kk];A_in_7=A8[7][kk];
                B_in_0=B8[kk][0];B_in_1=B8[kk][1];B_in_2=B8[kk][2];B_in_3=B8[kk][3];
                B_in_4=B8[kk][4];B_in_5=B8[kk][5];B_in_6=B8[kk][6];B_in_7=B8[kk][7];
                @(posedge clk);#1;
            end
            clr_in;
            wait_done(400);
        end
    endtask

    initial begin
        pass_count=0; fail_count=0;
        $display("============================================");
        $display("  Testbench: systolic_array  Q8.8 format");
        $display("  1.0=0x0100 2.0=0x0200 3.0=0x0300 8.0=0x0800");
        $display("============================================");

        // ── Test 1: 3x3 Identity x Identity ─────────────
        $display("\n--- Test 1: 3x3 Identity x Identity ---");
        do_reset;
        A3[0][0]=16'h0100;A3[0][1]=0;        A3[0][2]=0;
        A3[1][0]=0;        A3[1][1]=16'h0100;A3[1][2]=0;
        A3[2][0]=0;        A3[2][1]=0;        A3[2][2]=16'h0100;
        B3[0][0]=16'h0100;B3[0][1]=0;        B3[0][2]=0;
        B3[1][0]=0;        B3[1][1]=16'h0100;B3[1][2]=0;
        B3[2][0]=0;        B3[2][1]=0;        B3[2][2]=16'h0100;
        feed_3x3(3,3);
        chk(C_out_00,16'h0100,"C[0][0]=1.0"); chk(C_out_01,16'h0000,"C[0][1]=0.0"); chk(C_out_02,16'h0000,"C[0][2]=0.0");
        chk(C_out_10,16'h0000,"C[1][0]=0.0"); chk(C_out_11,16'h0100,"C[1][1]=1.0"); chk(C_out_12,16'h0000,"C[1][2]=0.0");
        chk(C_out_20,16'h0000,"C[2][0]=0.0"); chk(C_out_21,16'h0000,"C[2][1]=0.0"); chk(C_out_22,16'h0100,"C[2][2]=1.0");

        // ── Test 2: 3x3 known values ─────────────────────
        // A=[[1,2,0],[0,1,0],[0,0,1]] B=[[1,0,0],[1,1,0],[0,0,1]]
        // C=[[3,2,0],[1,1,0],[0,0,1]]
        $display("\n--- Test 2: 3x3 known-value multiply ---");
        do_reset;
        A3[0][0]=16'h0100;A3[0][1]=16'h0200;A3[0][2]=0;
        A3[1][0]=0;        A3[1][1]=16'h0100;A3[1][2]=0;
        A3[2][0]=0;        A3[2][1]=0;        A3[2][2]=16'h0100;
        B3[0][0]=16'h0100;B3[0][1]=0;        B3[0][2]=0;
        B3[1][0]=16'h0100;B3[1][1]=16'h0100;B3[1][2]=0;
        B3[2][0]=0;        B3[2][1]=0;        B3[2][2]=16'h0100;
        feed_3x3(3,3);
        chk(C_out_00,16'h0300,"C[0][0]=3.0"); chk(C_out_01,16'h0200,"C[0][1]=2.0"); chk(C_out_02,16'h0000,"C[0][2]=0.0");
        chk(C_out_10,16'h0100,"C[1][0]=1.0"); chk(C_out_11,16'h0100,"C[1][1]=1.0"); chk(C_out_12,16'h0000,"C[1][2]=0.0");
        chk(C_out_20,16'h0000,"C[2][0]=0.0"); chk(C_out_21,16'h0000,"C[2][1]=0.0"); chk(C_out_22,16'h0100,"C[2][2]=1.0");

        // ── Test 3: 8x8 all-ones => C=8.0 everywhere ────
        $display("\n--- Test 3: 8x8 all-ones (C=8.0) ---");
        do_reset;
        begin : f8
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin A8[r][c]=16'h0100; B8[r][c]=16'h0100; end
        end
        feed_8x8;
        chk(C_out_00,16'h0800,"C[0][0]=8.0"); chk(C_out_07,16'h0800,"C[0][7]=8.0");
        chk(C_out_33,16'h0800,"C[3][3]=8.0"); chk(C_out_44,16'h0800,"C[4][4]=8.0");
        chk(C_out_70,16'h0800,"C[7][0]=8.0"); chk(C_out_77,16'h0800,"C[7][7]=8.0");

        // ── Test 4: zero-skip count ───────────────────────
        $display("\n--- Test 4: zero-skip count (sparse A) ---");
        do_reset;
        begin : sp
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin
                A8[r][c]=(r%2==0)?16'h0100:16'h0000;
                B8[r][c]=16'h0100;
            end
        end
        feed_8x8;
        $display("  INFO | skip_count=%0d (expect > 0)",skip_count);
        if(skip_count>0) begin $display("  PASS | zero-skip fired correctly"); pass_count=pass_count+1; end
        else             begin $display("  FAIL | skip_count=0");              fail_count=fail_count+1;  end

        $display("\n============================================");
        $display("  Results: %0d PASSED, %0d FAILED",pass_count,fail_count);
        if(fail_count==0) $display("  ALL TESTS PASSED");
        else              $display("  SOME TESTS FAILED");
        $display("============================================");
        $finish;
    end

    initial begin $dumpfile("tb_systolic_array.vcd");$dumpvars(0,tb_systolic_array);end
    initial begin #10000000;$display("TIMEOUT");$finish;end
endmodule
