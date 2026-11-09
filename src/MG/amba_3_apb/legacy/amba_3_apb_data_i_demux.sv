module amba_3_apb_data_i_demux #(
    parameter   DATA_WIDTH = 32,
                D_WID = DATA_WIDTH - 1,
                ADDR_WIDTH = 11,
                A_WID = ADDR_WIDTH - 1
)(
    input  logic [3:0]      paddr_i,
    input  logic [D_WID:0]  pwdata_i,
    output logic [D_WID:0]  op_ctl_o,
                            op_sts_o,
                            op_ier_o,
                            op_msg_o,
                            op_exp_o,
                            op_mod_o,
                            op_res_o,
                            op_idr_o
);

    // Op codes:
    localparam  CTRL_R    = 4'b0000,
                STATUS_R  = 4'b0001,
                IER_R     = 4'b0010,
                MSG_R     = 4'b0011,
                EXP_R     = 4'b0100,
                MOD_R     = 4'b0101,
                RESULT_R  = 4'b0110,
                ID_R      = 4'b0111;

    always_comb begin : Demux
        case (paddr_i)
            CTRL_R:
                begin
                    op_ctl_o = pwdata_i;
                    op_sts_o = 'Z;
                    op_ier_o = 'Z;
                    op_msg_o = 'Z;
                    op_exp_o = 'Z;
                    op_mod_o = 'Z;
                    op_res_o = 'Z;
                    op_idr_o = 'Z;
                end
            STATUS_R:
                begin
                    op_ctl_o = 'Z;
                    op_sts_o = pwdata_i;
                    op_ier_o = 'Z;
                    op_msg_o = 'Z;
                    op_exp_o = 'Z;
                    op_mod_o = 'Z;
                    op_res_o = 'Z;
                    op_idr_o = 'Z;
                end
            IER_R:
                begin
                    op_ctl_o = 'Z;
                    op_sts_o = 'Z;
                    op_ier_o = pwdata_i;
                    op_msg_o = 'Z;
                    op_exp_o = 'Z;
                    op_mod_o = 'Z;
                    op_res_o = 'Z;
                    op_idr_o = 'Z;
                end
            MSG_R:
                begin
                    op_ctl_o = 'Z;
                    op_sts_o = 'Z;
                    op_ier_o = 'Z;
                    op_msg_o = pwdata_i;
                    op_exp_o = 'Z;
                    op_mod_o = 'Z;
                    op_res_o = 'Z;
                    op_idr_o = 'Z;
                end
            EXP_R:
                begin
                    op_ctl_o = 'Z;
                    op_sts_o = 'Z;
                    op_ier_o = 'Z;
                    op_msg_o = 'Z;
                    op_exp_o = pwdata_i;
                    op_mod_o = 'Z;
                    op_res_o = 'Z;
                    op_idr_o = 'Z;
                end
            MOD_R:
                begin
                    op_ctl_o = 'Z;
                    op_sts_o = 'Z;
                    op_ier_o = 'Z;
                    op_msg_o = 'Z;
                    op_exp_o = 'Z;
                    op_mod_o = pwdata_i;
                    op_res_o = 'Z;
                    op_idr_o = 'Z;
                end
            RESULT_R:
                begin
                    op_ctl_o = 'Z;
                    op_sts_o = 'Z;
                    op_ier_o = 'Z;
                    op_msg_o = 'Z;
                    op_exp_o = 'Z;
                    op_mod_o = 'Z;
                    op_res_o = pwdata_i;
                    op_idr_o = 'Z;
                end
            ID_R:
                begin
                    op_ctl_o = 'Z;
                    op_sts_o = 'Z;
                    op_ier_o = 'Z;
                    op_msg_o = 'Z;
                    op_exp_o = 'Z;
                    op_mod_o = 'Z;
                    op_res_o = 'Z;
                    op_idr_o = pwdata_i;
                end
            default:
                begin
                    op_ctl_o = 'Z;
                    op_sts_o = 'Z;
                    op_ier_o = 'Z;
                    op_msg_o = 'Z;
                    op_exp_o = 'Z;
                    op_mod_o = 'Z;
                    op_res_o = 'Z;
                    op_idr_o = 'Z;
                end
        endcase
    end

endmodule: amba_3_apb_data_i_demux
