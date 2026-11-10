
module amba_3_apb_control #(
    parameter   DATA_WIDTH = 32,
                D_WID = DATA_WIDTH - 1
)(
    // APB Control Inputs:
    input  logic            psel_i,
    input  logic            penable_i,
    input  logic            pwrite_i,
    input  logic [3:0]      paddr_i,
    input  logic [1:0]      ctrl_pwdata_i,
    input  logic            addr_valid_i,

    // Register Bank Status:
    input  logic            status_done_i,
    input  logic            status_error_i,

    // Interrupt Enable Register:
    input  logic            done_ie_i,
    input  logic            err_ie_i,

    // Wrapper Control Inputs:
    input  logic            busy_i,

    // APB Control Outputs:
    output logic            pready_o,
    output logic            pslverr_o,
    output logic            irq_o,

    // Register Bank Write Enables:
    output logic            we_ctrl_o,
    output logic            we_status_o,
    output logic            we_ier_o,
    output logic            we_msg_o,
    output logic            we_exp_o,
    output logic            we_mod_o
);

// APB Phase Encoding:
localparam logic [3:0] IDLE   = 4'b1000,
                       SETUP  = 4'b1001,
                       ACCESS = 4'b1011;

// Reduced Register Bank Address:
localparam logic [3:0] CTRL_R   = 4'b0000,
                       STATUS_R = 4'b0001,
                       IER_R    = 4'b0010,
                       MSG_R    = 4'b0011,
                       EXP_R    = 4'b0100,
                       MOD_R    = 4'b0101,
                       RESULT_R = 4'b0110,
                       ID_R     = 4'b0111;

// APB3: Zero Wait States:
assign pready_o = 1'b1;

// Interrupt Request:
assign irq_o = (status_done_i && done_ie_i) ||(status_error_i && err_ie_i);

// APB Phase:
logic [3:0] apb_phase;

// APB Phase Decoder:
always_comb
    begin : control_branch

        if (psel_i && !penable_i)
            begin
                apb_phase = SETUP;
            end
        else if (psel_i && penable_i)
            begin
                apb_phase = ACCESS;
            end
        else
            begin
                apb_phase = IDLE;
            end
    end

// APB Operation Decoder:
always_comb
    begin : APB_actions

        // Default values:
        we_ctrl_o   = '0;
        we_status_o = '0;
        we_ier_o    = '0;
        we_msg_o    = '0;
        we_exp_o    = '0;
        we_mod_o    = '0;
        pslverr_o   = '0;

        case (apb_phase)

            // IDLE phase:
            IDLE:
                begin
                    // No active APB transaction.
                end

            // SETUP phase:
            SETUP:
                begin
                    // No register write is performed.
                end

            // ACCESS phase:
            ACCESS:
                begin

                    // Address validation:
                    if (!addr_valid_i)
                        begin
                            pslverr_o = 1'b1;
                        end

                    // APB Write operation:
                    else if (pwrite_i)
                        begin
                            case (paddr_i)

                                // CTRL register:
                                CTRL_R:
                                    begin
                                        // Valid APB write to CTRL:
                                        we_ctrl_o = 1'b1;

                                        // Reject START while BUSY.
                                        // SRST has priority over START:
                                        if (ctrl_pwdata_i == 2'b10 && busy_i)
                                            begin
                                                pslverr_o = 1'b1;
                                            end
                                        else
                                            begin
                                                pslverr_o = 1'b0;
                                            end
                                    end

                                // STATUS register (W1C):
                                STATUS_R:
                                    begin
                                        we_status_o = 1'b1;
                                    end

                                // IER register:
                                IER_R:
                                    begin
                                        we_ier_o = 1'b1;
                                    end

                                // MSG register:
                                MSG_R:
                                    begin
                                        if (!busy_i)
                                            begin
                                                we_msg_o = 1'b1;
                                            end
                                        else
                                            begin
                                                pslverr_o = 1'b1;
                                            end
                                    end

                                // EXP register:
                                EXP_R:
                                    begin
                                        if (!busy_i)
                                            begin
                                                we_exp_o = 1'b1;
                                            end
                                        else
                                            begin
                                                pslverr_o = 1'b1;
                                            end
                                    end

                                // MOD register:
                                MOD_R:
                                    begin
                                        if (!busy_i)
                                            begin
                                                we_mod_o = 1'b1;
                                            end
                                        else
                                            begin
                                                pslverr_o = 1'b1;
                                            end
                                    end

                                // Read-only registers:
                                RESULT_R, ID_R:
                                    begin
                                        pslverr_o = 1'b1;
                                    end

                                default:
                                    begin
                                        pslverr_o = 1'b1;
                                    end

                            endcase
                        end

                    // APB Read operation:
                    // Valid reads do not generate PSLVERR.
                    // CTRL is WO and returns zero via data_o_mux.
                    else
                        begin
                            pslverr_o = '0;
                        end
                end

            default:
                begin
                    // Undefined APB phase.
                end

        endcase
    end

endmodule: amba_3_apb_control
