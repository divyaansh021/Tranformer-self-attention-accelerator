// ============================================================
// Module  : softmax
// Project : Transformer Attention Block Accelerator
// File    : softmax.v
//
// Description:
//   Computes softmax for one row of 8 scaled attention scores.
//   Input  : 8 scores in Q8.8 signed
//   Output : 8 attention weights in Q8.8 unsigned (sum ~= 0x0100)
//
//   Algorithm (numerically stable softmax):
//     1. max   = max(scores[0..7])              1 cycle
//     2. e[i]  = exp(scores[i] - max)  LUT      8+1 cycles
//     3. S     = sum(e[0..7])                   8 cycles
//     4. w[i]  = (e[i] * 256) / S      div      8*17 cycles
//
//   Division: 17-cycle restoring division
//     dividend = e[i] * 256  (17-bit max: 256*256=65536)
//     divisor  = S           (12-bit max: 8*256=2048)
//     quotient = w[i]        (8-bit max: 256 = 1.0 in Q8.8)
//
//   Total latency: ~158 cycles per row
//   (1 + 9 + 8 + 8*17 + 1 = 155 cycles)
//
// Ports:
//   clk, rst_n  - clock, active-low reset
//   start       - pulse to begin one row
//   score_*     - 8 scores Q8.8 signed
//   weight_*    - 8 weights Q8.8 unsigned (valid when done=1)
//   done        - 1-cycle pulse
//   row_max     - debug: row maximum value
//   exp_sum     - debug: sum of exp values
// ============================================================

