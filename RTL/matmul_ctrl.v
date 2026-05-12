// ============================================================
// Module  : matmul_ctrl
// Project : Transformer Attention Block Accelerator
// File    : matmul_ctrl.v
//
// Description:
//   FSM controller for the 8x8 systolic matrix multiplier.
//
//   State sequence for one matrix multiply:
//   IDLE  -> CLEAR -> RUN -> DONE -> IDLE
//
//   IMPORTANT: acc_clr is a COMBINATIONAL output (wire),
//   not registered. This ensures acc_clr=1 exactly during
//   the CLEAR state only, and drops to 0 on the very first
//   cycle of RUN so PE[0][0] captures its first product
//   correctly.
//
//   Latency formula:
//     RUN cycles = 2*n_valid + dk_valid - 2
//     This accounts for:
//       - dk_valid inner products per PE
//       - n_valid-1 extra cycles for skew chain pipeline depth
//         (PE[N-1][N-1] receives last data N-1 cycles after PE[0][0])
//
// Parameters:
//   SIZE - max array dimension (default 8)
//
// Ports:
//   clk       - clock
//   rst_n     - active-low synchronous reset
//   start     - 1-cycle pulse to begin multiply
//   n_valid   - actual N  (1 to SIZE) [4 bits]
//   dk_valid  - actual DK (1 to SIZE) [4 bits]
//   acc_clr   - COMBINATIONAL: high only when state==CLEAR
//   running   - high during RUN state
//   done      - 1-cycle pulse when C_out is valid
//   cycle_cnt - RUN counter for debug visibility
// ============================================================

module matmul_ctrl #(
    parameter SIZE = 8
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [3:0] n_valid,
    input  wire [3:0] dk_valid,
    output wire       acc_clr,    // COMBINATIONAL — not registered
    output reg        running,
    output reg        done,
    output reg  [4:0] cycle_cnt
);

    // ── State encoding ────────────────────────────────────
    localparam IDLE  = 2'b00;
    localparam CLEAR = 2'b01;
    localparam RUN   = 2'b10;
    localparam DONE  = 2'b11;

    reg [1:0] state;

    // ── Latency: 2*N + DK - 2 ────────────────────────────
    // Accounts for DK inner products AND N-1 skew pipeline depth
    wire [5:0] latency;
    assign latency = {1'b0, n_valid, 1'b0}       // 2*n_valid
                   + {2'b00, dk_valid}             // + dk_valid
                   - 6'd2;                         // - 2

    // ── acc_clr: combinational from state ─────────────────
    // HIGH only during CLEAR state — drops to 0 the very
    // first cycle RUN begins, so PE[0][0] captures correctly
    assign acc_clr = (state == CLEAR);

    // ── State + output register ───────────────────────────
    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= IDLE;
            running   <= 1'b0;
            done      <= 1'b0;
            cycle_cnt <= 5'd0;
        end
        else begin
            running <= 1'b0;
            done    <= 1'b0;

            case (state)

                IDLE: begin
                    cycle_cnt <= 5'd0;
                    if (start) state <= CLEAR;
                end

                CLEAR: begin
                    // acc_clr driven combinationally above
                    // transition to RUN next cycle
                    cycle_cnt <= 5'd0;
                    state     <= RUN;
                end

                RUN: begin
                    running <= 1'b1;
                    if (cycle_cnt == latency - 1) begin
                        cycle_cnt <= 5'd0;
                        state     <= DONE;
                    end
                    else begin
                        cycle_cnt <= cycle_cnt + 1'b1;
                    end
                end

                DONE: begin
                    done      <= 1'b1;
                    cycle_cnt <= 5'd0;
                    state     <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
