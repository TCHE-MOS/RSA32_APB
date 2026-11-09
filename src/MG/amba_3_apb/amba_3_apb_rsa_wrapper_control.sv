module amba_3_apb_rsa_wrapper_control #(
    parameter   LOAD_GAP = 0,
                GAP_WIDTH = 1,
    parameter logic [GAP_WIDTH-1:0] GAP_LAST = '0,
    parameter logic [5:0] IDLE        = 6'b000000,
                          LOAD_MSG    = 6'b000001,
                          GAP_MSG_EXP = 6'b000010,
                          LOAD_EXP    = 6'b000100,
                          GAP_EXP_MOD = 6'b001000,
                          LOAD_MOD    = 6'b010000,
                          WAIT_DONE   = 6'b100000
)(
    // Clock and Reset:
    input  logic             pclk_i,
    input  logic             presetn_i,
    input  logic             rsa_rst_i,

    // FSM Commands and Events:
    input  logic             start_i,
    input  logic             core_done_i,
    input  logic             core_error_i,

    // FSM State:
    output logic [6:0]       c_state_o
);

// FSM State Registers:
logic [6:0] c_state, n_state;

// GAP Counter:
logic gap_counter;

// FSM State Output:
assign c_state_o = c_state;

// RSA Wrapper FSM Control Path:
always_comb
    begin
        n_state = c_state;

        case (c_state)
            IDLE:
                begin
                    if (start_i && !rsa_rst_i)
                        begin
                            n_state = LOAD_MSG;
                        end
                    else
                        begin
                            n_state = IDLE;
                        end
                end

            LOAD_MSG:
                begin
                    if (LOAD_GAP == 0)
                        begin
                            n_state = LOAD_EXP;
                        end
                    else
                        begin
                            n_state = GAP_MSG_EXP;
                        end
                end

            GAP_MSG_EXP:
                begin
                    if (gap_counter == GAP_LAST)
                        begin
                            n_state = LOAD_EXP;
                        end
                    else
                        begin
                            n_state = GAP_MSG_EXP;
                        end
                end

            LOAD_EXP:
                begin
                    if (LOAD_GAP == 0)
                        begin
                            n_state = LOAD_MOD;
                        end
                    else
                        begin
                            n_state = GAP_EXP_MOD;
                        end
                end

            GAP_EXP_MOD:
                begin
                    if (gap_counter == GAP_LAST)
                        begin
                            n_state = LOAD_MOD;
                        end
                    else
                        begin
                            n_state = GAP_EXP_MOD;
                        end
                end

            LOAD_MOD:
                begin
                    n_state = WAIT_DONE;
                end

            WAIT_DONE:
                begin
                    if (core_done_i || core_error_i)
                        begin
                            n_state = IDLE;
                        end
                    else
                        begin
                            n_state = WAIT_DONE;
                        end
                end

            default:
                begin
                    n_state = IDLE;
                end
        endcase
    end

// RSA Wrapper FSM State and GAP Counter:
always_ff @(posedge pclk_i or negedge presetn_i)
    begin
        if (!presetn_i)
            begin
                c_state     <= IDLE;
                gap_counter <= '0;
            end
        else if (rsa_rst_i)
            begin
                c_state     <= IDLE;
                gap_counter <= '0;
            end
        else
            begin
                c_state <= n_state;

                if ((c_state == GAP_MSG_EXP) || (c_state == GAP_EXP_MOD))
                    begin
                        if (gap_counter == GAP_LAST)
                            begin
                                gap_counter <= '0;
                            end

                        else
                            begin
                                gap_counter <= GAP_WIDTH'(gap_counter + 1'b1);
                            end
                    end
                else
                    begin
                        gap_counter <= '0;
                    end
            end
    end

endmodule: amba_3_apb_rsa_wrapper_control