// ============================================================
// Module  : scale
// Project : Transformer Attention Block Accelerator
// File    : scale.v
//
// Description:
//   Scales attention scores by 1/sqrt(dk).
//   Step 2 of attention pipeline: scores → scaled → softmax
//
//   Why we scale:
//     Raw dot products Q*K^T grow with dk.
//     Dividing by sqrt(dk) prevents softmax saturation.
//
//   Fixed-point arithmetic:
//     Input  : Q8.8  signed (16-bit)
//     Recip  : Q1.15 unsigned (16-bit) precomputed 1/sqrt(dk)
//     Product: Q9.23 signed (32-bit intermediate)
//     Output : Q8.8  signed (16-bit) = product[30:15]
//
//   Why product[30:15]:
//     Q8.8 x Q1.15 = Q9.23 (32-bit)
//     To recover Q8.8: arithmetic right-shift by 15
//     product[30:15] = bits 30 downto 15 = >>15
//
//   Reciprocal LUT — 1/sqrt(dk) in Q1.15, ALL dk=1..8:
//     dk=1: 1.0000  0x8000  error=0.000%
//     dk=2: 0.7071  0x5A82  error=0.002%
//     dk=3: 0.5774  0x49E7  error=0.002%
//     dk=4: 0.5000  0x4000  error=0.000% (exact)
//     dk=5: 0.4472  0x393E  error=0.002%
//     dk=6: 0.4082  0x3441  error=0.004%
//     dk=7: 0.3780  0x3061  error=0.001%
//     dk=8: 0.3536  0x2D41  error=0.002%
//   All errors < Q8.8 resolution (0.39%) — negligible.
//
//   Pipeline: 1 cycle latency
//     Cycle N  : valid_in=1, score_in presented
//     Cycle N+1: valid_out=1, scaled_out valid
//
// Ports:
//   clk        - clock
//   rst_n      - active-low synchronous reset
//   valid_in   - score_in is valid this cycle
//   score_in   - one score element [Q8.8 signed, 16-bit]
//   dk         - head dimension 1..8  [4-bit]
//   scaled_out - score / sqrt(dk)  [Q8.8 signed, 16-bit]
//   valid_out  - scaled_out valid (registered, 1 cycle later)
// ============================================================

module scale #(
    parameter DW = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  valid_in,
    input  wire signed [DW-1:0]  score_in,
    input  wire [3:0]            dk,
    output reg  signed [DW-1:0]  scaled_out,
    output reg                   valid_out
);

    // --------------------------------------------------------
    // Reciprocal LUT — 1/sqrt(dk) in Q1.15
    // All values dk=1 through dk=8 supported
    // --------------------------------------------------------
    reg [15:0] recip;

    always @(*) begin
        case (dk)
            4'd1:    recip = 16'h8000; // 1/sqrt(1) = 1.0000
            4'd2:    recip = 16'h5A82; // 1/sqrt(2) = 0.7071
            4'd3:    recip = 16'h49E7; // 1/sqrt(3) = 0.5774
            4'd4:    recip = 16'h4000; // 1/sqrt(4) = 0.5000
            4'd5:    recip = 16'h393E; // 1/sqrt(5) = 0.4472
            4'd6:    recip = 16'h3441; // 1/sqrt(6) = 0.4082
            4'd7:    recip = 16'h3061; // 1/sqrt(7) = 0.3780
            4'd8:    recip = 16'h2D41; // 1/sqrt(8) = 0.3536
            default: recip = 16'h2D41; // fallback dk=8
        endcase
    end

    // --------------------------------------------------------
    // Multiply: Q8.8 signed x Q1.15 unsigned = Q9.23 signed
    // Take bits [30:15] to recover Q8.8
    // --------------------------------------------------------
    wire signed [31:0] product;
    assign product = score_in * $signed({1'b0, recip});

    // --------------------------------------------------------
    // 1-cycle pipeline register
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            scaled_out <= 0;
            valid_out  <= 0;
        end else begin
            valid_out  <= valid_in;
            scaled_out <= valid_in ? product[30:15] : 16'sd0;
        end
    end

endmodule
