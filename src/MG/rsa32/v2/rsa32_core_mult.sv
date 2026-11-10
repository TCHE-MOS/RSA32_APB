
 // ============================================================
 // Module: rsa_core_mult
 // ============================================================
module rsa_core_mult #(
    parameter DATA_WIDTH = 32,
              D_WID      = (DATA_WIDTH-1),
              RESET      = 1,
              START      = 1
) (
    input                       mult_clk,
    input                       mult_rst,
    input                       mult_start,
    input  [D_WID:0]     mult_a,
    input  [D_WID:0]     mult_b,
    output                      mult_done,
    output [2*DATA_WIDTH-1:0] mult_c
);

    // FSM state encoding:
    localparam [2:0] INIT      = 3'd0,
                     ANALYZE   = 3'd1,
                     SHIFT_ADD = 3'd2,
                     SHIFT     = 3'd3,
                     DONE      = 3'd4;

    // FSM registers:
    logic [2:0] state_reg;
    logic [2:0] state_ns;

    // Counter parameters:
    localparam int unsigned CNT_WIDTH = $clog2(DATA_WIDTH+1);
    localparam logic [CNT_WIDTH-1:0] CNT_LAST = CNT_WIDTH'(D_WID);

    // Datapath registers:
    logic [CNT_WIDTH-1:0] a_cnt;
    logic [CNT_WIDTH-1:0] a_cnt_inc;
    logic [D_WID:0] a_reg, b_reg;
    logic [2*DATA_WIDTH-1:0] p_reg, c_reg;
    logic done_ff;

    // Kogge-Stone result:
    logic [2*DATA_WIDTH-1:0] shift_add_result;
    logic cout_w;

    // --------------------------------------------------------
    // Output signal connections:
    // --------------------------------------------------------
    assign mult_done = done_ff;
    assign mult_c    = c_reg;

    // --------------------------------------------------------
    // Kogge-Stone Adder:
    // --------------------------------------------------------
    kogge_stone_adder #(
        .DATA_WIDTH(2*DATA_WIDTH)
    ) u_kogge_stone (
        .a_i    ({{DATA_WIDTH{1'b0}}, a_reg}),
        .b_i    ({p_reg[2*DATA_WIDTH-2:0], 1'b0}),
        .cin_i  (1'b0),
        .sum_o  (shift_add_result),
        .cout_o (cout_w)
    );

    // --------------------------------------------------------
    // Fixed-width counter incrementer:
    // a_cnt_inc = (a_cnt + 1) mod 2**CNT_WIDTH
    // --------------------------------------------------------
    assign a_cnt_inc[0] = ~a_cnt[0];

    generate
        for (genvar i = 1; i < CNT_WIDTH; i = i + 1)
            begin : gen_counter_increment
                assign a_cnt_inc[i] = a_cnt[i] ^ (&a_cnt[i-1:0]);
            end
    endgenerate

    // --------------------------------------------------------
    // Next state decode logic:
    // --------------------------------------------------------
    always @(mult_rst, mult_start, b_reg[D_WID], a_cnt, state_reg)
        begin
            if (mult_rst == RESET)
                begin
                    state_ns = INIT;
                end
            else
                begin
                    case (state_reg)
                        INIT:
                            state_ns = (mult_start == START) ? ANALYZE : INIT;

                        ANALYZE:
                            state_ns = (b_reg[D_WID]) ? SHIFT_ADD : SHIFT;

                        SHIFT_ADD:
                            begin
                                if (a_cnt != CNT_LAST)
                                    begin
                                        state_ns = (b_reg[D_WID]) ? SHIFT_ADD : SHIFT;
                                    end
                                else
                                    begin
                                        state_ns = DONE;
                                    end
                            end

                        SHIFT:
                            begin
                                if (a_cnt != CNT_LAST)
                                    begin
                                        state_ns = (b_reg[D_WID]) ? SHIFT_ADD : SHIFT;
                                    end
                                else
                                    begin
                                        state_ns = DONE;
                                    end
                            end

                        DONE:
                            state_ns = INIT;

                        default:
                            state_ns = INIT;
                    endcase
                end
        end

    // --------------------------------------------------------
    // Sequential logic:
    // --------------------------------------------------------
    always_ff @(posedge mult_clk)
        begin
            case (state_reg)
                INIT:
                    begin
                        p_reg   <= 0;
                        a_cnt   <= 0;
                        done_ff <= 1'b0;
                        a_reg   <= mult_a;
                        b_reg   <= mult_b;
                    end

                ANALYZE:
                    begin
                        b_reg <= {b_reg[DATA_WIDTH-2:0], 1'b0};
                    end

                SHIFT_ADD:
                    begin
                        p_reg <= shift_add_result;
                        a_cnt <= a_cnt_inc;
                        b_reg <= {b_reg[DATA_WIDTH-2:0], 1'b0};
                    end

                SHIFT:
                    begin
                        p_reg <= {p_reg[2*DATA_WIDTH-2:0], 1'b0};
                        a_cnt <= a_cnt_inc;
                        b_reg <= {b_reg[DATA_WIDTH-2:0], 1'b0};
                    end

                DONE:
                    begin
                        done_ff <= 1'b1;
                        c_reg   <= p_reg;
                    end
            endcase

            state_reg <= state_ns;
        end

endmodule