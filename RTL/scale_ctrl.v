// ============================================================
// Module  : scale_ctrl
// Project : Transformer Attention Block Accelerator
// File    : scale_ctrl.v
//
// Description:
//   Controller that serialises the 8x8 MAC output matrix and
//   feeds it element-by-element into scale.v.
//
//   When MAC done=1:
//     - Reads C_out_00..C_out_77 one element per cycle
//     - Drives score_in and valid_in on scale.v
//     - Stores scaled results in scaled_buf[row][col]
//     - Asserts scale_done after all 64 elements processed
//
//   Sequence: C[0][0], C[0][1]..C[0][7], C[1][0]..C[7][7]
//   (row-major order — matches softmax row-by-row requirement)
//
//   States:
//     IDLE    : wait for mac_done
//     RUNNING : count 0..63, mux C_out, drive scale.v
//     DONE    : assert scale_done for 1 cycle
//
// Ports:
//   clk, rst_n      - clock, active-low reset
//   mac_done        - 1-cycle pulse from systolic_array
//   dk              - head dimension (passed to scale.v)
//   C_out_*         - 64 score elements from MAC
//   scale_done      - 1-cycle pulse when all 64 scaled
//   scaled_buf_*    - 64 scaled outputs (valid after scale_done)
// ============================================================

