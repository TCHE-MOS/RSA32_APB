module amba_3_apb_rsa_apb_top #(
    parameter   DATA_WIDTH = 32,
                D_WID = DATA_WIDTH - 1,
                ADDR_WIDTH = 12,
                A_WID = ADDR_WIDTH - 1,
                LOAD_GAP = 1,
                RESET_LATENCY = 2
)(
    // APB Clock and Reset:
    input  logic             pclk_i,
    input  logic             presetn_i,

    // APB Control:
    input  logic             psel_i,
    input  logic             penable_i,
    input  logic             pwrite_i,

    // APB Address and Data:
    input  logic [A_WID:0]   paddr_i,
    input  logic [D_WID:0]   pwdata_i,

    // APB Outputs:
    output logic [D_WID:0]   prdata_o,
    output logic             pready_o,
    output logic             pslverr_o,
    output logic             irq_o
);

logic [1:0] ctrl_pwdata_w;

assign ctrl_pwdata_w = pwdata_i[1:0];

// Reduced Address and Validation:
logic [3:0]     oaddr_w;
logic           addr_valid_w;

// Register Bank Write Enables:
logic           we_ctrl_w;
logic           we_status_w;
logic           we_ier_w;
logic           we_msg_w;
logic           we_exp_w;
logic           we_mod_w;

// Register Bank Commands:
logic           start_w;
logic           srst_w;

// Register Bank Status and Interrupt Enables:
logic           status_done_w;
logic           status_error_w;
logic           done_ie_w;
logic           err_ie_w;

// Register Bank Data Outputs:
logic [D_WID:0] op_sts_w;
logic [D_WID:0] op_ier_w;
logic [D_WID:0] op_msg_w;
logic [D_WID:0] op_exp_w;
logic [D_WID:0] op_mod_w;
logic [D_WID:0] op_res_w;
logic [D_WID:0] op_idr_w;

// Reset Signals:
logic           rsa_rst_w;

// RSA Wrapper Signals:
logic           rsa_wp_busy_w;
logic           rsa_wp_done_w;
logic           rsa_wp_error_w;
logic [D_WID:0] rsa_wp_dout_w;

// APB Address and Read Data:
amba_3_apb_data_io_top #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .D_WID      (D_WID),
    .A_WID      (A_WID)
) data_io_top_inst (
    .paddr_i      (paddr_i),
    .op_sts_i     (op_sts_w),
    .op_ier_i     (op_ier_w),
    .op_msg_i     (op_msg_w),
    .op_exp_i     (op_exp_w),
    .op_mod_i     (op_mod_w),
    .op_res_i     (op_res_w),
    .op_idr_i     (op_idr_w),
    .prdata_o     (prdata_o),
    .oaddr_o      (oaddr_w),
    .addr_valid_o (addr_valid_w)
);

// APB Control:
amba_3_apb_control #(
    .DATA_WIDTH (DATA_WIDTH),
    .D_WID      (D_WID)
) apb_control_inst (
    .psel_i          (psel_i),
    .penable_i       (penable_i),
    .pwrite_i        (pwrite_i),
    .paddr_i         (oaddr_w),
    .ctrl_pwdata_i   (ctrl_pwdata_w),
    .addr_valid_i    (addr_valid_w),
    .status_done_i   (status_done_w),
    .status_error_i  (status_error_w),
    .done_ie_i       (done_ie_w),
    .err_ie_i        (err_ie_w),
    .busy_i          (rsa_wp_busy_w),
    .pready_o        (pready_o),
    .pslverr_o       (pslverr_o),
    .irq_o           (irq_o),
    .we_ctrl_o       (we_ctrl_w),
    .we_status_o     (we_status_w),
    .we_ier_o        (we_ier_w),
    .we_msg_o        (we_msg_w),
    .we_exp_o        (we_exp_w),
    .we_mod_o        (we_mod_w)
);

// Register Bank:
amba_3_apb_regbank #(
    .DATA_WIDTH (DATA_WIDTH),
    .D_WID      (D_WID)
) regbank_inst (
    .pclk_i           (pclk_i),
    .presetn_i        (presetn_i),
    .rsa_rst_i        (rsa_rst_w),
    .pwdata_i         (pwdata_i),
    .we_ctrl_i        (we_ctrl_w),
    .we_status_i      (we_status_w),
    .we_ier_i         (we_ier_w),
    .we_msg_i         (we_msg_w),
    .we_exp_i         (we_exp_w),
    .we_mod_i         (we_mod_w),
    .rsa_wp_busy_i    (rsa_wp_busy_w),
    .rsa_wp_done_i    (rsa_wp_done_w),
    .rsa_wp_error_i   (rsa_wp_error_w),
    .rsa_wp_dout_i    (rsa_wp_dout_w),
    .start_o          (start_w),
    .srst_o           (srst_w),
    .status_done_o    (status_done_w),
    .status_error_o   (status_error_w),
    .done_ie_o        (done_ie_w),
    .err_ie_o         (err_ie_w),
    .op_sts_o         (op_sts_w),
    .op_ier_o         (op_ier_w),
    .op_msg_o         (op_msg_w),
    .op_exp_o         (op_exp_w),
    .op_mod_o         (op_mod_w),
    .op_res_o         (op_res_w),
    .op_idr_o         (op_idr_w)
);

// Reset Synchronizer:
amba_3_apb_reset #(
    .LATENCY (RESET_LATENCY)
) reset_inst (
    .pclk_i         (pclk_i),
    .presetn_i      (presetn_i),
    .srst_i         (srst_w),
    .rsa_rst_o      (rsa_rst_w)
);

// RSA Wrapper:
amba_3_apb_rsa_wrapper_top #(
    .DATA_WIDTH (DATA_WIDTH),
    .D_WID      (D_WID),
    .LOAD_GAP   (LOAD_GAP)
) rsa_wrapper_inst (
    .pclk_i          (pclk_i),
    .presetn_i       (presetn_i),
    .start_i         (start_w),
    .rsa_rst_i       (rsa_rst_w),
    .op_msg_i        (op_msg_w),
    .op_exp_i        (op_exp_w),
    .op_mod_i        (op_mod_w),
    .rsa_wp_busy_o   (rsa_wp_busy_w),
    .rsa_wp_done_o   (rsa_wp_done_w),
    .rsa_wp_error_o  (rsa_wp_error_w),
    .rsa_wp_dout_o   (rsa_wp_dout_w)
);

endmodule: amba_3_apb_rsa_apb_top
