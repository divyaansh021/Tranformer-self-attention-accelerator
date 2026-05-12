// ============================================================
// Module  : systolic_array
// Project : Transformer Attention Block Accelerator
// File    : systolic_array.v
//
// Description:
//   Complete 8x8 systolic matrix multiplier.
//   Computes C = A x B where A, B, C are up to 8x8 matrices.
//   Smaller sizes supported via n_valid / dk_valid — unused
//   lanes are zero-padded and zero-skip fires automatically.
//
//   Internal structure:
//     skew_chain u_skew_a  — delays A row i by i cycles
//     skew_chain u_skew_b  — delays B col j by j cycles
//     systolic_pe u_pe[i][j] — 8x8 = 64 PEs wired in grid
//     matmul_ctrl u_ctrl   — FSM: IDLE->CLEAR->RUN->DONE
//
//   Data flow:
//     A[i] enters left  of row i  (skewed by i cycles)
//     B[j] enters top   of col j  (skewed by j cycles)
//     a_out flows right across each row (1 cycle per PE)
//     b_out flows down  across each col (1 cycle per PE)
//     C[i][j] = dot(A row i, B col j) accumulates in PE[i][j]
//
//   Latency:
//     n_valid + dk_valid - 1 cycles after start
//     done pulses 1 cycle when C_out is valid
//
//   Fixed-point: Q8.8 (16-bit signed)
//   Accumulator: Q16.16 (32-bit), truncated to Q8.8 on output
//
// Parameters:
//   SIZE - max array dimension (default 8)
//   DW   - data width Q8.8    (default 16)
//
// Ports:
//   clk, rst_n         - clock, active-low reset
//   start              - 1-cycle pulse to begin multiply
//   n_valid            - actual N  (1-8)
//   dk_valid           - actual DK (1-8)
//   A_in[0..7]         - A row inputs  (zero-pad unused lanes)
//   B_in[0..7]         - B col inputs  (zero-pad unused lanes)
//   C_out[0..7][0..7]  - result matrix (read top-left NxN)
//   done               - 1-cycle pulse when C_out valid
//   running            - high during active computation
//   skip_count         - total zero-skips across all 64 PEs
// ============================================================

