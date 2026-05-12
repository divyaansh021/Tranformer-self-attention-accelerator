// ============================================================
// Module  : register
// Library : Attention Accelerator Datapath Library
// File    : lib/register.v
//
// Description:
//   Parameterised D flip-flop register with:
//     - synchronous active-low reset (rst_n)
//     - synchronous clear (clr) — sets output to 0
//     - clock enable (en)  — holds value when en=0
//
//   Used for:
//     - 32-bit accumulator (ACC) in the PE
//     - 16-bit pass-through registers (a_out, b_out)
//     - Skew delay chain registers in systolic array
//
//   Hardware:
//     N flip-flops with CE (clock enable) and R (reset).
//     Vivado maps directly to FDRE primitives.
//
// Parameters:
//   N    - register width in bits (default 16)
//   INIT - reset/clear value     (default 0)
//
// Ports:
//   clk   - clock (rising edge)
//   rst_n - active-low synchronous reset
//   clr   - synchronous clear (overrides en, sets to INIT)
//   en    - clock enable (1 = update, 0 = hold)
//   d     - data input   (N bits)
//   q     - data output  (N bits)
// ============================================================

module register #(
    parameter N    = 16,
    parameter INIT = 0
)(
    input  wire           clk,
    input  wire           rst_n,
    input  wire           clr,
    input  wire           en,
    input  wire [N-1:0]   d,
    output reg  [N-1:0]   q
);

    always @(posedge clk) begin
        if (!rst_n) begin
            // synchronous reset — highest priority
            q <= INIT[N-1:0];
        end
        else if (clr) begin
            // synchronous clear — e.g. acc_clr between matrices
            q <= INIT[N-1:0];
        end
        else if (en) begin
            // normal capture when enabled
            q <= d;
        end
        // else: hold — q unchanged
    end

endmodule
