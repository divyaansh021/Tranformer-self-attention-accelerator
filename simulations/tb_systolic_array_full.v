// ============================================================
// Testbench : tb_systolic_array_full
// File      : tb_systolic_array_full.v
//
// Test cases:
//   Test 1 - 3x3 Identity x Identity = Identity
//   Test 2 - 3x3 known-value (original)
//   Test 3 - 8x8 all-ones => C=8.0
//   Test 4 - zero-skip counter
//   Test 5 - Professor's slide: Q(3x2) x KT(2x3)
//            Q=[[1,0],[0,1],[1,1]]  KT=[[1,0,1],[0,1,1]]
//            C=[[1,0,1],[0,1,1],[1,1,2]]
//   Test 6 - Asymmetric values: mixed large numbers
//            Q=[[1,2],[3,4],[0,1]]  KT=[[1,0,2],[1,2,0]]
//            C=[[3,4,2],[7,8,6],[1,2,0]]
//   Test 7 - Zero row in Q (zero-skip full row)
//            Q=[[1,1],[0,0],[1,0]]  KT=[[1,1,1],[1,1,1]]
//            C=[[2,2,2],[0,0,0],[1,1,1]]
//   Test 8 - 3x3 all-twos: C=12.0 everywhere
//   Test 9 - 4x4 diagonal x scalar: I4 x 2*I4 = 2*I4
//   Test 10 - 8x8 identity x identity = identity
// ============================================================
`timescale 1ns/1ps

module tb_systolic_array_full;

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

    // ── helpers ──────────────────────────────────────────────
    task chk;
        input [DW-1:0] got,exp; input [8*30-1:0] nm;
        begin
            if(got===exp) begin
                $display("  PASS | %s | %h",nm,got);
                pass_count=pass_count+1;
            end else begin
                $display("  FAIL | %s | got=%h exp=%h",nm,got,exp);
                fail_count=fail_count+1;
            end
        end
    endtask

    task clr_in;
        begin
            A_in_0=0;A_in_1=0;A_in_2=0;A_in_3=0;
            A_in_4=0;A_in_5=0;A_in_6=0;A_in_7=0;
            B_in_0=0;B_in_1=0;B_in_2=0;B_in_3=0;
            B_in_4=0;B_in_5=0;B_in_6=0;B_in_7=0;
        end
    endtask

    task do_reset;
        begin
            rst_n=0;start=0;clr_in;
            repeat(3)@(posedge clk);
            rst_n=1;@(posedge clk);#1;
        end
    endtask

    task wait_done;
        input integer t; integer w;
        begin
            w=0;
            while(!done&&w<t) begin @(posedge clk);#1;w=w+1; end
            if(w>=t) $display("  TIMEOUT after %0d cycles",t);
        end
    endtask

    // ── matrix storage ───────────────────────────────────────
    // A[row][k], B[k][col] — inner dim k goes to DK
    reg [DW-1:0] AM[0:7][0:7];  // A matrix
    reg [DW-1:0] BM[0:7][0:7];  // B matrix (B[k][col])

    // ── generic feed task ─────────────────────────────────────
    // n_sz  = number of rows/cols (N)
    // dk_sz = inner dimension (DK)
    // Timing: start -> CLEAR (1 cycle) -> RUN (feed dk_sz cycles)
    task feed_matrix;
        input integer n_sz, dk_sz;
        integer kk;
        begin
            n_valid  = n_sz;
            dk_valid = dk_sz;

            start=1; @(posedge clk);#1; start=0;
            @(posedge clk);#1;  // wait through CLEAR

            for(kk=0; kk<dk_sz; kk=kk+1) begin
                // A rows: row i gets its k-th element
                A_in_0=(0<n_sz)?AM[0][kk]:0;
                A_in_1=(1<n_sz)?AM[1][kk]:0;
                A_in_2=(2<n_sz)?AM[2][kk]:0;
                A_in_3=(3<n_sz)?AM[3][kk]:0;
                A_in_4=(4<n_sz)?AM[4][kk]:0;
                A_in_5=(5<n_sz)?AM[5][kk]:0;
                A_in_6=(6<n_sz)?AM[6][kk]:0;
                A_in_7=(7<n_sz)?AM[7][kk]:0;
                // B cols: col j gets its k-th element
                B_in_0=(0<n_sz)?BM[kk][0]:0;
                B_in_1=(1<n_sz)?BM[kk][1]:0;
                B_in_2=(2<n_sz)?BM[kk][2]:0;
                B_in_3=(3<n_sz)?BM[kk][3]:0;
                B_in_4=(4<n_sz)?BM[kk][4]:0;
                B_in_5=(5<n_sz)?BM[kk][5]:0;
                B_in_6=(6<n_sz)?BM[kk][6]:0;
                B_in_7=(7<n_sz)?BM[kk][7]:0;
                @(posedge clk);#1;
            end
            clr_in;
            wait_done(500);
        end
    endtask

    // ── helper: Q8.8 value from integer ──────────────────────
    // e.g. q88(1) = 16'h0100, q88(3) = 16'h0300
    function [DW-1:0] q88;
        input integer v;
        begin q88 = v * 256; end
    endfunction

    // ── main test sequence ────────────────────────────────────
    initial begin
        pass_count=0; fail_count=0;

        $display("============================================");
        $display("  tb_systolic_array_full");
        $display("  Q8.8: 1.0=0x0100  2.0=0x0200  etc.");
        $display("============================================");

        // =====================================================
        // TEST 1: 3x3 Identity x Identity = Identity
        // A=B=I3, C[i][j]=1 if i==j else 0
        // =====================================================
        $display("\n--- Test 1: 3x3 Identity x Identity ---");
        do_reset;
        begin : t1
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin AM[r][c]=0; BM[r][c]=0; end
            AM[0][0]=q88(1); AM[1][1]=q88(1); AM[2][2]=q88(1);
            BM[0][0]=q88(1); BM[1][1]=q88(1); BM[2][2]=q88(1);
        end
        feed_matrix(3,3);
        chk(C_out_00,q88(1),"C[0][0]=1"); chk(C_out_01,q88(0),"C[0][1]=0"); chk(C_out_02,q88(0),"C[0][2]=0");
        chk(C_out_10,q88(0),"C[1][0]=0"); chk(C_out_11,q88(1),"C[1][1]=1"); chk(C_out_12,q88(0),"C[1][2]=0");
        chk(C_out_20,q88(0),"C[2][0]=0"); chk(C_out_21,q88(0),"C[2][1]=0"); chk(C_out_22,q88(1),"C[2][2]=1");

        // =====================================================
        // TEST 2: 3x3 known-value (original test)
        // A=[[1,2,0],[0,1,0],[0,0,1]]  B=[[1,0,0],[1,1,0],[0,0,1]]
        // C=[[3,2,0],[1,1,0],[0,0,1]]
        // =====================================================
        $display("\n--- Test 2: 3x3 known-value ---");
        do_reset;
        begin : t2
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin AM[r][c]=0; BM[r][c]=0; end
            AM[0][0]=q88(1);AM[0][1]=q88(2);AM[1][1]=q88(1);AM[2][2]=q88(1);
            BM[0][0]=q88(1);BM[1][0]=q88(1);BM[1][1]=q88(1);BM[2][2]=q88(1);
        end
        feed_matrix(3,3);
        chk(C_out_00,q88(3),"C[0][0]=3"); chk(C_out_01,q88(2),"C[0][1]=2"); chk(C_out_02,q88(0),"C[0][2]=0");
        chk(C_out_10,q88(1),"C[1][0]=1"); chk(C_out_11,q88(1),"C[1][1]=1"); chk(C_out_12,q88(0),"C[1][2]=0");
        chk(C_out_20,q88(0),"C[2][0]=0"); chk(C_out_21,q88(0),"C[2][1]=0"); chk(C_out_22,q88(1),"C[2][2]=1");

        // =====================================================
        // TEST 3: 8x8 all-ones => C=8.0 everywhere
        // A=B=ones(8,8), C[i][j]=8.0 (0x0800)
        // =====================================================
        $display("\n--- Test 3: 8x8 all-ones => C=8.0 ---");
        do_reset;
        begin : t3
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin AM[r][c]=q88(1); BM[r][c]=q88(1); end
        end
        feed_matrix(8,8);
        chk(C_out_00,q88(8),"C[0][0]=8"); chk(C_out_07,q88(8),"C[0][7]=8");
        chk(C_out_33,q88(8),"C[3][3]=8"); chk(C_out_44,q88(8),"C[4][4]=8");
        chk(C_out_70,q88(8),"C[7][0]=8"); chk(C_out_77,q88(8),"C[7][7]=8");

        // =====================================================
        // TEST 4: Zero-skip counter (sparse A)
        // =====================================================
        $display("\n--- Test 4: zero-skip counter ---");
        do_reset;
        begin : t4
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin
                AM[r][c]=(r%2==0)?q88(1):0;
                BM[r][c]=q88(1);
            end
        end
        feed_matrix(8,8);
        $display("  INFO | skip_count=%0d",skip_count);
        if(skip_count>0) begin
            $display("  PASS | zero-skip fired"); pass_count=pass_count+1;
        end else begin
            $display("  FAIL | skip_count=0");   fail_count=fail_count+1;
        end

        // =====================================================
        // TEST 5: PROFESSOR'S SLIDE — Q x K^T
        // Q  = [[1,0],[0,1],[1,1]]  (3 tokens, DK=2)
        // KT = [[1,0,1],[0,1,1]]    (DK=2 rows, 3 cols)
        // C  = [[1,0,1],[0,1,1],[1,1,2]]
        // Hand-verify:
        //   C[0][0]=1*1+0*0=1  C[0][1]=1*0+0*1=0  C[0][2]=1*1+0*1=1
        //   C[1][0]=0*1+1*0=0  C[1][1]=0*0+1*1=1  C[1][2]=0*1+1*1=1
        //   C[2][0]=1*1+1*0=1  C[2][1]=1*0+1*1=1  C[2][2]=1*1+1*1=2
        // =====================================================
        $display("\n--- Test 5: Professor slide Q x KT (N=3 DK=2) ---");
        $display("  Q=[[1,0],[0,1],[1,1]]  KT=[[1,0,1],[0,1,1]]");
        $display("  Expected C=[[1,0,1],[0,1,1],[1,1,2]]");
        do_reset;
        begin : t5
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin AM[r][c]=0; BM[r][c]=0; end
            // Q rows (A matrix): A[row][k]
            AM[0][0]=q88(1); AM[0][1]=q88(0);  // Q row 0 = [1,0]
            AM[1][0]=q88(0); AM[1][1]=q88(1);  // Q row 1 = [0,1]
            AM[2][0]=q88(1); AM[2][1]=q88(1);  // Q row 2 = [1,1]
            // KT cols (B matrix): B[k][col]
            // KT = [[1,0,1],[0,1,1]] so B[0][.]=row0 of KT, B[1][.]=row1
            BM[0][0]=q88(1); BM[0][1]=q88(0); BM[0][2]=q88(1);  // KT row 0
            BM[1][0]=q88(0); BM[1][1]=q88(1); BM[1][2]=q88(1);  // KT row 1
        end
        feed_matrix(3,2);
        chk(C_out_00,q88(1),"C[0][0]=1"); chk(C_out_01,q88(0),"C[0][1]=0"); chk(C_out_02,q88(1),"C[0][2]=1");
        chk(C_out_10,q88(0),"C[1][0]=0"); chk(C_out_11,q88(1),"C[1][1]=1"); chk(C_out_12,q88(1),"C[1][2]=1");
        chk(C_out_20,q88(1),"C[2][0]=1"); chk(C_out_21,q88(1),"C[2][1]=1"); chk(C_out_22,q88(2),"C[2][2]=2");

        // =====================================================
        // TEST 6: Asymmetric larger values
        // Q=[[1,2],[3,4],[0,1]]  KT=[[1,0,2],[1,2,0]]
        // C=[[3,4,2],[7,8,6],[1,2,0]]
        // Hand-verify C[1][1]: 3*0+4*2=8  C[1][0]: 3*1+4*1=7
        // =====================================================
        $display("\n--- Test 6: Asymmetric values (N=3 DK=2) ---");
        $display("  Q=[[1,2],[3,4],[0,1]]  KT=[[1,0,2],[1,2,0]]");
        $display("  Expected C=[[3,4,2],[7,8,6],[1,2,0]]");
        do_reset;
        begin : t6
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin AM[r][c]=0; BM[r][c]=0; end
            AM[0][0]=q88(1);AM[0][1]=q88(2);
            AM[1][0]=q88(3);AM[1][1]=q88(4);
            AM[2][0]=q88(0);AM[2][1]=q88(1);
            BM[0][0]=q88(1);BM[0][1]=q88(0);BM[0][2]=q88(2);
            BM[1][0]=q88(1);BM[1][1]=q88(2);BM[1][2]=q88(0);
        end
        feed_matrix(3,2);
        chk(C_out_00,q88(3),"C[0][0]=3"); chk(C_out_01,q88(4),"C[0][1]=4"); chk(C_out_02,q88(2),"C[0][2]=2");
        chk(C_out_10,q88(7),"C[1][0]=7"); chk(C_out_11,q88(8),"C[1][1]=8"); chk(C_out_12,q88(6),"C[1][2]=6");
        chk(C_out_20,q88(1),"C[2][0]=1"); chk(C_out_21,q88(2),"C[2][1]=2"); chk(C_out_22,q88(0),"C[2][2]=0");

        // =====================================================
        // TEST 7: Zero row in Q — tests zero-skip on full row
        // Q=[[1,1],[0,0],[1,0]]  KT=[[1,1,1],[1,1,1]]
        // C=[[2,2,2],[0,0,0],[1,1,1]]
        // Row 1 of C is all zeros — PE row 1 zero-skips every cycle
        // =====================================================
        $display("\n--- Test 7: Zero row in Q => full zero row in C ---");
        $display("  Q=[[1,1],[0,0],[1,0]]  KT=[[1,1,1],[1,1,1]]");
        $display("  Expected C=[[2,2,2],[0,0,0],[1,1,1]]");
        do_reset;
        begin : t7
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin AM[r][c]=0; BM[r][c]=0; end
            AM[0][0]=q88(1);AM[0][1]=q88(1);
            AM[1][0]=q88(0);AM[1][1]=q88(0);  // zero row
            AM[2][0]=q88(1);AM[2][1]=q88(0);
            BM[0][0]=q88(1);BM[0][1]=q88(1);BM[0][2]=q88(1);
            BM[1][0]=q88(1);BM[1][1]=q88(1);BM[1][2]=q88(1);
        end
        feed_matrix(3,2);
        chk(C_out_00,q88(2),"C[0][0]=2"); chk(C_out_01,q88(2),"C[0][1]=2"); chk(C_out_02,q88(2),"C[0][2]=2");
        chk(C_out_10,q88(0),"C[1][0]=0"); chk(C_out_11,q88(0),"C[1][1]=0"); chk(C_out_12,q88(0),"C[1][2]=0");
        chk(C_out_20,q88(1),"C[2][0]=1"); chk(C_out_21,q88(1),"C[2][1]=1"); chk(C_out_22,q88(1),"C[2][2]=1");

        // =====================================================
        // TEST 8: 3x3 all-twos
        // A=B=2*ones(3,3), C[i][j]=12.0 (3 terms of 2*2=4, sum=12)
        // =====================================================
        $display("\n--- Test 8: 3x3 all-twos => C=12.0 ---");
        do_reset;
        begin : t8
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin AM[r][c]=0; BM[r][c]=0; end
            begin : inner8
                integer i,j;
                for(i=0;i<3;i=i+1) for(j=0;j<3;j=j+1) begin
                    AM[i][j]=q88(2); BM[i][j]=q88(2);
                end
            end
        end
        feed_matrix(3,3);
        chk(C_out_00,q88(12),"C[0][0]=12"); chk(C_out_01,q88(12),"C[0][1]=12");
        chk(C_out_11,q88(12),"C[1][1]=12"); chk(C_out_22,q88(12),"C[2][2]=12");

        // =====================================================
        // TEST 9: 4x4 Identity x 2*Identity = 2*Identity
        // A=I4, B=2*I4, C[i][j]=2 if i==j else 0
        // =====================================================
        $display("\n--- Test 9: 4x4 I4 x 2*I4 = 2*I4 ---");
        do_reset;
        begin : t9
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin AM[r][c]=0; BM[r][c]=0; end
            AM[0][0]=q88(1);AM[1][1]=q88(1);AM[2][2]=q88(1);AM[3][3]=q88(1);
            BM[0][0]=q88(2);BM[1][1]=q88(2);BM[2][2]=q88(2);BM[3][3]=q88(2);
        end
        feed_matrix(4,4);
        chk(C_out_00,q88(2),"C[0][0]=2"); chk(C_out_11,q88(2),"C[1][1]=2");
        chk(C_out_22,q88(2),"C[2][2]=2"); chk(C_out_33,q88(2),"C[3][3]=2");
        chk(C_out_01,q88(0),"C[0][1]=0"); chk(C_out_10,q88(0),"C[1][0]=0");
        chk(C_out_23,q88(0),"C[2][3]=0"); chk(C_out_32,q88(0),"C[3][2]=0");

        // =====================================================
        // TEST 10: 8x8 Identity x Identity = Identity
        // Diagonal=1.0, all off-diagonal=0.0
        // =====================================================
        $display("\n--- Test 10: 8x8 Identity x Identity ---");
        do_reset;
        begin : t10
            integer r,c;
            for(r=0;r<8;r=r+1) for(c=0;c<8;c=c+1) begin AM[r][c]=0; BM[r][c]=0; end
            AM[0][0]=q88(1);AM[1][1]=q88(1);AM[2][2]=q88(1);AM[3][3]=q88(1);
            AM[4][4]=q88(1);AM[5][5]=q88(1);AM[6][6]=q88(1);AM[7][7]=q88(1);
            BM[0][0]=q88(1);BM[1][1]=q88(1);BM[2][2]=q88(1);BM[3][3]=q88(1);
            BM[4][4]=q88(1);BM[5][5]=q88(1);BM[6][6]=q88(1);BM[7][7]=q88(1);
        end
        feed_matrix(8,8);
        // diagonal = 1.0
        chk(C_out_00,q88(1),"C[0][0]=1"); chk(C_out_11,q88(1),"C[1][1]=1");
        chk(C_out_22,q88(1),"C[2][2]=1"); chk(C_out_33,q88(1),"C[3][3]=1");
        chk(C_out_44,q88(1),"C[4][4]=1"); chk(C_out_55,q88(1),"C[5][5]=1");
        chk(C_out_66,q88(1),"C[6][6]=1"); chk(C_out_77,q88(1),"C[7][7]=1");
        // off-diagonal = 0.0
        chk(C_out_01,q88(0),"C[0][1]=0"); chk(C_out_07,q88(0),"C[0][7]=0");
        chk(C_out_70,q88(0),"C[7][0]=0"); chk(C_out_34,q88(0),"C[3][4]=0");

        // =====================================================
        // Summary
        // =====================================================
        $display("\n============================================");
        $display("  Results: %0d PASSED, %0d FAILED",
                  pass_count, fail_count);
        if(fail_count==0) $display("  ALL TESTS PASSED");
        else              $display("  SOME TESTS FAILED");
        $display("============================================");
        $finish;
    end

    initial begin
        $dumpfile("tb_systolic_array_full.vcd");
        $dumpvars(0,tb_systolic_array_full);
    end
    initial begin #20000000; $display("TIMEOUT"); $finish; end

endmodule
