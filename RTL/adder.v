// ============================================================
// Module  : adder
// Library : Attention Accelerator Datapath Library
// File    : lib/adder.v
//
// Description:
//   Signed combinational adder with carry-out.
//   Takes two N-bit signed inputs, produces an N-bit sum
//   and a 1-bit carry/overflow flag.
//   Purely combinational — no clock.
//
//   Use in MAC:
//     adder #(32) u_add (
//       .a(acc), .b(mux_out), .sum(acc_next), .cout()
//     );
//
//   Hardware:
//     Vivado maps to LUT-based carry-chain adder (CARRY4).
//     For N=32: 8 CARRY4 primitives.
//
// Parameters:
//   N  - operand width in bits (default 32)
//
// Ports:
//   a     - signed input A  (N bits)
//   b     - signed input B  (N bits)
//   sum   - signed output   (N bits)
//   cout  - carry out       (1 bit)  — tie off if unused
// ============================================================

module adder #(
    parameter N = 32
)(
    input  wire signed [N-1:0] a,
    input  wire signed [N-1:0] b,
    output wire signed [N-1:0] sum,
    output wire                cout
);

    // N-bit signed addition with carry
    assign {cout, sum} = {a[N-1], a} + {b[N-1], b};

endmodule
