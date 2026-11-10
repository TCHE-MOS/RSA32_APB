
module amba_3_apb_regbank #(
    parameter   DATA_WIDTH = 32,
                D_WID = DATA_WIDTH - 1
)(
    // Clock and Reset:
    input  logic             pclk_i,
    input  logic             presetn_i,
    input  logic             rsa_rst_i,

    // APB Write Data:
    input  logic [D_WID:0]   pwdata_i,

    // Register Write Enables:
    input  logic             we_ctrl_i,
    input  logic             we_status_i,
    input  logic             we_ier_i,
    input  logic             we_msg_i,
    input  logic             we_exp_i,
    input  logic             we_mod_i,

    // Wrapper Control:
    input  logic             rsa_wp_busy_i,
    input  logic             rsa_wp_done_i,
    input  logic             rsa_wp_error_i,
    input  logic [D_WID:0]   rsa_wp_dout_i,

    // Control Commands:
    output logic             start_o,
    output logic             srst_o,

    // Status Flags:
    output logic             status_done_o,
    output logic             status_error_o,

    // Interrupt Enables:
    output logic             done_ie_o,
    output logic             err_ie_o,

    // Register Outputs:
    output logic [D_WID:0]   op_sts_o,
    output logic [D_WID:0]   op_ier_o,
    output logic [D_WID:0]   op_msg_o,
    output logic [D_WID:0]   op_exp_o,
    output logic [D_WID:0]   op_mod_o,
    output logic [D_WID:0]   op_res_o,
    output logic [D_WID:0]   op_idr_o
);

// ID Register (0x1C):
localparam logic [D_WID:0] ID_VALUE = 32'h5253_0200;

// Reduced Register Bank Address:
localparam logic [3:0] CTRL_R   = 4'b0000,
                       STATUS_R = 4'b0001,
                       IER_R    = 4'b0010,
                       MSG_R    = 4'b0011,
                       EXP_R    = 4'b0100,
                       MOD_R    = 4'b0101,
                       RESULT_R = 4'b0110,
                       ID_R     = 4'b0111;

// CTRL Register (0x00):
// START and SRST are self-clearing commands.
// No storage required.

// STATUS Register (0x04):
// [2] ERROR, [1] DONE, [0] BUSY
logic               status_error_reg;
logic               status_done_reg;

// IER Register (0x08):
// [1] ERR_IE, [0] DONE_IE
logic               ier_err_ie_reg;
logic               ier_done_ie_reg;

// MSG Register (0x0C):
logic [D_WID:0]     msg_reg;

// EXP Register (0x10):
logic [D_WID:0]     exp_reg;

// MOD Register (0x14):
logic [D_WID:0]     mod_reg;

// RESULT Register (0x18):
logic [D_WID:0]     result_reg;

// STATUS Register (0x04):
assign op_sts_o[D_WID:3] = '0;
assign op_sts_o[2]       = status_error_reg;
assign op_sts_o[1]       = status_done_reg;
assign op_sts_o[0]       = rsa_wp_busy_i;

// IER Register (0x08):
assign op_ier_o[D_WID:2] = '0;
assign op_ier_o[1]       = ier_err_ie_reg;
assign op_ier_o[0]       = ier_done_ie_reg;

// ID Register (0x1C):
assign op_idr_o = ID_VALUE;

// STATUS Flags:
assign status_done_o  = status_done_reg;
assign status_error_o = status_error_reg;

// Interrupt Enables:
assign done_ie_o = ier_done_ie_reg;
assign err_ie_o  = ier_err_ie_reg;


// IER, MSG, EXP and MOD Registers:
always_ff @(posedge pclk_i or negedge presetn_i)
    begin
        if (!presetn_i)
            begin
                ier_err_ie_reg  <= '0;
                ier_done_ie_reg <= '0;
                msg_reg         <= '0;
                exp_reg         <= '0;
                mod_reg         <= '0;
            end
        else
            begin
                // IER Register:
                if (we_ier_i)
                    begin
                        ier_err_ie_reg  <= pwdata_i[1];
                        ier_done_ie_reg <= pwdata_i[0];
                    end
                else
                    begin
                        ier_err_ie_reg  <= ier_err_ie_reg;
                        ier_done_ie_reg <= ier_done_ie_reg;
                    end

                // MSG Register:
                if (we_msg_i)
                    begin
                        msg_reg <= pwdata_i;
                    end
                else
                    begin
                        msg_reg <= msg_reg;
                    end

                // EXP Register:
                if (we_exp_i)
                    begin
                        exp_reg <= pwdata_i;
                    end
                else
                    begin
                        exp_reg <= exp_reg;
                    end

                // MOD Register:
                if (we_mod_i)
                    begin
                        mod_reg <= pwdata_i;
                    end
                else
                    begin
                        mod_reg <= mod_reg;
                    end
            end
    end


// STATUS Register:
always_ff @(posedge pclk_i or negedge presetn_i)
    begin
        if (!presetn_i)
            begin
                status_done_reg  <= '0;
                status_error_reg <= '0;
            end
        else if (srst_o || start_o)
            begin
                status_done_reg  <= '0;
                status_error_reg <= '0;
            end
        else
            begin
                // DONE Flag:
                if (rsa_wp_done_i)
                    begin
                        status_done_reg <= 1'b1;
                    end
                else if (we_status_i && pwdata_i[1])
                    begin
                        status_done_reg <= '0;
                    end
                else
                    begin
                        status_done_reg <= status_done_reg;
                    end

                // ERROR Flag:
                if (rsa_wp_error_i)
                    begin
                        status_error_reg <= 1'b1;
                    end
                else if (we_status_i && pwdata_i[2])
                    begin
                        status_error_reg <= '0;
                    end
                else
                    begin
                        status_error_reg <= status_error_reg;
                    end
            end
    end

// RESULT Register:
always_ff @(posedge pclk_i or negedge presetn_i)
    begin
        if (!presetn_i)
            begin
                result_reg <= '0;
            end
        else
            begin
                if (rsa_wp_done_i && !srst_o)
                    begin
                        result_reg <= rsa_wp_dout_i;
                    end
                else
                    begin
                        result_reg <= result_reg;
                    end
            end
    end

// CTRL Register Commands:
// Reset has priority over START.
assign srst_o  = we_ctrl_i && pwdata_i[1];

assign start_o = (we_ctrl_i && pwdata_i[0] && !pwdata_i[1] && !rsa_wp_busy_i && presetn_i && !rsa_rst_i);

// MSG Register (0x0C):
assign op_msg_o = msg_reg;

// EXP Register (0x10):
assign op_exp_o = exp_reg;

// MOD Register (0x14):
assign op_mod_o = mod_reg;

// RESULT Register (0x18):
assign op_res_o = result_reg;

endmodule: amba_3_apb_regbank
