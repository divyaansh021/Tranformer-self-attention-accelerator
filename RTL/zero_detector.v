// ============================================================
// Module  : zero_detector
// Library : Attention Accelerator Datapath Library
// File    : lib/zero_detector.v
//
// Description:
//   Detects whether an N-bit input is exactly zero.
//   Implements a NOR-tree reduction — output is 1 only
//   when ALL input bits are 0.
//
//   Hardware: synthesizes to a tree of NOR gates.
//   For N=16: 2 LUTs (each 6-input LUT covers 6 bits,
//   two levels cover 16 bits).
//   Purely combinational — no clock.
//
// Parameters:
//   N  - input width in bits (default 16)
//
// Ports:
//   in     - N-bit input to check
//   is_zero - 1 when in == 0, else 0
// ============================================================

module zero_detector #(
    parameter N = 16
)(
    input  wire [N-1:0] in,
    output wire         is_zero
);

    // NOR reduction — true when no bit is set
    assign is_zero = ~(|in);

endmodule
