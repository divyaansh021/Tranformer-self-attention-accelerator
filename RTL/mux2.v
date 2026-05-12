// ============================================================
// Module  : mux2
// Library : Attention Accelerator Datapath Library
// File    : lib/mux2.v
//
// Description:
//   Parameterised 2-to-1 multiplexer.
//   Used in the zero-skip path to gate the multiplier
//   output before the accumulator adder.
//
//   Zero-skip use:
//     sel = skip signal (1 = zero input detected)
//     in0 = product from multiplier  (normal compute)
//     in1 = 0                        (skip — pass zero)
//     out = fed into adder input B
//
//   When sel=1 (skip): adder gets 0 → accumulator unchanged.
//   When sel=0 (compute): adder gets real product.
//
//   Hardware:
//     Vivado maps to LUT2/LUT4 based on width.
//     For N=32: ~8 LUTs.
//
// Parameters:
//   N  - data width in bits (default 32)
//
// Ports:
//   sel - select line (0 = in0, 1 = in1)
//   in0 - input when sel=0
//   in1 - input when sel=1
//   out - selected output
// ============================================================

module mux2 #(
    parameter N = 32
)(
    input  wire           sel,
    input  wire [N-1:0]   in0,
    input  wire [N-1:0]   in1,
    output wire [N-1:0]   out
);

    assign out = sel ? in1 : in0;

endmodule
