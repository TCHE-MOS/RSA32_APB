
module rsa_core_mod #(
    parameter DATA_WIDTH = 32,
              D_WID      = (DATA_WIDTH-1),
              RESET      = 1,
              START      = 1
) (
    input  logic                    mod_clk,
    input  logic                    mod_rst,
    input  logic                    mod_start,
    input  logic [2*DATA_WIDTH-1:0] mod_a,
    input  logic [D_WID:0]   mod_b,
    output logic                    mod_done,
    output logic                    mod_err,
    output logic [D_WID:0]   mod_c
);

    // FSM state encoding:
    localparam [2:0] INIT     = 3'b000,
                     CHECK    = 3'b001,
                     PREPARE  = 3'b010,
                     COMPARE  = 3'b011,
                     SUBTRACT = 3'b100,
                     SHIFT    = 3'b101,
                     DONE     = 3'b110,
                     ERROR    = 3'b111;

    // FSM registers:
    logic [2:0] state_reg;
    logic [2:0] state_ns;

    // Datapath registers:
    logic [DATA_WIDTH:0]       a_cnt;
    logic [2*DATA_WIDTH-1:0] t_reg, n_reg;
    logic [D_WID:0]     r_reg;
    logic                     mod_done_ff, mod_err_ff;

    // Kogge-Stone subtraction result (2*DATA_WIDTH bits):
    logic [2*DATA_WIDTH-1:0] subtract_result;

    // Shared Kogge-Stone increment/decrement result (DATA_WIDTH+1 bits):
    localparam logic [DATA_WIDTH:0] CNT_ONE = {{DATA_WIDTH{1'b0}}, 1'b1};
    logic [DATA_WIDTH:0] count_result;
    logic [DATA_WIDTH:0] count_operand;
    logic                  count_sub;

    // --------------------------------------------------------
    // Output signal connections:
    // --------------------------------------------------------
    assign mod_done = mod_done_ff;
    assign mod_err  = mod_err_ff;
    assign mod_c    = r_reg;

    // --------------------------------------------------------
    // Kogge-Stone subtractor:
    // T - N = T + (~N) + 1
    // --------------------------------------------------------
    kogge_stone_adder #(
        .DATA_WIDTH(2*DATA_WIDTH)
    ) u_kogge_stone (
        .a_i    (t_reg),
        .b_i    (~n_reg),
        .cin_i  (1'b1),
        .sum_o  (subtract_result),
        .cout_o ()
    );

    // --------------------------------------------------------
    // Shared 33-bit Kogge-Stone counter for DATA_WIDTH=32:
    // PREPARE:          a_cnt + 1
    // SUBTRACT / SHIFT: a_cnt - 1 = a_cnt + (~1) + 1
    // --------------------------------------------------------
    assign count_sub = (state_reg == SUBTRACT) || (state_reg == SHIFT);
    assign count_operand = count_sub ? ~CNT_ONE : CNT_ONE;

    kogge_stone_adder #(
        .DATA_WIDTH(DATA_WIDTH+1)
    ) u_counter_kogge_stone (
        .a_i    (a_cnt),
        .b_i    (count_operand),
        .cin_i  (count_sub),
        .sum_o  (count_result),
        .cout_o ()
    );

    // --------------------------------------------------------
    // Next state decode logic:
    // --------------------------------------------------------
    always @(mod_rst, mod_start, t_reg, n_reg, a_cnt, state_reg)
        begin
            if (mod_rst == RESET)
                begin
                    state_ns = INIT;
                end
            else
                begin
                    case (state_reg)
                        INIT:
                            begin
                                if (mod_start == START)
                                    begin
                                        state_ns = CHECK;
                                    end
                                else
                                    begin
                                        state_ns = INIT;
                                    end
                            end

                        CHECK:
                            begin
                                if (n_reg[D_WID:0] == {DATA_WIDTH{1'b0}})
                                    begin
                                        state_ns = ERROR;
                                    end
                                else
                                    begin
                                        state_ns = PREPARE;
                                    end
                            end

                        PREPARE:
                            begin
                                if (n_reg[2*DATA_WIDTH-2] == 1'b0)
                                    begin
                                        state_ns = PREPARE;
                                    end
                                else
                                    begin
                                        state_ns = COMPARE;
                                    end
                            end

                        COMPARE:
                            begin
                                if (t_reg >= n_reg)
                                    begin
                                        state_ns = SUBTRACT;
                                    end
                                else
                                    begin
                                        state_ns = SHIFT;
                                    end
                            end

                        SUBTRACT:
                            begin
                                if (a_cnt != '0)
                                    begin
                                        state_ns = COMPARE;
                                    end
                                else
                                    begin
                                        state_ns = DONE;
                                    end
                            end

                        SHIFT:
                            begin
                                if (a_cnt != '0)
                                    begin
                                        state_ns = COMPARE;
                                    end
                                else
                                    begin
                                        state_ns = DONE;
                                    end
                            end

                        DONE:
                            begin
                                state_ns = INIT;
                            end

                        ERROR:
                            begin
                                state_ns = INIT;
                            end

                        default:
                            begin
                                state_ns = INIT;
                            end
                    endcase
                end
        end

    // --------------------------------------------------------
    // Sequential logic:
    // --------------------------------------------------------
    always_ff @(posedge mod_clk)
        begin
            case (state_reg)
                INIT:
                    begin
                        mod_done_ff                      <= 1'b0;
                        t_reg                            <= mod_a;
                        n_reg[D_WID:0]            <= mod_b;
                        n_reg[2*DATA_WIDTH-1:DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
                        a_cnt                            <= {DATA_WIDTH+1{1'b0}};
                    end

                CHECK:
                    begin
                        // No register transfers.
                    end

                PREPARE:
                    begin
                        a_cnt <= count_result;
                        n_reg <= {n_reg[2*DATA_WIDTH-2:0], 1'b0};
                    end

                COMPARE:
                    begin
                        // No register transfers.
                    end

                SUBTRACT:
                    begin
                        t_reg <= subtract_result;
                        n_reg <= {1'b0, n_reg[2*DATA_WIDTH-1:1]};
                        a_cnt <= count_result;
                    end

                SHIFT:
                    begin
                        n_reg <= {1'b0, n_reg[2*DATA_WIDTH-1:1]};
                        a_cnt <= count_result;
                    end

                DONE:
                    begin
                        r_reg       <= t_reg[D_WID:0];
                        mod_done_ff <= 1'b1;
                        mod_err_ff  <= 1'b0;
                    end

                ERROR:
                    begin
                        mod_err_ff  <= 1'b1;
                        mod_done_ff <= 1'b1;
                        r_reg       <= {DATA_WIDTH{1'b1}};
                    end

                default:
                    begin
                        // No register transfers.
                    end
            endcase

            state_reg <= state_ns;
        end

endmodule
