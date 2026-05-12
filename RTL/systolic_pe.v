// ============================================================
// Module  : systolic_pe
// Project : Transformer Attention Block Accelerator
// File    : systolic_pe.v
//
// Description:
//   Single Processing Element (PE) for the 8x8 systolic array.
//   STRUCTURAL implementation — instantiates datapath library
//   modules explicitly:
//
//     zero_detector  x2  — detect zero on a_in, b_in
//     mux2           x1  — gate multiplier output (zero-skip)
//     multiplier     x1  — 16x16 signed multiply -> 32-bit
//     adder          x1  — 32-bit accumulate
//     register       x3  — ACC (32b), a_out (16b), b_out (16b)
//
//   Fixed-point: Q8.8 input, Q16.16 accumulator, Q8.8 output
//   Truncation : c_out = acc[23:8]  (zero hardware, wires only)
//
// Parameters:
//   DW  - data width (default 16 for Q8.8)
//   AW  - accumulator width (default 32 = 2*DW)
// ============================================================


module systolic_pe #(
    parameter DW = 16,
    parameter AW = 32
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          acc_clr,
    input  wire [DW-1:0] a_in,
    input  wire [DW-1:0] b_in,
    output wire [DW-1:0] a_out,
    output wire [DW-1:0] b_out,
    output wire [DW-1:0] c_out,
    output wire          skipped
);

    // --------------------------------------------------------
    // Internal wires
    // --------------------------------------------------------
    wire          a_zero;
    wire          b_zero;
    wire          skip;
    wire [AW-1:0] product;
    wire [AW-1:0] mux_out;
    wire [AW-1:0] acc;
    wire [AW-1:0] acc_next;
    wire          add_cout;

    // --------------------------------------------------------
    // 1. Zero detectors (NOR tree — combinational)
    // --------------------------------------------------------
    zero_detector #(.N(DW)) u_zdet_a (
        .in      (a_in),
        .is_zero (a_zero)
    );

    zero_detector #(.N(DW)) u_zdet_b (
        .in      (b_in),
        .is_zero (b_zero)
    );

    assign skip    = a_zero | b_zero;
    assign skipped = skip;

    // --------------------------------------------------------
    // 2. Multiplier (16x16 signed -> 32-bit, DSP48 in FPGA)
    // --------------------------------------------------------
    multiplier #(.AW(DW), .PW(AW)) u_mul (
        .a (a_in),
        .b (b_in),
        .p (product)
    );

    // --------------------------------------------------------
    // 3. MUX — zero-skip gate
    //    skip=0 -> pass product to adder (compute)
    //    skip=1 -> pass zero  to adder (accumulator unchanged)
    // --------------------------------------------------------
    mux2 #(.N(AW)) u_mux (
        .sel (skip),
        .in0 (product),
        .in1 ({AW{1'b0}}),
        .out (mux_out)
    );

    // --------------------------------------------------------
    // 4. Adder (32-bit signed, CARRY4 chain in FPGA)
    // --------------------------------------------------------
    adder #(.N(AW)) u_add (
        .a    (acc),
        .b    (mux_out),
        .sum  (acc_next),
        .cout (add_cout)
    );

    // --------------------------------------------------------
    // 5. Accumulator register (32-bit, clr = acc_clr)
    // --------------------------------------------------------
    register #(.N(AW), .INIT(0)) u_acc (
        .clk   (clk),
        .rst_n (rst_n),
        .clr   (acc_clr),
        .en    (1'b1),
        .d     (acc_next),
        .q     (acc)
    );

    // --------------------------------------------------------
    // 6. Output truncation Q16.16 -> Q8.8 (wires only, no LUTs)
    //    acc[23:16] = integer part
    //    acc[15: 8] = fraction part
    // --------------------------------------------------------
    assign c_out = acc[23:8];

    // --------------------------------------------------------
    // 7. Systolic pass-through registers
    //    a_out: a_in delayed 1 cycle -> feeds PE to the right
    //    b_out: b_in delayed 1 cycle -> feeds PE below
    // --------------------------------------------------------
    register #(.N(DW), .INIT(0)) u_areg (
        .clk   (clk),
        .rst_n (rst_n),
        .clr   (1'b0),
        .en    (1'b1),
        .d     (a_in),
        .q     (a_out)
    );

    register #(.N(DW), .INIT(0)) u_breg (
        .clk   (clk),
        .rst_n (rst_n),
        .clr   (1'b0),
        .en    (1'b1),
        .d     (b_in),
        .q     (b_out)
    );

endmodule
