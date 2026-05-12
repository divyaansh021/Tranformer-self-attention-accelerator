// ============================================================
// Module  : skew_chain
// Project : Transformer Attention Block Accelerator
// File    : skew_chain.v
//
// Description:
//   Input skewing for the 8x8 systolic array.
//   Lane i is delayed by i clock cycles using i registers.
//
//     out_0 = in_0  (0 cycles — direct wire)
//     out_1 = in_1  (1 cycle  delay)
//     out_2 = in_2  (2 cycles delay)
//     ...
//     out_7 = in_7  (7 cycles delay)
//
//   Used twice in systolic_array.v:
//     - A skew chain : row i delayed by i cycles
//     - B skew chain : col j delayed by j cycles
//
//   Hardware: 0+1+2+...+7 = 28 register stages per chain
//             28 x 16 bits = 448 flip-flops per chain
//
// Parameters:
//   DW - data width per lane (default 16 for Q8.8)
// ============================================================

module skew_chain #(
    parameter DW = 16
)(
    input  wire          clk,
    input  wire          rst_n,

    input  wire [DW-1:0] in_0,
    input  wire [DW-1:0] in_1,
    input  wire [DW-1:0] in_2,
    input  wire [DW-1:0] in_3,
    input  wire [DW-1:0] in_4,
    input  wire [DW-1:0] in_5,
    input  wire [DW-1:0] in_6,
    input  wire [DW-1:0] in_7,

    output wire [DW-1:0] out_0,
    output wire [DW-1:0] out_1,
    output wire [DW-1:0] out_2,
    output wire [DW-1:0] out_3,
    output wire [DW-1:0] out_4,
    output wire [DW-1:0] out_5,
    output wire [DW-1:0] out_6,
    output wire [DW-1:0] out_7
);

    // ── Lane 0 : 0 delays ────────────────────────────────
    assign out_0 = in_0;

    // ── Lane 1 : 1 register ──────────────────────────────
    wire [DW-1:0] l1_s1;
    register #(.N(DW),.INIT(0)) u_l1_s1 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(in_1),.q(l1_s1));
    assign out_1 = l1_s1;

    // ── Lane 2 : 2 registers ─────────────────────────────
    wire [DW-1:0] l2_s1, l2_s2;
    register #(.N(DW),.INIT(0)) u_l2_s1 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(in_2), .q(l2_s1));
    register #(.N(DW),.INIT(0)) u_l2_s2 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l2_s1),.q(l2_s2));
    assign out_2 = l2_s2;

    // ── Lane 3 : 3 registers ─────────────────────────────
    wire [DW-1:0] l3_s1, l3_s2, l3_s3;
    register #(.N(DW),.INIT(0)) u_l3_s1 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(in_3), .q(l3_s1));
    register #(.N(DW),.INIT(0)) u_l3_s2 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l3_s1),.q(l3_s2));
    register #(.N(DW),.INIT(0)) u_l3_s3 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l3_s2),.q(l3_s3));
    assign out_3 = l3_s3;

    // ── Lane 4 : 4 registers ─────────────────────────────
    wire [DW-1:0] l4_s1, l4_s2, l4_s3, l4_s4;
    register #(.N(DW),.INIT(0)) u_l4_s1 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(in_4), .q(l4_s1));
    register #(.N(DW),.INIT(0)) u_l4_s2 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l4_s1),.q(l4_s2));
    register #(.N(DW),.INIT(0)) u_l4_s3 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l4_s2),.q(l4_s3));
    register #(.N(DW),.INIT(0)) u_l4_s4 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l4_s3),.q(l4_s4));
    assign out_4 = l4_s4;

    // ── Lane 5 : 5 registers ─────────────────────────────
    wire [DW-1:0] l5_s1, l5_s2, l5_s3, l5_s4, l5_s5;
    register #(.N(DW),.INIT(0)) u_l5_s1 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(in_5), .q(l5_s1));
    register #(.N(DW),.INIT(0)) u_l5_s2 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l5_s1),.q(l5_s2));
    register #(.N(DW),.INIT(0)) u_l5_s3 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l5_s2),.q(l5_s3));
    register #(.N(DW),.INIT(0)) u_l5_s4 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l5_s3),.q(l5_s4));
    register #(.N(DW),.INIT(0)) u_l5_s5 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l5_s4),.q(l5_s5));
    assign out_5 = l5_s5;

    // ── Lane 6 : 6 registers ─────────────────────────────
    wire [DW-1:0] l6_s1, l6_s2, l6_s3, l6_s4, l6_s5, l6_s6;
    register #(.N(DW),.INIT(0)) u_l6_s1 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(in_6), .q(l6_s1));
    register #(.N(DW),.INIT(0)) u_l6_s2 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l6_s1),.q(l6_s2));
    register #(.N(DW),.INIT(0)) u_l6_s3 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l6_s2),.q(l6_s3));
    register #(.N(DW),.INIT(0)) u_l6_s4 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l6_s3),.q(l6_s4));
    register #(.N(DW),.INIT(0)) u_l6_s5 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l6_s4),.q(l6_s5));
    register #(.N(DW),.INIT(0)) u_l6_s6 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l6_s5),.q(l6_s6));
    assign out_6 = l6_s6;

    // ── Lane 7 : 7 registers ─────────────────────────────
    wire [DW-1:0] l7_s1, l7_s2, l7_s3, l7_s4, l7_s5, l7_s6, l7_s7;
    register #(.N(DW),.INIT(0)) u_l7_s1 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(in_7), .q(l7_s1));
    register #(.N(DW),.INIT(0)) u_l7_s2 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l7_s1),.q(l7_s2));
    register #(.N(DW),.INIT(0)) u_l7_s3 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l7_s2),.q(l7_s3));
    register #(.N(DW),.INIT(0)) u_l7_s4 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l7_s3),.q(l7_s4));
    register #(.N(DW),.INIT(0)) u_l7_s5 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l7_s4),.q(l7_s5));
    register #(.N(DW),.INIT(0)) u_l7_s6 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l7_s5),.q(l7_s6));
    register #(.N(DW),.INIT(0)) u_l7_s7 (.clk(clk),.rst_n(rst_n),.clr(1'b0),.en(1'b1),.d(l7_s6),.q(l7_s7));
    assign out_7 = l7_s7;

endmodule