module scale_ctrl #(
    parameter DW   = 16,
    parameter SIZE = 8
)(
    input  wire        clk,
    input  wire        rst_n,

    // from MAC unit
    input  wire        mac_done,
    input  wire [3:0]  dk,

    // 64 C_out ports from systolic_array (flat individual ports)
    input  wire [DW-1:0] C_out_00,C_out_01,C_out_02,C_out_03,
    input  wire [DW-1:0] C_out_04,C_out_05,C_out_06,C_out_07,
    input  wire [DW-1:0] C_out_10,C_out_11,C_out_12,C_out_13,
    input  wire [DW-1:0] C_out_14,C_out_15,C_out_16,C_out_17,
    input  wire [DW-1:0] C_out_20,C_out_21,C_out_22,C_out_23,
    input  wire [DW-1:0] C_out_24,C_out_25,C_out_26,C_out_27,
    input  wire [DW-1:0] C_out_30,C_out_31,C_out_32,C_out_33,
    input  wire [DW-1:0] C_out_34,C_out_35,C_out_36,C_out_37,
    input  wire [DW-1:0] C_out_40,C_out_41,C_out_42,C_out_43,
    input  wire [DW-1:0] C_out_44,C_out_45,C_out_46,C_out_47,
    input  wire [DW-1:0] C_out_50,C_out_51,C_out_52,C_out_53,
    input  wire [DW-1:0] C_out_54,C_out_55,C_out_56,C_out_57,
    input  wire [DW-1:0] C_out_60,C_out_61,C_out_62,C_out_63,
    input  wire [DW-1:0] C_out_64,C_out_65,C_out_66,C_out_67,
    input  wire [DW-1:0] C_out_70,C_out_71,C_out_72,C_out_73,
    input  wire [DW-1:0] C_out_74,C_out_75,C_out_76,C_out_77,

    // to scale.v (driven by this controller)
    output reg           valid_in,
    output reg  [DW-1:0] score_in,

    // from scale.v (routed back in)
    input  wire          valid_out,
    input  wire [DW-1:0] scaled_out,

    // status
    output reg           scale_done,

    // 64 scaled outputs — valid after scale_done
    output reg  [DW-1:0] scaled_buf_00,scaled_buf_01,scaled_buf_02,scaled_buf_03,
    output reg  [DW-1:0] scaled_buf_04,scaled_buf_05,scaled_buf_06,scaled_buf_07,
    output reg  [DW-1:0] scaled_buf_10,scaled_buf_11,scaled_buf_12,scaled_buf_13,
    output reg  [DW-1:0] scaled_buf_14,scaled_buf_15,scaled_buf_16,scaled_buf_17,
    output reg  [DW-1:0] scaled_buf_20,scaled_buf_21,scaled_buf_22,scaled_buf_23,
    output reg  [DW-1:0] scaled_buf_24,scaled_buf_25,scaled_buf_26,scaled_buf_27,
    output reg  [DW-1:0] scaled_buf_30,scaled_buf_31,scaled_buf_32,scaled_buf_33,
    output reg  [DW-1:0] scaled_buf_34,scaled_buf_35,scaled_buf_36,scaled_buf_37,
    output reg  [DW-1:0] scaled_buf_40,scaled_buf_41,scaled_buf_42,scaled_buf_43,
    output reg  [DW-1:0] scaled_buf_44,scaled_buf_45,scaled_buf_46,scaled_buf_47,
    output reg  [DW-1:0] scaled_buf_50,scaled_buf_51,scaled_buf_52,scaled_buf_53,
    output reg  [DW-1:0] scaled_buf_54,scaled_buf_55,scaled_buf_56,scaled_buf_57,
    output reg  [DW-1:0] scaled_buf_60,scaled_buf_61,scaled_buf_62,scaled_buf_63,
    output reg  [DW-1:0] scaled_buf_64,scaled_buf_65,scaled_buf_66,scaled_buf_67,
    output reg  [DW-1:0] scaled_buf_70,scaled_buf_71,scaled_buf_72,scaled_buf_73,
    output reg  [DW-1:0] scaled_buf_74,scaled_buf_75,scaled_buf_76,scaled_buf_77
);

    // --------------------------------------------------------
    // Pack all 64 C_out ports into an array for easy indexing
    // c_flat[i*8+j] = C_out[i][j]
    // --------------------------------------------------------
    wire [DW-1:0] c_flat [0:63];

    assign c_flat[0]  = C_out_00; assign c_flat[1]  = C_out_01;
    assign c_flat[2]  = C_out_02; assign c_flat[3]  = C_out_03;
    assign c_flat[4]  = C_out_04; assign c_flat[5]  = C_out_05;
    assign c_flat[6]  = C_out_06; assign c_flat[7]  = C_out_07;
    assign c_flat[8]  = C_out_10; assign c_flat[9]  = C_out_11;
    assign c_flat[10] = C_out_12; assign c_flat[11] = C_out_13;
    assign c_flat[12] = C_out_14; assign c_flat[13] = C_out_15;
    assign c_flat[14] = C_out_16; assign c_flat[15] = C_out_17;
    assign c_flat[16] = C_out_20; assign c_flat[17] = C_out_21;
    assign c_flat[18] = C_out_22; assign c_flat[19] = C_out_23;
    assign c_flat[20] = C_out_24; assign c_flat[21] = C_out_25;
    assign c_flat[22] = C_out_26; assign c_flat[23] = C_out_27;
    assign c_flat[24] = C_out_30; assign c_flat[25] = C_out_31;
    assign c_flat[26] = C_out_32; assign c_flat[27] = C_out_33;
    assign c_flat[28] = C_out_34; assign c_flat[29] = C_out_35;
    assign c_flat[30] = C_out_36; assign c_flat[31] = C_out_37;
    assign c_flat[32] = C_out_40; assign c_flat[33] = C_out_41;
    assign c_flat[34] = C_out_42; assign c_flat[35] = C_out_43;
    assign c_flat[36] = C_out_44; assign c_flat[37] = C_out_45;
    assign c_flat[38] = C_out_46; assign c_flat[39] = C_out_47;
    assign c_flat[40] = C_out_50; assign c_flat[41] = C_out_51;
    assign c_flat[42] = C_out_52; assign c_flat[43] = C_out_53;
    assign c_flat[44] = C_out_54; assign c_flat[45] = C_out_55;
    assign c_flat[46] = C_out_56; assign c_flat[47] = C_out_57;
    assign c_flat[48] = C_out_60; assign c_flat[49] = C_out_61;
    assign c_flat[50] = C_out_62; assign c_flat[51] = C_out_63;
    assign c_flat[52] = C_out_64; assign c_flat[53] = C_out_65;
    assign c_flat[54] = C_out_66; assign c_flat[55] = C_out_67;
    assign c_flat[56] = C_out_70; assign c_flat[57] = C_out_71;
    assign c_flat[58] = C_out_72; assign c_flat[59] = C_out_73;
    assign c_flat[60] = C_out_74; assign c_flat[61] = C_out_75;
    assign c_flat[62] = C_out_76; assign c_flat[63] = C_out_77;

    // --------------------------------------------------------
    // Pack scaled_buf into array for easy write-back
    // --------------------------------------------------------
    reg [DW-1:0] scaled_flat [0:63];

    // --------------------------------------------------------
    // State machine
    // --------------------------------------------------------
    localparam IDLE    = 2'd0;
    localparam RUNNING = 2'd1;
    localparam DONE    = 2'd2;

    reg [1:0]  state;
    reg [5:0]  send_cnt;   // 0..63 — which element to send to scale
    reg [5:0]  recv_cnt;   // 0..63 — which result to store from scale

    // --------------------------------------------------------
    // Main FSM
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state      <= IDLE;
            send_cnt   <= 0;
            recv_cnt   <= 0;
            valid_in   <= 0;
            score_in   <= 0;
            scale_done <= 0;
        end else begin
            scale_done <= 0;  // default

            case (state)

                // ── IDLE ────────────────────────────────────
                IDLE: begin
                    valid_in <= 0;
                    send_cnt <= 0;
                    recv_cnt <= 0;
                    if (mac_done)
                        state <= RUNNING;
                end

                // ── RUNNING ─────────────────────────────────
                // Each cycle: send one element to scale.v
                // One cycle later: receive scaled result back
                RUNNING: begin

                    // --- SEND side ---
                    if (send_cnt < 64) begin
                        valid_in <= 1;
                        score_in <= c_flat[send_cnt];
                        send_cnt <= send_cnt + 1;
                    end else begin
                        valid_in <= 0;
                        score_in <= 0;
                    end

                    // --- RECEIVE side (1 cycle delayed from send) ---
                    if (valid_out) begin
                        scaled_flat[recv_cnt] <= scaled_out;
                        recv_cnt <= recv_cnt + 1;
                    end

                    // All 64 results received → done
                    if (recv_cnt == 63 && valid_out)
                        state <= DONE;

                end

                // ── DONE ────────────────────────────────────
                DONE: begin
                    scale_done <= 1;
                    valid_in   <= 0;
                    send_cnt   <= 0;
                    recv_cnt   <= 0;
                    state      <= IDLE;
                end

            endcase
        end
    end

    // --------------------------------------------------------
    // Write scaled_flat back to named output ports
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            scaled_buf_00<=0; scaled_buf_01<=0; scaled_buf_02<=0; scaled_buf_03<=0;
            scaled_buf_04<=0; scaled_buf_05<=0; scaled_buf_06<=0; scaled_buf_07<=0;
            scaled_buf_10<=0; scaled_buf_11<=0; scaled_buf_12<=0; scaled_buf_13<=0;
            scaled_buf_14<=0; scaled_buf_15<=0; scaled_buf_16<=0; scaled_buf_17<=0;
            scaled_buf_20<=0; scaled_buf_21<=0; scaled_buf_22<=0; scaled_buf_23<=0;
            scaled_buf_24<=0; scaled_buf_25<=0; scaled_buf_26<=0; scaled_buf_27<=0;
            scaled_buf_30<=0; scaled_buf_31<=0; scaled_buf_32<=0; scaled_buf_33<=0;
            scaled_buf_34<=0; scaled_buf_35<=0; scaled_buf_36<=0; scaled_buf_37<=0;
            scaled_buf_40<=0; scaled_buf_41<=0; scaled_buf_42<=0; scaled_buf_43<=0;
            scaled_buf_44<=0; scaled_buf_45<=0; scaled_buf_46<=0; scaled_buf_47<=0;
            scaled_buf_50<=0; scaled_buf_51<=0; scaled_buf_52<=0; scaled_buf_53<=0;
            scaled_buf_54<=0; scaled_buf_55<=0; scaled_buf_56<=0; scaled_buf_57<=0;
            scaled_buf_60<=0; scaled_buf_61<=0; scaled_buf_62<=0; scaled_buf_63<=0;
            scaled_buf_64<=0; scaled_buf_65<=0; scaled_buf_66<=0; scaled_buf_67<=0;
            scaled_buf_70<=0; scaled_buf_71<=0; scaled_buf_72<=0; scaled_buf_73<=0;
            scaled_buf_74<=0; scaled_buf_75<=0; scaled_buf_76<=0; scaled_buf_77<=0;
        end else if (state == DONE) begin
            scaled_buf_00<=scaled_flat[0];  scaled_buf_01<=scaled_flat[1];
            scaled_buf_02<=scaled_flat[2];  scaled_buf_03<=scaled_flat[3];
            scaled_buf_04<=scaled_flat[4];  scaled_buf_05<=scaled_flat[5];
            scaled_buf_06<=scaled_flat[6];  scaled_buf_07<=scaled_flat[7];
            scaled_buf_10<=scaled_flat[8];  scaled_buf_11<=scaled_flat[9];
            scaled_buf_12<=scaled_flat[10]; scaled_buf_13<=scaled_flat[11];
            scaled_buf_14<=scaled_flat[12]; scaled_buf_15<=scaled_flat[13];
            scaled_buf_16<=scaled_flat[14]; scaled_buf_17<=scaled_flat[15];
            scaled_buf_20<=scaled_flat[16]; scaled_buf_21<=scaled_flat[17];
            scaled_buf_22<=scaled_flat[18]; scaled_buf_23<=scaled_flat[19];
            scaled_buf_24<=scaled_flat[20]; scaled_buf_25<=scaled_flat[21];
            scaled_buf_26<=scaled_flat[22]; scaled_buf_27<=scaled_flat[23];
            scaled_buf_30<=scaled_flat[24]; scaled_buf_31<=scaled_flat[25];
            scaled_buf_32<=scaled_flat[26]; scaled_buf_33<=scaled_flat[27];
            scaled_buf_34<=scaled_flat[28]; scaled_buf_35<=scaled_flat[29];
            scaled_buf_36<=scaled_flat[30]; scaled_buf_37<=scaled_flat[31];
            scaled_buf_40<=scaled_flat[32]; scaled_buf_41<=scaled_flat[33];
            scaled_buf_42<=scaled_flat[34]; scaled_buf_43<=scaled_flat[35];
            scaled_buf_44<=scaled_flat[36]; scaled_buf_45<=scaled_flat[37];
            scaled_buf_46<=scaled_flat[38]; scaled_buf_47<=scaled_flat[39];
            scaled_buf_50<=scaled_flat[40]; scaled_buf_51<=scaled_flat[41];
            scaled_buf_52<=scaled_flat[42]; scaled_buf_53<=scaled_flat[43];
            scaled_buf_54<=scaled_flat[44]; scaled_buf_55<=scaled_flat[45];
            scaled_buf_56<=scaled_flat[46]; scaled_buf_57<=scaled_flat[47];
            scaled_buf_60<=scaled_flat[48]; scaled_buf_61<=scaled_flat[49];
            scaled_buf_62<=scaled_flat[50]; scaled_buf_63<=scaled_flat[51];
            scaled_buf_64<=scaled_flat[52]; scaled_buf_65<=scaled_flat[53];
            scaled_buf_66<=scaled_flat[54]; scaled_buf_67<=scaled_flat[55];
            scaled_buf_70<=scaled_flat[56]; scaled_buf_71<=scaled_flat[57];
            scaled_buf_72<=scaled_flat[58]; scaled_buf_73<=scaled_flat[59];
            scaled_buf_74<=scaled_flat[60]; scaled_buf_75<=scaled_flat[61];
            scaled_buf_76<=scaled_flat[62]; scaled_buf_77<=scaled_flat[63];
        end
    end

endmodule
