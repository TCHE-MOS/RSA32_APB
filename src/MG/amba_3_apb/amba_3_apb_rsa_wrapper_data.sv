module amba_3_apb_rsa_wrapper_data #(
    parameter   DATA_WIDTH = 32,
                D_WID = DATA_WIDTH - 1,
    parameter logic [5:0]   IDLE        = 6'b000000,
                            LOAD_MSG    = 6'b000001,
                            GAP_MSG_EXP = 6'b000010,
                            LOAD_EXP    = 6'b000100,
                            GAP_EXP_MOD = 6'b001000,
                            LOAD_MOD    = 6'b010000,
                            WAIT_DONE   = 6'b100000
)(
    // FSM State and Reset:
    input  logic             rsa_rst_i,
    input  logic [6:0]       c_state_i,

    // RSA Operands:
    input  logic [D_WID:0]   op_msg_i,
    input  logic [D_WID:0]   op_exp_i,
    input  logic [D_WID:0]   op_mod_i,

    // RSA Core Data Path:
    output logic             core_load_o,
    output logic [D_WID:0]   core_din_o,

    // RSA Wrapper Status:
    output logic             rsa_wp_busy_o
);

// RSA Wrapper FSM Data Path:
always_comb
    begin
        if (rsa_rst_i)
            begin
                core_load_o   = '0;
                core_din_o    = '0;
                rsa_wp_busy_o = '0;
            end
        else
            begin
                case (c_state_i)
                    IDLE:
                        begin
                            core_load_o   = '0;
                            core_din_o    = '0;
                            rsa_wp_busy_o = '0;
                        end

                    LOAD_MSG:
                        begin
                            core_load_o   = 1'b1;
                            core_din_o    = op_msg_i;
                            rsa_wp_busy_o = 1'b1;
                        end

                    GAP_MSG_EXP:
                        begin
                            core_load_o   = '0;
                            core_din_o    = '0;
                            rsa_wp_busy_o = 1'b1;
                        end

                    LOAD_EXP:
                        begin
                            core_load_o   = 1'b1;
                            core_din_o    = op_exp_i;
                            rsa_wp_busy_o = 1'b1;
                        end

                    GAP_EXP_MOD:
                        begin
                            core_load_o   = '0;
                            core_din_o    = '0;
                            rsa_wp_busy_o = 1'b1;
                        end

                    LOAD_MOD:
                        begin
                            core_load_o   = 1'b1;
                            core_din_o    = op_mod_i;
                            rsa_wp_busy_o = 1'b1;
                        end

                    WAIT_DONE:
                        begin
                            core_load_o   = '0;
                            core_din_o    = '0;
                            rsa_wp_busy_o = 1'b1;
                        end

                    default:
                        begin
                            core_load_o   = '0;
                            core_din_o    = '0;
                            rsa_wp_busy_o = '0;
                        end
                endcase
            end
    end

endmodule: amba_3_apb_rsa_wrapper_data