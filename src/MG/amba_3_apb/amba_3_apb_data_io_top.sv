
module amba_3_apb_data_io_top #(
    parameter   DATA_WIDTH = 32,
                ADDR_WIDTH = 12,
                D_WID = DATA_WIDTH - 1,
                A_WID = ADDR_WIDTH - 1
)(
    // APB Address:
    input  logic [A_WID:0]  paddr_i,

    // Register Bank Read Data:
    input  logic [D_WID:0]  op_sts_i,
    input  logic [D_WID:0]  op_ier_i,
    input  logic [D_WID:0]  op_msg_i,
    input  logic [D_WID:0]  op_exp_i,
    input  logic [D_WID:0]  op_mod_i,
    input  logic [D_WID:0]  op_res_i,
    input  logic [D_WID:0]  op_idr_i,

    // APB Read Data:
    output logic [D_WID:0]  prdata_o,

    // Reduced Address:
    output logic [3:0]      oaddr_o,

    // Address Validation:
    output logic            addr_valid_o
);


// Internal Signals:
logic [3:0]     oaddr_w;
logic [D_WID:0] prdata_mux_w;

// Address Reduction:
amba_3_apb_adrec #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .A_WID      (A_WID)
) adrec_inst (
    .paddr_i      (paddr_i),
    .oaddr_o      (oaddr_w),
    .addr_valid_o (addr_valid_o)
);

assign oaddr_o = oaddr_w;

// Read Data Validation:
assign prdata_o = addr_valid_o ? prdata_mux_w : '0;

// APB Read Multiplexer:
amba_3_apb_data_o_mux #(
                        .DATA_WIDTH(DATA_WIDTH)
                        ) da_o_m (
                        .paddr_i (oaddr_w),
                        .op_sts_i(op_sts_i),
                        .op_ier_i(op_ier_i),
                        .op_msg_i(op_msg_i),
                        .op_exp_i(op_exp_i),
                        .op_mod_i(op_mod_i),
                        .op_res_i(op_res_i),
                        .op_idr_i(op_idr_i),
                        .prdata_o(prdata_mux_w)
                        );

endmodule: amba_3_apb_data_io_top