module softmax #(
    parameter N  = 8,
    parameter DW = 16
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,

    input  wire signed [DW-1:0] score_0, score_1, score_2, score_3,
    input  wire signed [DW-1:0] score_4, score_5, score_6, score_7,

    output reg  [DW-1:0] weight_0, weight_1, weight_2, weight_3,
    output reg  [DW-1:0] weight_4, weight_5, weight_6, weight_7,

    output reg  done,

    output reg  signed [DW-1:0] row_max,
    output reg  [DW-1:0]        exp_sum
);

    // ── States ────────────────────────────────────────────────
    localparam IDLE     = 3'd0;
    localparam MAX_FIND = 3'd1;
    localparam EXP      = 3'd2;
    localparam SUM      = 3'd3;
    localparam DIV      = 3'd4;
    localparam DONE_ST  = 3'd5;

    reg [2:0] state;

    // ── Data storage ─────────────────────────────────────────
    reg signed [DW-1:0] scores   [0:N-1];
    reg        [DW-1:0] exp_vals [0:N-1];

    // ── Counters ─────────────────────────────────────────────
    reg [3:0] i_cnt;     // element index 0..N-1
    reg [4:0] bit_cnt;   // division bit 0..16

    // ── Exp LUT ───────────────────────────────────────────────
    reg  [7:0]  lut_idx;
    wire [DW-1:0] lut_out;
    exp_lut u_lut (.index(lut_idx), .exp_out(lut_out));

    // ── Division registers ────────────────────────────────────
    reg [17:0] div_rem;       // remainder (18-bit for safety)
    reg [DW-1:0] div_quotient; // quotient being built
    reg [16:0] div_dividend;   // current element's e[i]*256

    // ── max2 ─────────────────────────────────────────────────
    function signed [DW-1:0] max2;
        input signed [DW-1:0] a, b;
        begin max2 = (a > b) ? a : b; end
    endfunction

    // ── FSM ───────────────────────────────────────────────────
    always @(posedge clk) begin
        if (!rst_n) begin
            state      <= IDLE;
            done       <= 0;
            i_cnt      <= 0;
            bit_cnt    <= 0;
            row_max    <= 0;
            exp_sum    <= 0;
            lut_idx    <= 0;
            div_rem    <= 0;
            div_quotient <= 0;
            div_dividend <= 0;
        end else begin
            done <= 0;

            case (state)

                // ── IDLE ──────────────────────────────────────
                IDLE: begin
                    i_cnt <= 0;
                    if (start) begin
                        scores[0]<=score_0; scores[1]<=score_1;
                        scores[2]<=score_2; scores[3]<=score_3;
                        scores[4]<=score_4; scores[5]<=score_5;
                        scores[6]<=score_6; scores[7]<=score_7;
                        state <= MAX_FIND;
                    end
                end

                // ── MAX_FIND ──────────────────────────────────
                MAX_FIND: begin
                    begin : find_max
                        reg signed [DW-1:0] m01,m23,m45,m67,m0123,m4567;
                        m01   = max2(scores[0],scores[1]);
                        m23   = max2(scores[2],scores[3]);
                        m45   = max2(scores[4],scores[5]);
                        m67   = max2(scores[6],scores[7]);
                        m0123 = max2(m01,m23);
                        m4567 = max2(m45,m67);
                        row_max <= max2(m0123,m4567);
                    end
                    i_cnt   <= 0;
                    exp_sum <= 0;
                    state   <= EXP;
                end

                // ── EXP ───────────────────────────────────────
                // Cycle i: present LUT index for scores[i]
                //          store LUT output (1-cycle combinational delay)
                EXP: begin
                    begin : exp_step
                        reg signed [DW-1:0] diff;
                        reg [DW-1:0] abs_diff;
                        diff     = scores[i_cnt] - row_max;
                        abs_diff = diff[DW-1] ? (~diff + 1) : diff;
                        lut_idx  <= abs_diff[10:3]; // >>3 for 8-bit index
                    end

                    // store previous cycle's LUT output
                    if (i_cnt > 0)
                        exp_vals[i_cnt-1] <= lut_out;

                    if (i_cnt == N) begin
                        exp_vals[N-1] <= lut_out;
                        i_cnt <= 0;
                        state <= SUM;
                    end else
                        i_cnt <= i_cnt + 1;
                end

                // ── SUM ───────────────────────────────────────
                SUM: begin
                    exp_sum <= exp_sum + exp_vals[i_cnt];
                    if (i_cnt == N-1) begin
                        i_cnt   <= 0;
                        bit_cnt <= 0;
                        div_rem <= 0;
                        state   <= DIV;
                    end else
                        i_cnt <= i_cnt + 1;
                end

                // ── DIV ───────────────────────────────────────
                // weight[i] = (exp_vals[i] * 256) / exp_sum
                // 18-cycle per element:
                //   bit_cnt==0        : load dividend, clear rem (no compute)
                //   bit_cnt==1..17    : 17 restoring division steps
                //   after bit_cnt==17 : store result, advance element
                DIV: begin
                    if (bit_cnt == 0) begin
                        // Setup cycle: register dividend, clear state
                        // No division step this cycle (div_dividend just loading)
                        div_dividend <= {1'b0, exp_vals[i_cnt], 8'b0};
                        div_rem      <= 0;
                        div_quotient <= 0;
                        bit_cnt      <= 1;
                    end else begin
                        // Division step (bit_cnt 1..17)
                        begin : div_step
                            reg [17:0] shifted;
                            reg d_bit;
                            // bit_cnt=1 -> bit 16 (MSB), bit_cnt=17 -> bit 0 (LSB)
                            d_bit   = div_dividend[17 - bit_cnt];
                            shifted = (div_rem << 1) | d_bit;

                            if (shifted >= {2'b0, exp_sum}) begin
                                div_rem      <= shifted - {2'b0, exp_sum};
                                div_quotient <= (div_quotient << 1) | 1;
                            end else begin
                                div_rem      <= shifted;
                                div_quotient <= (div_quotient << 1);
                            end
                        end

                        if (bit_cnt == 17) begin
                            // Last bit done — store result
                            // div_quotient<<1|d_bit = completed quotient
                            begin : store_w
                                reg [DW-1:0] fq;
                                fq = (div_quotient << 1) | div_dividend[17-bit_cnt];
                                case (i_cnt)
                                    3'd0: weight_0 <= fq;
                                    3'd1: weight_1 <= fq;
                                    3'd2: weight_2 <= fq;
                                    3'd3: weight_3 <= fq;
                                    3'd4: weight_4 <= fq;
                                    3'd5: weight_5 <= fq;
                                    3'd6: weight_6 <= fq;
                                    3'd7: weight_7 <= fq;
                                endcase
                            end
                            bit_cnt <= 0;
                            div_rem <= 0;
                            if (i_cnt == N-1)
                                state <= DONE_ST;
                            else
                                i_cnt <= i_cnt + 1;
                        end else
                            bit_cnt <= bit_cnt + 1;
                    end
                end

                // ── DONE ──────────────────────────────────────
                DONE_ST: begin
                    done  <= 1;
                    i_cnt <= 0;
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
