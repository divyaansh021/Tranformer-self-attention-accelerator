// ============================================================
// Module  : attention_top
// Project : Transformer Attention Block Accelerator
// File    : attention_top.v
//
// Description:
//   Top-level single-head attention accelerator.
//   Computes: Output = softmax(Q × Kᵀ / √dk) × V
//
//   Instantiates and sequences:
//     systolic_array  — shared for MAC1 (Q×Kᵀ) and MAC2 (Attn×V)
//     scale_ctrl      — serialises MAC1 output through scale.v
//     scale           — divides each score by 1/√dk
//     softmax_ctrl    — runs softmax.v once per row (N rows)
//     softmax         — computes attention weights per row
//     exp_lut         — 256-entry exp table for softmax
//
//   FSM states:
//     IDLE     : wait for start
//     MAC1     : compute Q × Kᵀ (systolic array, N+DK-2 cycles)
//     SCALE    : serialise 64 scores through scale unit (65 cycles)
//     SOFTMAX  : run softmax N times, one row per ~158 cycles
//     MAC2     : compute Attn × V (systolic array, 2N+N-2 cycles)
//     DONE_ST  : assert done for 1 cycle
//
//   Total latency: ~1381 cycles (N=8, DK=8)
//
// Port naming convention:
//   Q[i][k]  — query matrix, row i col k  → port Q_ik
//   K[i][k]  — key matrix,   row i col k  → port K_ik
//   V[k][j]  — value matrix, row k col j  → port V_kj
//   Out[i][j]— output,       row i col j  → port out_ij
//
//   MAC1 feeds: column k of Q as A rows, column k of K as B rows
//               (K[j][k] = Kᵀ[k][j], so K cols become KT rows)
//   MAC2 feeds: column k of Attn as A rows, row k of V as B cols
//
// Parameters:
//   N  — max tokens / array size  (default 8)
//   DK — head dimension            (default 8)
//   DW — data width Q8.8          (default 16)
// ============================================================

