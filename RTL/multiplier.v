// ============================================================
// Module  : multiplier
// Library : Attention Accelerator Datapath Library
// File    : lib/multiplier.v
//
// Description:
//   Signed combinational multiplier.
//   Takes two AW-bit signed inputs, produces a (2*AW)-bit
//   signed product. No registered output — purely combinational.
//
//   Fixed-point use:
//     Q8.8 x Q8.8 → Q16.16 (32-bit product)
//     Caller selects relevant bits for truncation.
//
//   Hardware (Vivado/Xilinx):
//     Inferred as DSP48E1 slice for AW <= 18.
//     One DSP48 per instantiation.
//
// Parameters:
//   AW - input operand width in bits (default 16)
//   PW - product width = 2*AW (default 32)
//
// Ports:
//   a   - signed input operand A  (AW bits)
//   b   - signed input operand B  (AW bits)
//   p   - signed product output   (PW bits = 2*AW)
// ============================================================

module multiplier #(
    parameter AW = 16,
    parameter PW = 2*AW
)(
    input  wire signed [AW-1:0] a,
    input  wire signed [AW-1:0] b,
    output wire signed [PW-1:0] p
);

    // Signed multiplication — Vivado infers DSP48E1
    assign p = a * b;

endmodule