module systolic_array #(
    parameter SIZE = 8,
    parameter DW   = 16
)(
    input  wire        clk,
    input  wire        rst_n,

    // control
    input  wire        start,
    input  wire [3:0]  n_valid,
    input  wire [3:0]  dk_valid,

    // A row inputs (one element per row per cycle)
    input  wire [DW-1:0] A_in_0,
    input  wire [DW-1:0] A_in_1,
    input  wire [DW-1:0] A_in_2,
    input  wire [DW-1:0] A_in_3,
    input  wire [DW-1:0] A_in_4,
    input  wire [DW-1:0] A_in_5,
    input  wire [DW-1:0] A_in_6,
    input  wire [DW-1:0] A_in_7,

    // B col inputs (one element per col per cycle)
    input  wire [DW-1:0] B_in_0,
    input  wire [DW-1:0] B_in_1,
    input  wire [DW-1:0] B_in_2,
    input  wire [DW-1:0] B_in_3,
    input  wire [DW-1:0] B_in_4,
    input  wire [DW-1:0] B_in_5,
    input  wire [DW-1:0] B_in_6,
    input  wire [DW-1:0] B_in_7,

    // result matrix C[row][col]
    output wire [DW-1:0] C_out_00, C_out_01, C_out_02, C_out_03,
    output wire [DW-1:0] C_out_04, C_out_05, C_out_06, C_out_07,
    output wire [DW-1:0] C_out_10, C_out_11, C_out_12, C_out_13,
    output wire [DW-1:0] C_out_14, C_out_15, C_out_16, C_out_17,
    output wire [DW-1:0] C_out_20, C_out_21, C_out_22, C_out_23,
    output wire [DW-1:0] C_out_24, C_out_25, C_out_26, C_out_27,
    output wire [DW-1:0] C_out_30, C_out_31, C_out_32, C_out_33,
    output wire [DW-1:0] C_out_34, C_out_35, C_out_36, C_out_37,
    output wire [DW-1:0] C_out_40, C_out_41, C_out_42, C_out_43,
    output wire [DW-1:0] C_out_44, C_out_45, C_out_46, C_out_47,
    output wire [DW-1:0] C_out_50, C_out_51, C_out_52, C_out_53,
    output wire [DW-1:0] C_out_54, C_out_55, C_out_56, C_out_57,
    output wire [DW-1:0] C_out_60, C_out_61, C_out_62, C_out_63,
    output wire [DW-1:0] C_out_64, C_out_65, C_out_66, C_out_67,
    output wire [DW-1:0] C_out_70, C_out_71, C_out_72, C_out_73,
    output wire [DW-1:0] C_out_74, C_out_75, C_out_76, C_out_77,

    // status
    output wire        done,
    output wire        running,
    output wire [31:0] skip_count
);

    // --------------------------------------------------------
    // Internal wires
    // --------------------------------------------------------
    wire        acc_clr;
    wire [3:0]  cycle_cnt;

    // skew chain outputs — A rows and B cols after delay
    wire [DW-1:0] A_skew_0, A_skew_1, A_skew_2, A_skew_3;
    wire [DW-1:0] A_skew_4, A_skew_5, A_skew_6, A_skew_7;
    wire [DW-1:0] B_skew_0, B_skew_1, B_skew_2, B_skew_3;
    wire [DW-1:0] B_skew_4, B_skew_5, B_skew_6, B_skew_7;

    // PE interconnect: a_wire[row][col], b_wire[row][col]
    // a_wire[i][0] = skewed A row i input
    // a_wire[i][j+1] = PE[i][j].a_out  (flows right)
    // b_wire[0][j] = skewed B col j input
    // b_wire[i+1][j] = PE[i][j].b_out  (flows down)
    wire [DW-1:0] a_wire [0:SIZE-1][0:SIZE];
    wire [DW-1:0] b_wire [0:SIZE][0:SIZE-1];

    // PE outputs
    wire [DW-1:0] c_wire [0:SIZE-1][0:SIZE-1];
    wire          skip_wire [0:SIZE-1][0:SIZE-1];

    // --------------------------------------------------------
    // 1. FSM Controller
    // --------------------------------------------------------
    matmul_ctrl #(.SIZE(SIZE)) u_ctrl (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .n_valid  (n_valid),
        .dk_valid (dk_valid),
        .acc_clr  (acc_clr),
        .running  (running),
        .done     (done),
        .cycle_cnt()
    );

    // --------------------------------------------------------
    // 2. Skew chains — A rows and B cols
    // --------------------------------------------------------
    skew_chain #(.DW(DW)) u_skew_a (
        .clk   (clk), .rst_n(rst_n),
        .in_0(A_in_0), .in_1(A_in_1), .in_2(A_in_2), .in_3(A_in_3),
        .in_4(A_in_4), .in_5(A_in_5), .in_6(A_in_6), .in_7(A_in_7),
        .out_0(A_skew_0), .out_1(A_skew_1), .out_2(A_skew_2), .out_3(A_skew_3),
        .out_4(A_skew_4), .out_5(A_skew_5), .out_6(A_skew_6), .out_7(A_skew_7)
    );

    skew_chain #(.DW(DW)) u_skew_b (
        .clk   (clk), .rst_n(rst_n),
        .in_0(B_in_0), .in_1(B_in_1), .in_2(B_in_2), .in_3(B_in_3),
        .in_4(B_in_4), .in_5(B_in_5), .in_6(B_in_6), .in_7(B_in_7),
        .out_0(B_skew_0), .out_1(B_skew_1), .out_2(B_skew_2), .out_3(B_skew_3),
        .out_4(B_skew_4), .out_5(B_skew_5), .out_6(B_skew_6), .out_7(B_skew_7)
    );

    // --------------------------------------------------------
    // 3. Connect skew outputs to left/top PE inputs
    // --------------------------------------------------------
    assign a_wire[0][0] = A_skew_0;
    assign a_wire[1][0] = A_skew_1;
    assign a_wire[2][0] = A_skew_2;
    assign a_wire[3][0] = A_skew_3;
    assign a_wire[4][0] = A_skew_4;
    assign a_wire[5][0] = A_skew_5;
    assign a_wire[6][0] = A_skew_6;
    assign a_wire[7][0] = A_skew_7;

    assign b_wire[0][0] = B_skew_0;
    assign b_wire[0][1] = B_skew_1;
    assign b_wire[0][2] = B_skew_2;
    assign b_wire[0][3] = B_skew_3;
    assign b_wire[0][4] = B_skew_4;
    assign b_wire[0][5] = B_skew_5;
    assign b_wire[0][6] = B_skew_6;
    assign b_wire[0][7] = B_skew_7;

    // --------------------------------------------------------
    // 4. 8x8 PE grid — generate loop
    //    PE[i][j] :
    //      a_in  = a_wire[i][j]   (from left)
    //      a_out = a_wire[i][j+1] (to right)
    //      b_in  = b_wire[i][j]   (from above)
    //      b_out = b_wire[i+1][j] (to below)
    //      c_out = c_wire[i][j]   (result)
    // --------------------------------------------------------
    genvar gi, gj;
    generate
        for (gi = 0; gi < SIZE; gi = gi + 1) begin : row
            for (gj = 0; gj < SIZE; gj = gj + 1) begin : col

                systolic_pe #(.DW(DW)) u_pe (
                    .clk     (clk),
                    .rst_n   (rst_n),
                    .acc_clr (acc_clr),
                    .a_in    (a_wire[gi][gj]),
                    .b_in    (b_wire[gi][gj]),
                    .a_out   (a_wire[gi][gj+1]),
                    .b_out   (b_wire[gi+1][gj]),
                    .c_out   (c_wire[gi][gj]),
                    .skipped (skip_wire[gi][gj])
                );

            end
        end
    endgenerate

    // --------------------------------------------------------
    // 5. Skip counter — sum all 64 PE skip signals each cycle
    // --------------------------------------------------------
    reg [31:0] skip_cnt_reg;
    assign skip_count = skip_cnt_reg;

    integer si, sj;
    always @(posedge clk) begin
        if (!rst_n) begin
            skip_cnt_reg <= 32'd0;
        end else begin
            for (si = 0; si < SIZE; si = si + 1)
                for (sj = 0; sj < SIZE; sj = sj + 1)
                    if (skip_wire[si][sj])
                        skip_cnt_reg <= skip_cnt_reg + 1;
        end
    end

    // --------------------------------------------------------
    // 6. Map c_wire[i][j] to flat output ports
    //    Row 0
    // --------------------------------------------------------
    assign C_out_00 = c_wire[0][0]; assign C_out_01 = c_wire[0][1];
    assign C_out_02 = c_wire[0][2]; assign C_out_03 = c_wire[0][3];
    assign C_out_04 = c_wire[0][4]; assign C_out_05 = c_wire[0][5];
    assign C_out_06 = c_wire[0][6]; assign C_out_07 = c_wire[0][7];
    // Row 1
    assign C_out_10 = c_wire[1][0]; assign C_out_11 = c_wire[1][1];
    assign C_out_12 = c_wire[1][2]; assign C_out_13 = c_wire[1][3];
    assign C_out_14 = c_wire[1][4]; assign C_out_15 = c_wire[1][5];
    assign C_out_16 = c_wire[1][6]; assign C_out_17 = c_wire[1][7];
    // Row 2
    assign C_out_20 = c_wire[2][0]; assign C_out_21 = c_wire[2][1];
    assign C_out_22 = c_wire[2][2]; assign C_out_23 = c_wire[2][3];
    assign C_out_24 = c_wire[2][4]; assign C_out_25 = c_wire[2][5];
    assign C_out_26 = c_wire[2][6]; assign C_out_27 = c_wire[2][7];
    // Row 3
    assign C_out_30 = c_wire[3][0]; assign C_out_31 = c_wire[3][1];
    assign C_out_32 = c_wire[3][2]; assign C_out_33 = c_wire[3][3];
    assign C_out_34 = c_wire[3][4]; assign C_out_35 = c_wire[3][5];
    assign C_out_36 = c_wire[3][6]; assign C_out_37 = c_wire[3][7];
    // Row 4
    assign C_out_40 = c_wire[4][0]; assign C_out_41 = c_wire[4][1];
    assign C_out_42 = c_wire[4][2]; assign C_out_43 = c_wire[4][3];
    assign C_out_44 = c_wire[4][4]; assign C_out_45 = c_wire[4][5];
    assign C_out_46 = c_wire[4][6]; assign C_out_47 = c_wire[4][7];
    // Row 5
    assign C_out_50 = c_wire[5][0]; assign C_out_51 = c_wire[5][1];
    assign C_out_52 = c_wire[5][2]; assign C_out_53 = c_wire[5][3];
    assign C_out_54 = c_wire[5][4]; assign C_out_55 = c_wire[5][5];
    assign C_out_56 = c_wire[5][6]; assign C_out_57 = c_wire[5][7];
    // Row 6
    assign C_out_60 = c_wire[6][0]; assign C_out_61 = c_wire[6][1];
    assign C_out_62 = c_wire[6][2]; assign C_out_63 = c_wire[6][3];
    assign C_out_64 = c_wire[6][4]; assign C_out_65 = c_wire[6][5];
    assign C_out_66 = c_wire[6][6]; assign C_out_67 = c_wire[6][7];
    // Row 7
    assign C_out_70 = c_wire[7][0]; assign C_out_71 = c_wire[7][1];
    assign C_out_72 = c_wire[7][2]; assign C_out_73 = c_wire[7][3];
    assign C_out_74 = c_wire[7][4]; assign C_out_75 = c_wire[7][5];
    assign C_out_76 = c_wire[7][6]; assign C_out_77 = c_wire[7][7];

endmodule