module attention_top #(
    parameter N  = 8,
    parameter DK = 8,
    parameter DW = 16
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [3:0]  n_valid,   // actual number of tokens (1..N)
    input  wire [3:0]  dk_valid,  // head dimension (1..DK)

    // Q matrix [N x DK]
    input  wire [DW-1:0] Q_00,Q_01,Q_02,Q_03,Q_04,Q_05,Q_06,Q_07,
    input  wire [DW-1:0] Q_10,Q_11,Q_12,Q_13,Q_14,Q_15,Q_16,Q_17,
    input  wire [DW-1:0] Q_20,Q_21,Q_22,Q_23,Q_24,Q_25,Q_26,Q_27,
    input  wire [DW-1:0] Q_30,Q_31,Q_32,Q_33,Q_34,Q_35,Q_36,Q_37,
    input  wire [DW-1:0] Q_40,Q_41,Q_42,Q_43,Q_44,Q_45,Q_46,Q_47,
    input  wire [DW-1:0] Q_50,Q_51,Q_52,Q_53,Q_54,Q_55,Q_56,Q_57,
    input  wire [DW-1:0] Q_60,Q_61,Q_62,Q_63,Q_64,Q_65,Q_66,Q_67,
    input  wire [DW-1:0] Q_70,Q_71,Q_72,Q_73,Q_74,Q_75,Q_76,Q_77,

    // K matrix [N x DK]
    input  wire [DW-1:0] K_00,K_01,K_02,K_03,K_04,K_05,K_06,K_07,
    input  wire [DW-1:0] K_10,K_11,K_12,K_13,K_14,K_15,K_16,K_17,
    input  wire [DW-1:0] K_20,K_21,K_22,K_23,K_24,K_25,K_26,K_27,
    input  wire [DW-1:0] K_30,K_31,K_32,K_33,K_34,K_35,K_36,K_37,
    input  wire [DW-1:0] K_40,K_41,K_42,K_43,K_44,K_45,K_46,K_47,
    input  wire [DW-1:0] K_50,K_51,K_52,K_53,K_54,K_55,K_56,K_57,
    input  wire [DW-1:0] K_60,K_61,K_62,K_63,K_64,K_65,K_66,K_67,
    input  wire [DW-1:0] K_70,K_71,K_72,K_73,K_74,K_75,K_76,K_77,

    // V matrix [N x DK]
    input  wire [DW-1:0] V_00,V_01,V_02,V_03,V_04,V_05,V_06,V_07,
    input  wire [DW-1:0] V_10,V_11,V_12,V_13,V_14,V_15,V_16,V_17,
    input  wire [DW-1:0] V_20,V_21,V_22,V_23,V_24,V_25,V_26,V_27,
    input  wire [DW-1:0] V_30,V_31,V_32,V_33,V_34,V_35,V_36,V_37,
    input  wire [DW-1:0] V_40,V_41,V_42,V_43,V_44,V_45,V_46,V_47,
    input  wire [DW-1:0] V_50,V_51,V_52,V_53,V_54,V_55,V_56,V_57,
    input  wire [DW-1:0] V_60,V_61,V_62,V_63,V_64,V_65,V_66,V_67,
    input  wire [DW-1:0] V_70,V_71,V_72,V_73,V_74,V_75,V_76,V_77,

    // Output context matrix [N x DK]
    output wire [DW-1:0] out_00,out_01,out_02,out_03,out_04,out_05,out_06,out_07,
    output wire [DW-1:0] out_10,out_11,out_12,out_13,out_14,out_15,out_16,out_17,
    output wire [DW-1:0] out_20,out_21,out_22,out_23,out_24,out_25,out_26,out_27,
    output wire [DW-1:0] out_30,out_31,out_32,out_33,out_34,out_35,out_36,out_37,
    output wire [DW-1:0] out_40,out_41,out_42,out_43,out_44,out_45,out_46,out_47,
    output wire [DW-1:0] out_50,out_51,out_52,out_53,out_54,out_55,out_56,out_57,
    output wire [DW-1:0] out_60,out_61,out_62,out_63,out_64,out_65,out_66,out_67,
    output wire [DW-1:0] out_70,out_71,out_72,out_73,out_74,out_75,out_76,out_77,

    output reg  done
);

    // ── FSM states ───────────────────────────────────────────
    localparam IDLE    = 3'd0;
    localparam MAC1    = 3'd1;
    localparam SCALE   = 3'd2;
    localparam SOFTMAX = 3'd3;
    localparam MAC2    = 3'd4;
    localparam DONE_ST = 3'd5;

    reg [2:0] state;

    // ── Pack Q, K, V into arrays ─────────────────────────────
    wire [DW-1:0] Q_mat [0:N-1][0:DK-1];
    wire [DW-1:0] K_mat [0:N-1][0:DK-1];
    wire [DW-1:0] V_mat [0:N-1][0:DK-1];

    assign Q_mat[0][0]=Q_00;assign Q_mat[0][1]=Q_01;assign Q_mat[0][2]=Q_02;assign Q_mat[0][3]=Q_03;
    assign Q_mat[0][4]=Q_04;assign Q_mat[0][5]=Q_05;assign Q_mat[0][6]=Q_06;assign Q_mat[0][7]=Q_07;
    assign Q_mat[1][0]=Q_10;assign Q_mat[1][1]=Q_11;assign Q_mat[1][2]=Q_12;assign Q_mat[1][3]=Q_13;
    assign Q_mat[1][4]=Q_14;assign Q_mat[1][5]=Q_15;assign Q_mat[1][6]=Q_16;assign Q_mat[1][7]=Q_17;
    assign Q_mat[2][0]=Q_20;assign Q_mat[2][1]=Q_21;assign Q_mat[2][2]=Q_22;assign Q_mat[2][3]=Q_23;
    assign Q_mat[2][4]=Q_24;assign Q_mat[2][5]=Q_25;assign Q_mat[2][6]=Q_26;assign Q_mat[2][7]=Q_27;
    assign Q_mat[3][0]=Q_30;assign Q_mat[3][1]=Q_31;assign Q_mat[3][2]=Q_32;assign Q_mat[3][3]=Q_33;
    assign Q_mat[3][4]=Q_34;assign Q_mat[3][5]=Q_35;assign Q_mat[3][6]=Q_36;assign Q_mat[3][7]=Q_37;
    assign Q_mat[4][0]=Q_40;assign Q_mat[4][1]=Q_41;assign Q_mat[4][2]=Q_42;assign Q_mat[4][3]=Q_43;
    assign Q_mat[4][4]=Q_44;assign Q_mat[4][5]=Q_45;assign Q_mat[4][6]=Q_46;assign Q_mat[4][7]=Q_47;
    assign Q_mat[5][0]=Q_50;assign Q_mat[5][1]=Q_51;assign Q_mat[5][2]=Q_52;assign Q_mat[5][3]=Q_53;
    assign Q_mat[5][4]=Q_54;assign Q_mat[5][5]=Q_55;assign Q_mat[5][6]=Q_56;assign Q_mat[5][7]=Q_57;
    assign Q_mat[6][0]=Q_60;assign Q_mat[6][1]=Q_61;assign Q_mat[6][2]=Q_62;assign Q_mat[6][3]=Q_63;
    assign Q_mat[6][4]=Q_64;assign Q_mat[6][5]=Q_65;assign Q_mat[6][6]=Q_66;assign Q_mat[6][7]=Q_67;
    assign Q_mat[7][0]=Q_70;assign Q_mat[7][1]=Q_71;assign Q_mat[7][2]=Q_72;assign Q_mat[7][3]=Q_73;
    assign Q_mat[7][4]=Q_74;assign Q_mat[7][5]=Q_75;assign Q_mat[7][6]=Q_76;assign Q_mat[7][7]=Q_77;

    assign K_mat[0][0]=K_00;assign K_mat[0][1]=K_01;assign K_mat[0][2]=K_02;assign K_mat[0][3]=K_03;
    assign K_mat[0][4]=K_04;assign K_mat[0][5]=K_05;assign K_mat[0][6]=K_06;assign K_mat[0][7]=K_07;
    assign K_mat[1][0]=K_10;assign K_mat[1][1]=K_11;assign K_mat[1][2]=K_12;assign K_mat[1][3]=K_13;
    assign K_mat[1][4]=K_14;assign K_mat[1][5]=K_15;assign K_mat[1][6]=K_16;assign K_mat[1][7]=K_17;
    assign K_mat[2][0]=K_20;assign K_mat[2][1]=K_21;assign K_mat[2][2]=K_22;assign K_mat[2][3]=K_23;
    assign K_mat[2][4]=K_24;assign K_mat[2][5]=K_25;assign K_mat[2][6]=K_26;assign K_mat[2][7]=K_27;
    assign K_mat[3][0]=K_30;assign K_mat[3][1]=K_31;assign K_mat[3][2]=K_32;assign K_mat[3][3]=K_33;
    assign K_mat[3][4]=K_34;assign K_mat[3][5]=K_35;assign K_mat[3][6]=K_36;assign K_mat[3][7]=K_37;
    assign K_mat[4][0]=K_40;assign K_mat[4][1]=K_41;assign K_mat[4][2]=K_42;assign K_mat[4][3]=K_43;
    assign K_mat[4][4]=K_44;assign K_mat[4][5]=K_45;assign K_mat[4][6]=K_46;assign K_mat[4][7]=K_47;
    assign K_mat[5][0]=K_50;assign K_mat[5][1]=K_51;assign K_mat[5][2]=K_52;assign K_mat[5][3]=K_53;
    assign K_mat[5][4]=K_54;assign K_mat[5][5]=K_55;assign K_mat[5][6]=K_56;assign K_mat[5][7]=K_57;
    assign K_mat[6][0]=K_60;assign K_mat[6][1]=K_61;assign K_mat[6][2]=K_62;assign K_mat[6][3]=K_63;
    assign K_mat[6][4]=K_64;assign K_mat[6][5]=K_65;assign K_mat[6][6]=K_66;assign K_mat[6][7]=K_67;
    assign K_mat[7][0]=K_70;assign K_mat[7][1]=K_71;assign K_mat[7][2]=K_72;assign K_mat[7][3]=K_73;
    assign K_mat[7][4]=K_74;assign K_mat[7][5]=K_75;assign K_mat[7][6]=K_76;assign K_mat[7][7]=K_77;

    assign V_mat[0][0]=V_00;assign V_mat[0][1]=V_01;assign V_mat[0][2]=V_02;assign V_mat[0][3]=V_03;
    assign V_mat[0][4]=V_04;assign V_mat[0][5]=V_05;assign V_mat[0][6]=V_06;assign V_mat[0][7]=V_07;
    assign V_mat[1][0]=V_10;assign V_mat[1][1]=V_11;assign V_mat[1][2]=V_12;assign V_mat[1][3]=V_13;
    assign V_mat[1][4]=V_14;assign V_mat[1][5]=V_15;assign V_mat[1][6]=V_16;assign V_mat[1][7]=V_17;
    assign V_mat[2][0]=V_20;assign V_mat[2][1]=V_21;assign V_mat[2][2]=V_22;assign V_mat[2][3]=V_23;
    assign V_mat[2][4]=V_24;assign V_mat[2][5]=V_25;assign V_mat[2][6]=V_26;assign V_mat[2][7]=V_27;
    assign V_mat[3][0]=V_30;assign V_mat[3][1]=V_31;assign V_mat[3][2]=V_32;assign V_mat[3][3]=V_33;
    assign V_mat[3][4]=V_34;assign V_mat[3][5]=V_35;assign V_mat[3][6]=V_36;assign V_mat[3][7]=V_37;
    assign V_mat[4][0]=V_40;assign V_mat[4][1]=V_41;assign V_mat[4][2]=V_42;assign V_mat[4][3]=V_43;
    assign V_mat[4][4]=V_44;assign V_mat[4][5]=V_45;assign V_mat[4][6]=V_46;assign V_mat[4][7]=V_47;
    assign V_mat[5][0]=V_50;assign V_mat[5][1]=V_51;assign V_mat[5][2]=V_52;assign V_mat[5][3]=V_53;
    assign V_mat[5][4]=V_54;assign V_mat[5][5]=V_55;assign V_mat[5][6]=V_56;assign V_mat[5][7]=V_57;
    assign V_mat[6][0]=V_60;assign V_mat[6][1]=V_61;assign V_mat[6][2]=V_62;assign V_mat[6][3]=V_63;
    assign V_mat[6][4]=V_64;assign V_mat[6][5]=V_65;assign V_mat[6][6]=V_66;assign V_mat[6][7]=V_67;
    assign V_mat[7][0]=V_70;assign V_mat[7][1]=V_71;assign V_mat[7][2]=V_72;assign V_mat[7][3]=V_73;
    assign V_mat[7][4]=V_74;assign V_mat[7][5]=V_75;assign V_mat[7][6]=V_76;assign V_mat[7][7]=V_77;

    // ── MAC data column counter ─────────────────────────────
    reg [3:0]  mac_col_cnt;   // which column of A/B to feed
    reg        mac_feeding;   // actively feeding data
    reg [3:0]  mac_n_reg;
    reg [3:0]  mac_dk_reg;

    // ── Systolic array signals ────────────────────────────────
    reg           mac_start_r;
    reg  [3:0]    mac_n_in, mac_dk_in;
    reg  [DW-1:0] mac_A0,mac_A1,mac_A2,mac_A3,mac_A4,mac_A5,mac_A6,mac_A7;
    reg  [DW-1:0] mac_B0,mac_B1,mac_B2,mac_B3,mac_B4,mac_B5,mac_B6,mac_B7;
    wire          mac_done_w, mac_run_w;
    wire [31:0]   mac_skip_w;

    // C_out wires (score matrix from MAC1, output from MAC2)
    wire [DW-1:0] C00,C01,C02,C03,C04,C05,C06,C07;
    wire [DW-1:0] C10,C11,C12,C13,C14,C15,C16,C17;
    wire [DW-1:0] C20,C21,C22,C23,C24,C25,C26,C27;
    wire [DW-1:0] C30,C31,C32,C33,C34,C35,C36,C37;
    wire [DW-1:0] C40,C41,C42,C43,C44,C45,C46,C47;
    wire [DW-1:0] C50,C51,C52,C53,C54,C55,C56,C57;
    wire [DW-1:0] C60,C61,C62,C63,C64,C65,C66,C67;
    wire [DW-1:0] C70,C71,C72,C73,C74,C75,C76,C77;

    systolic_array #(.SIZE(N),.DW(DW)) u_mac (
        .clk(clk),.rst_n(rst_n),.start(mac_start_r),
        .n_valid(mac_n_in),.dk_valid(mac_dk_in),
        .A_in_0(mac_A0),.A_in_1(mac_A1),.A_in_2(mac_A2),.A_in_3(mac_A3),
        .A_in_4(mac_A4),.A_in_5(mac_A5),.A_in_6(mac_A6),.A_in_7(mac_A7),
        .B_in_0(mac_B0),.B_in_1(mac_B1),.B_in_2(mac_B2),.B_in_3(mac_B3),
        .B_in_4(mac_B4),.B_in_5(mac_B5),.B_in_6(mac_B6),.B_in_7(mac_B7),
        .C_out_00(C00),.C_out_01(C01),.C_out_02(C02),.C_out_03(C03),
        .C_out_04(C04),.C_out_05(C05),.C_out_06(C06),.C_out_07(C07),
        .C_out_10(C10),.C_out_11(C11),.C_out_12(C12),.C_out_13(C13),
        .C_out_14(C14),.C_out_15(C15),.C_out_16(C16),.C_out_17(C17),
        .C_out_20(C20),.C_out_21(C21),.C_out_22(C22),.C_out_23(C23),
        .C_out_24(C24),.C_out_25(C25),.C_out_26(C26),.C_out_27(C27),
        .C_out_30(C30),.C_out_31(C31),.C_out_32(C32),.C_out_33(C33),
        .C_out_34(C34),.C_out_35(C35),.C_out_36(C36),.C_out_37(C37),
        .C_out_40(C40),.C_out_41(C41),.C_out_42(C42),.C_out_43(C43),
        .C_out_44(C44),.C_out_45(C45),.C_out_46(C46),.C_out_47(C47),
        .C_out_50(C50),.C_out_51(C51),.C_out_52(C52),.C_out_53(C53),
        .C_out_54(C54),.C_out_55(C55),.C_out_56(C56),.C_out_57(C57),
        .C_out_60(C60),.C_out_61(C61),.C_out_62(C62),.C_out_63(C63),
        .C_out_64(C64),.C_out_65(C65),.C_out_66(C66),.C_out_67(C67),
        .C_out_70(C70),.C_out_71(C71),.C_out_72(C72),.C_out_73(C73),
        .C_out_74(C74),.C_out_75(C75),.C_out_76(C76),.C_out_77(C77),
        .done(mac_done_w),.running(mac_run_w),.skip_count(mac_skip_w)
    );

    // ── Scale unit ───────────────────────────────────────────
    wire           sc_valid_w, sc_vout_w;
    wire [DW-1:0]  sc_score_w, sc_out_w;

    scale #(.DW(DW)) u_scale (
        .clk(clk),.rst_n(rst_n),
        .valid_in(sc_valid_w),.score_in(sc_score_w),.dk(dk_valid),
        .scaled_out(sc_out_w),.valid_out(sc_vout_w)
    );

    // ── Scale controller ─────────────────────────────────────
    wire scale_done_w;
    wire [DW-1:0] sb_00,sb_01,sb_02,sb_03,sb_04,sb_05,sb_06,sb_07;
    wire [DW-1:0] sb_10,sb_11,sb_12,sb_13,sb_14,sb_15,sb_16,sb_17;
    wire [DW-1:0] sb_20,sb_21,sb_22,sb_23,sb_24,sb_25,sb_26,sb_27;
    wire [DW-1:0] sb_30,sb_31,sb_32,sb_33,sb_34,sb_35,sb_36,sb_37;
    wire [DW-1:0] sb_40,sb_41,sb_42,sb_43,sb_44,sb_45,sb_46,sb_47;
    wire [DW-1:0] sb_50,sb_51,sb_52,sb_53,sb_54,sb_55,sb_56,sb_57;
    wire [DW-1:0] sb_60,sb_61,sb_62,sb_63,sb_64,sb_65,sb_66,sb_67;
    wire [DW-1:0] sb_70,sb_71,sb_72,sb_73,sb_74,sb_75,sb_76,sb_77;

    scale_ctrl #(.DW(DW),.SIZE(N)) u_scale_ctrl (
        .clk(clk),.rst_n(rst_n),
        .mac_done(mac_done_w),.dk(dk_valid),
        .C_out_00(C00),.C_out_01(C01),.C_out_02(C02),.C_out_03(C03),
        .C_out_04(C04),.C_out_05(C05),.C_out_06(C06),.C_out_07(C07),
        .C_out_10(C10),.C_out_11(C11),.C_out_12(C12),.C_out_13(C13),
        .C_out_14(C14),.C_out_15(C15),.C_out_16(C16),.C_out_17(C17),
        .C_out_20(C20),.C_out_21(C21),.C_out_22(C22),.C_out_23(C23),
        .C_out_24(C24),.C_out_25(C25),.C_out_26(C26),.C_out_27(C27),
        .C_out_30(C30),.C_out_31(C31),.C_out_32(C32),.C_out_33(C33),
        .C_out_34(C34),.C_out_35(C35),.C_out_36(C36),.C_out_37(C37),
        .C_out_40(C40),.C_out_41(C41),.C_out_42(C42),.C_out_43(C43),
        .C_out_44(C44),.C_out_45(C45),.C_out_46(C46),.C_out_47(C47),
        .C_out_50(C50),.C_out_51(C51),.C_out_52(C52),.C_out_53(C53),
        .C_out_54(C54),.C_out_55(C55),.C_out_56(C56),.C_out_57(C57),
        .C_out_60(C60),.C_out_61(C61),.C_out_62(C62),.C_out_63(C63),
        .C_out_64(C64),.C_out_65(C65),.C_out_66(C66),.C_out_67(C67),
        .C_out_70(C70),.C_out_71(C71),.C_out_72(C72),.C_out_73(C73),
        .C_out_74(C74),.C_out_75(C75),.C_out_76(C76),.C_out_77(C77),
        .valid_in(sc_valid_w),.score_in(sc_score_w),
        .valid_out(sc_vout_w),.scaled_out(sc_out_w),
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

    // ── Softmax unit ─────────────────────────────────────────
    wire           sm_start_w, sm_done_w;
    wire [DW-1:0]  sm_s0,sm_s1,sm_s2,sm_s3,sm_s4,sm_s5,sm_s6,sm_s7;
    wire [DW-1:0]  sm_w0,sm_w1,sm_w2,sm_w3,sm_w4,sm_w5,sm_w6,sm_w7;
    wire [DW-1:0]  sm_max_w, sm_sum_w;

    softmax #(.N(N),.DW(DW)) u_softmax (
        .clk(clk),.rst_n(rst_n),.start(sm_start_w),
        .score_0(sm_s0),.score_1(sm_s1),.score_2(sm_s2),.score_3(sm_s3),
        .score_4(sm_s4),.score_5(sm_s5),.score_6(sm_s6),.score_7(sm_s7),
        .weight_0(sm_w0),.weight_1(sm_w1),.weight_2(sm_w2),.weight_3(sm_w3),
        .weight_4(sm_w4),.weight_5(sm_w5),.weight_6(sm_w6),.weight_7(sm_w7),
        .done(sm_done_w),.row_max(sm_max_w),.exp_sum(sm_sum_w)
    );

    // ── Softmax controller ────────────────────────────────────
    wire           sm_ctrl_done_w;
    wire [DW-1:0]  ab_00,ab_01,ab_02,ab_03,ab_04,ab_05,ab_06,ab_07;
    wire [DW-1:0]  ab_10,ab_11,ab_12,ab_13,ab_14,ab_15,ab_16,ab_17;
    wire [DW-1:0]  ab_20,ab_21,ab_22,ab_23,ab_24,ab_25,ab_26,ab_27;
    wire [DW-1:0]  ab_30,ab_31,ab_32,ab_33,ab_34,ab_35,ab_36,ab_37;
    wire [DW-1:0]  ab_40,ab_41,ab_42,ab_43,ab_44,ab_45,ab_46,ab_47;
    wire [DW-1:0]  ab_50,ab_51,ab_52,ab_53,ab_54,ab_55,ab_56,ab_57;
    wire [DW-1:0]  ab_60,ab_61,ab_62,ab_63,ab_64,ab_65,ab_66,ab_67;
    wire [DW-1:0]  ab_70,ab_71,ab_72,ab_73,ab_74,ab_75,ab_76,ab_77;

    softmax_ctrl #(.N(N),.DW(DW)) u_sm_ctrl (
        .clk(clk),.rst_n(rst_n),
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
        .scaled_buf_74(sb_74),.scaled_buf_75(sb_75),.scaled_buf_76(sb_76),.scaled_buf_77(sb_77),
        .sm_start(sm_start_w),
        .sm_score_0(sm_s0),.sm_score_1(sm_s1),.sm_score_2(sm_s2),.sm_score_3(sm_s3),
        .sm_score_4(sm_s4),.sm_score_5(sm_s5),.sm_score_6(sm_s6),.sm_score_7(sm_s7),
        .sm_done(sm_done_w),
        .sm_weight_0(sm_w0),.sm_weight_1(sm_w1),.sm_weight_2(sm_w2),.sm_weight_3(sm_w3),
        .sm_weight_4(sm_w4),.sm_weight_5(sm_w5),.sm_weight_6(sm_w6),.sm_weight_7(sm_w7),
        .softmax_ctrl_done(sm_ctrl_done_w),
        .attn_buf_00(ab_00),.attn_buf_01(ab_01),.attn_buf_02(ab_02),.attn_buf_03(ab_03),
        .attn_buf_04(ab_04),.attn_buf_05(ab_05),.attn_buf_06(ab_06),.attn_buf_07(ab_07),
        .attn_buf_10(ab_10),.attn_buf_11(ab_11),.attn_buf_12(ab_12),.attn_buf_13(ab_13),
        .attn_buf_14(ab_14),.attn_buf_15(ab_15),.attn_buf_16(ab_16),.attn_buf_17(ab_17),
        .attn_buf_20(ab_20),.attn_buf_21(ab_21),.attn_buf_22(ab_22),.attn_buf_23(ab_23),
        .attn_buf_24(ab_24),.attn_buf_25(ab_25),.attn_buf_26(ab_26),.attn_buf_27(ab_27),
        .attn_buf_30(ab_30),.attn_buf_31(ab_31),.attn_buf_32(ab_32),.attn_buf_33(ab_33),
        .attn_buf_34(ab_34),.attn_buf_35(ab_35),.attn_buf_36(ab_36),.attn_buf_37(ab_37),
        .attn_buf_40(ab_40),.attn_buf_41(ab_41),.attn_buf_42(ab_42),.attn_buf_43(ab_43),
        .attn_buf_44(ab_44),.attn_buf_45(ab_45),.attn_buf_46(ab_46),.attn_buf_47(ab_47),
        .attn_buf_50(ab_50),.attn_buf_51(ab_51),.attn_buf_52(ab_52),.attn_buf_53(ab_53),
        .attn_buf_54(ab_54),.attn_buf_55(ab_55),.attn_buf_56(ab_56),.attn_buf_57(ab_57),
        .attn_buf_60(ab_60),.attn_buf_61(ab_61),.attn_buf_62(ab_62),.attn_buf_63(ab_63),
        .attn_buf_64(ab_64),.attn_buf_65(ab_65),.attn_buf_66(ab_66),.attn_buf_67(ab_67),
        .attn_buf_70(ab_70),.attn_buf_71(ab_71),.attn_buf_72(ab_72),.attn_buf_73(ab_73),
        .attn_buf_74(ab_74),.attn_buf_75(ab_75),.attn_buf_76(ab_76),.attn_buf_77(ab_77)
    );

    // ── attn_buf packed array for MAC2 feeding ────────────────
    wire [DW-1:0] attn_mat [0:N-1][0:N-1];
    assign attn_mat[0][0]=ab_00;assign attn_mat[0][1]=ab_01;assign attn_mat[0][2]=ab_02;assign attn_mat[0][3]=ab_03;
    assign attn_mat[0][4]=ab_04;assign attn_mat[0][5]=ab_05;assign attn_mat[0][6]=ab_06;assign attn_mat[0][7]=ab_07;
    assign attn_mat[1][0]=ab_10;assign attn_mat[1][1]=ab_11;assign attn_mat[1][2]=ab_12;assign attn_mat[1][3]=ab_13;
    assign attn_mat[1][4]=ab_14;assign attn_mat[1][5]=ab_15;assign attn_mat[1][6]=ab_16;assign attn_mat[1][7]=ab_17;
    assign attn_mat[2][0]=ab_20;assign attn_mat[2][1]=ab_21;assign attn_mat[2][2]=ab_22;assign attn_mat[2][3]=ab_23;
    assign attn_mat[2][4]=ab_24;assign attn_mat[2][5]=ab_25;assign attn_mat[2][6]=ab_26;assign attn_mat[2][7]=ab_27;
    assign attn_mat[3][0]=ab_30;assign attn_mat[3][1]=ab_31;assign attn_mat[3][2]=ab_32;assign attn_mat[3][3]=ab_33;
    assign attn_mat[3][4]=ab_34;assign attn_mat[3][5]=ab_35;assign attn_mat[3][6]=ab_36;assign attn_mat[3][7]=ab_37;
    assign attn_mat[4][0]=ab_40;assign attn_mat[4][1]=ab_41;assign attn_mat[4][2]=ab_42;assign attn_mat[4][3]=ab_43;
    assign attn_mat[4][4]=ab_44;assign attn_mat[4][5]=ab_45;assign attn_mat[4][6]=ab_46;assign attn_mat[4][7]=ab_47;
    assign attn_mat[5][0]=ab_50;assign attn_mat[5][1]=ab_51;assign attn_mat[5][2]=ab_52;assign attn_mat[5][3]=ab_53;
    assign attn_mat[5][4]=ab_54;assign attn_mat[5][5]=ab_55;assign attn_mat[5][6]=ab_56;assign attn_mat[5][7]=ab_57;
    assign attn_mat[6][0]=ab_60;assign attn_mat[6][1]=ab_61;assign attn_mat[6][2]=ab_62;assign attn_mat[6][3]=ab_63;
    assign attn_mat[6][4]=ab_64;assign attn_mat[6][5]=ab_65;assign attn_mat[6][6]=ab_66;assign attn_mat[6][7]=ab_67;
    assign attn_mat[7][0]=ab_70;assign attn_mat[7][1]=ab_71;assign attn_mat[7][2]=ab_72;assign attn_mat[7][3]=ab_73;
    assign attn_mat[7][4]=ab_74;assign attn_mat[7][5]=ab_75;assign attn_mat[7][6]=ab_76;assign attn_mat[7][7]=ab_77;

    // ── Output = MAC2 C_out ───────────────────────────────────
    assign out_00=C00;assign out_01=C01;assign out_02=C02;assign out_03=C03;
    assign out_04=C04;assign out_05=C05;assign out_06=C06;assign out_07=C07;
    assign out_10=C10;assign out_11=C11;assign out_12=C12;assign out_13=C13;
    assign out_14=C14;assign out_15=C15;assign out_16=C16;assign out_17=C17;
    assign out_20=C20;assign out_21=C21;assign out_22=C22;assign out_23=C23;
    assign out_24=C24;assign out_25=C25;assign out_26=C26;assign out_27=C27;
    assign out_30=C30;assign out_31=C31;assign out_32=C32;assign out_33=C33;
    assign out_34=C34;assign out_35=C35;assign out_36=C36;assign out_37=C37;
    assign out_40=C40;assign out_41=C41;assign out_42=C42;assign out_43=C43;
    assign out_44=C44;assign out_45=C45;assign out_46=C46;assign out_47=C47;
    assign out_50=C50;assign out_51=C51;assign out_52=C52;assign out_53=C53;
    assign out_54=C54;assign out_55=C55;assign out_56=C56;assign out_57=C57;
    assign out_60=C60;assign out_61=C61;assign out_62=C62;assign out_63=C63;
    assign out_64=C64;assign out_65=C65;assign out_66=C66;assign out_67=C67;
    assign out_70=C70;assign out_71=C71;assign out_72=C72;assign out_73=C73;
    assign out_74=C74;assign out_75=C75;assign out_76=C76;assign out_77=C77;

    // ── Top FSM ──────────────────────────────────────────────
    always @(posedge clk) begin
        if (!rst_n) begin
            state        <= IDLE;
            done         <= 0;
            mac_start_r  <= 0;
            mac_feeding  <= 0;
            mac_col_cnt  <= 0;
            mac_n_reg    <= N;
            mac_dk_reg   <= DK;
            mac_n_in     <= N;
            mac_dk_in    <= DK;
            mac_A0<=0;mac_A1<=0;mac_A2<=0;mac_A3<=0;
            mac_A4<=0;mac_A5<=0;mac_A6<=0;mac_A7<=0;
            mac_B0<=0;mac_B1<=0;mac_B2<=0;mac_B3<=0;
            mac_B4<=0;mac_B5<=0;mac_B6<=0;mac_B7<=0;
        end else begin
            done        <= 0;
            mac_start_r <= 0;

            case (state)

                // ── IDLE ─────────────────────────────────────
                IDLE: begin
                    mac_feeding <= 0;
                    mac_col_cnt <= 0;
                    if (start) begin
                        mac_n_reg  <= n_valid;
                        mac_dk_reg <= dk_valid;
                        mac_n_in   <= n_valid;
                        mac_dk_in  <= dk_valid;
                        mac_start_r <= 1;
                        state      <= MAC1;
                    end
                end

                // ── MAC1: Q x KT ──────────────────────────────
                // After start pulse, wait 1 cycle (CLEAR in array),
                // then feed DK columns of Q and K
                MAC1: begin
                    if (!mac_feeding && !mac_start_r) begin
                        // One cycle after start was sent
                        mac_feeding <= 1;
                        mac_col_cnt <= 0;
                    end

                    if (mac_feeding && mac_col_cnt < mac_dk_reg) begin
                        // Feed column mac_col_cnt of Q as A rows
                        mac_A0 <= Q_mat[0][mac_col_cnt];
                        mac_A1 <= Q_mat[1][mac_col_cnt];
                        mac_A2 <= Q_mat[2][mac_col_cnt];
                        mac_A3 <= Q_mat[3][mac_col_cnt];
                        mac_A4 <= Q_mat[4][mac_col_cnt];
                        mac_A5 <= Q_mat[5][mac_col_cnt];
                        mac_A6 <= Q_mat[6][mac_col_cnt];
                        mac_A7 <= Q_mat[7][mac_col_cnt];
                        // Feed column mac_col_cnt of K as B rows
                        // K[j][k] = KT[k][j] so this feeds KT correctly
                        mac_B0 <= K_mat[0][mac_col_cnt];
                        mac_B1 <= K_mat[1][mac_col_cnt];
                        mac_B2 <= K_mat[2][mac_col_cnt];
                        mac_B3 <= K_mat[3][mac_col_cnt];
                        mac_B4 <= K_mat[4][mac_col_cnt];
                        mac_B5 <= K_mat[5][mac_col_cnt];
                        mac_B6 <= K_mat[6][mac_col_cnt];
                        mac_B7 <= K_mat[7][mac_col_cnt];
                        mac_col_cnt <= mac_col_cnt + 1;
                    end else if (mac_feeding && mac_col_cnt >= mac_dk_reg) begin
                        // Clear inputs after feeding all DK columns
                        mac_A0<=0;mac_A1<=0;mac_A2<=0;mac_A3<=0;
                        mac_A4<=0;mac_A5<=0;mac_A6<=0;mac_A7<=0;
                        mac_B0<=0;mac_B1<=0;mac_B2<=0;mac_B3<=0;
                        mac_B4<=0;mac_B5<=0;mac_B6<=0;mac_B7<=0;
                    end

                    if (mac_done_w) begin
                        mac_feeding <= 0;
                        mac_col_cnt <= 0;
                        state       <= SCALE;
                    end
                end

                // ── SCALE ─────────────────────────────────────
                // scale_ctrl starts automatically on mac_done
                // Wait for scale_done
                SCALE: begin
                    if (scale_done_w)
                        state <= SOFTMAX;
                end

                // ── SOFTMAX ───────────────────────────────────
                // softmax_ctrl starts automatically on scale_done
                // Wait for softmax_ctrl_done
                SOFTMAX: begin
                    if (sm_ctrl_done_w) begin
                        // Prepare MAC2: Attn x V
                        mac_n_in  <= mac_n_reg;
                        mac_dk_in <= mac_n_reg; // dk for MAC2 = N (Attn is NxN)
                        mac_start_r <= 1;
                        mac_feeding <= 0;
                        mac_col_cnt <= 0;
                        state       <= MAC2;
                    end
                end

                // ── MAC2: Attn x V ────────────────────────────
                MAC2: begin
                    if (!mac_feeding && !mac_start_r) begin
                        mac_feeding <= 1;
                        mac_col_cnt <= 0;
                    end

                    if (mac_feeding && mac_col_cnt < mac_n_reg) begin
                        // Feed column mac_col_cnt of Attn as A rows
                        mac_A0 <= attn_mat[0][mac_col_cnt];
                        mac_A1 <= attn_mat[1][mac_col_cnt];
                        mac_A2 <= attn_mat[2][mac_col_cnt];
                        mac_A3 <= attn_mat[3][mac_col_cnt];
                        mac_A4 <= attn_mat[4][mac_col_cnt];
                        mac_A5 <= attn_mat[5][mac_col_cnt];
                        mac_A6 <= attn_mat[6][mac_col_cnt];
                        mac_A7 <= attn_mat[7][mac_col_cnt];
                        // Feed row mac_col_cnt of V as B cols
                        mac_B0 <= V_mat[mac_col_cnt][0];
                        mac_B1 <= V_mat[mac_col_cnt][1];
                        mac_B2 <= V_mat[mac_col_cnt][2];
                        mac_B3 <= V_mat[mac_col_cnt][3];
                        mac_B4 <= V_mat[mac_col_cnt][4];
                        mac_B5 <= V_mat[mac_col_cnt][5];
                        mac_B6 <= V_mat[mac_col_cnt][6];
                        mac_B7 <= V_mat[mac_col_cnt][7];
                        mac_col_cnt <= mac_col_cnt + 1;
                    end else if (mac_feeding && mac_col_cnt >= mac_n_reg) begin
                        mac_A0<=0;mac_A1<=0;mac_A2<=0;mac_A3<=0;
                        mac_A4<=0;mac_A5<=0;mac_A6<=0;mac_A7<=0;
                        mac_B0<=0;mac_B1<=0;mac_B2<=0;mac_B3<=0;
                        mac_B4<=0;mac_B5<=0;mac_B6<=0;mac_B7<=0;
                    end

                    if (mac_done_w) begin
                        mac_feeding <= 0;
                        state       <= DONE_ST;
                    end
                end

                // ── DONE ─────────────────────────────────────
                DONE_ST: begin
                    done  <= 1;
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
