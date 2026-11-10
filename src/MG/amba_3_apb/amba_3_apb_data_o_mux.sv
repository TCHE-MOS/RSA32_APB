
module amba_3_apb_data_o_mux #(
    parameter   DATA_WIDTH = 32,
                D_WID = DATA_WIDTH - 1
)(
    input  logic [3:0]      paddr_i,
    input  logic [D_WID:0]  op_sts_i,
                            op_ier_i,
                            op_msg_i,
                            op_exp_i,
                            op_mod_i,
                            op_res_i,
                            op_idr_i,

    output logic [D_WID:0]  prdata_o
);

// Register Bank Addresses:
localparam logic [3:0]  CTRL_R   = 4'b0000,
                        STATUS_R = 4'b0001,
                        IER_R    = 4'b0010,
                        MSG_R    = 4'b0011,
                        EXP_R    = 4'b0100,
                        MOD_R    = 4'b0101,
                        RESULT_R = 4'b0110,
                        ID_R     = 4'b0111;

// Default read value:
localparam logic [D_WID:0] INVALID_DATA = 32'h0000_000F;

// APB Read Multiplexer:
always_comb
    begin : Mux
        case (paddr_i)

            CTRL_R:    prdata_o = '0;
            STATUS_R:  prdata_o = op_sts_i;
            IER_R:     prdata_o = op_ier_i;
            MSG_R:     prdata_o = op_msg_i;
            EXP_R:     prdata_o = op_exp_i;
            MOD_R:     prdata_o = op_mod_i;
            RESULT_R:  prdata_o = op_res_i;
            ID_R:      prdata_o = op_idr_i;
            default:   prdata_o = INVALID_DATA;

            endcase
        end

endmodule: amba_3_apb_data_o_mux
