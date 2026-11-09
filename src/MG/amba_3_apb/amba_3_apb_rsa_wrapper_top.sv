module amba_3_apb_rsa_wrapper_top #(
    parameter   DATA_WIDTH = 32,
                D_WID = DATA_WIDTH - 1,
                LOAD_GAP = 0
)(
    // Clock and Reset:
    input  logic             pclk_i,
    input  logic             presetn_i,

    // Register Bank Control:
    input  logic             start_i,
    input  logic             rsa_rst_i,

    // RSA Operands:
    input  logic [D_WID:0]   op_msg_i,
    input  logic [D_WID:0]   op_exp_i,
    input  logic [D_WID:0]   op_mod_i,

    // RSA Wrapper Status:
    output logic             rsa_wp_busy_o,
    output logic             rsa_wp_done_o,
    output logic             rsa_wp_error_o,
    output logic [D_WID:0]   rsa_wp_dout_o
);

// RSA Wrapper FSM States (One-Hot):
localparam logic [5:0] IDLE        = 6'b000000,
                       LOAD_MSG    = 6'b000001,
                       GAP_MSG_EXP = 6'b000010,
                       LOAD_EXP    = 6'b000100,
                       GAP_EXP_MOD = 6'b001000,
                       LOAD_MOD    = 6'b010000,
                       WAIT_DONE   = 6'b100000;

// GAP Counter Parameters:
localparam integer GAP_WIDTH = (LOAD_GAP > 1) ? $clog2(LOAD_GAP) : 1;
localparam logic [GAP_WIDTH-1:0] GAP_LAST = (LOAD_GAP > 0) ? GAP_WIDTH'(LOAD_GAP - 1) : '0;

// FSM State Connections:
logic [6:0] c_state_w;

// RSA Core Interface:
logic               core_clk;
logic               core_rst;
logic               core_load;
logic [D_WID:0]     core_din;
logic               core_done;
logic               core_error;
logic [D_WID:0]     core_dout;

// RSA Core Clock and Reset:
assign core_clk = pclk_i;
assign core_rst = rsa_rst_i;

// RSA Wrapper Outputs:
assign rsa_wp_done_o  = core_done;
assign rsa_wp_error_o = core_error;
assign rsa_wp_dout_o  = core_dout;

// RSA Wrapper Control Path Instance:
amba_3_apb_rsa_wrapper_control #(
    .LOAD_GAP    (LOAD_GAP),
    .GAP_WIDTH   (GAP_WIDTH),
    .GAP_LAST    (GAP_LAST),
    .IDLE        (IDLE),
    .LOAD_MSG    (LOAD_MSG),
    .GAP_MSG_EXP (GAP_MSG_EXP),
    .LOAD_EXP    (LOAD_EXP),
    .GAP_EXP_MOD (GAP_EXP_MOD),
    .LOAD_MOD    (LOAD_MOD),
    .WAIT_DONE   (WAIT_DONE)
) rsa_wrapper_control_inst (
    .pclk_i       (pclk_i),
    .presetn_i    (presetn_i),
    .rsa_rst_i    (rsa_rst_i),
    .start_i      (start_i),
    .core_done_i  (core_done),
    .core_error_i (core_error),
    .c_state_o    (c_state_w)
);

// RSA Wrapper Data Path Instance:
amba_3_apb_rsa_wrapper_data #(
    .DATA_WIDTH  (DATA_WIDTH),
    .D_WID       (D_WID),
    .IDLE        (IDLE),
    .LOAD_MSG    (LOAD_MSG),
    .GAP_MSG_EXP (GAP_MSG_EXP),
    .LOAD_EXP    (LOAD_EXP),
    .GAP_EXP_MOD (GAP_EXP_MOD),
    .LOAD_MOD    (LOAD_MOD),
    .WAIT_DONE   (WAIT_DONE)
) rsa_wrapper_data_inst (
    .c_state_i     (c_state_w),
    .rsa_rst_i     (rsa_rst_i),
    .op_msg_i      (op_msg_i),
    .op_exp_i      (op_exp_i),
    .op_mod_i      (op_mod_i),
    .core_load_o   (core_load),
    .core_din_o    (core_din),
    .rsa_wp_busy_o (rsa_wp_busy_o)
);

// RSA Core Instance:
rsa_core #(
    .DATA_WIDTH (DATA_WIDTH),
    .RESET      (1'b1),
    .LOAD       (1'b1)
) rsa_core_inst (
    .core_clk   (core_clk),
    .core_rst   (core_rst),
    .core_load  (core_load),
    .core_din   (core_din),
    .core_done  (core_done),
    .core_err   (core_error),
    .core_dout  (core_dout)
);

endmodule: amba_3_apb_rsa_wrapper_top