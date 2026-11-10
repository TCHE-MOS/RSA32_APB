
// Consolidated Verilog source
// Top module: rsa_core
// Included modules:
//   - rsa_core_mult
//   - rsa_core_mod
//   - rsa_core_ctrl
//   - rsa_core


// ============================================================
// Module: rsa_core (TOP)
// ============================================================
module rsa_core #(
    parameter   DATA_WIDTH = 32,
                D_WID      = (DATA_WIDTH-1),
                RESET = 1'b1,
                LOAD = 1'b1
)
(
    input   logic core_clk,
    input   logic core_rst,
    input   logic core_load,
    input   logic [D_WID:0] core_din,
    output  logic core_done,
    output  logic core_err,
    output  logic [D_WID:0] core_dout
);

    // Internal signals
    logic ctrl_start_sig;
    logic [D_WID:0]      ctrl_m_sig;
    logic [D_WID:0]      ctrl_n_sig;
    logic [D_WID:0]      ctrl_doutx_sig;

    logic mult_done_sig;
    logic [2*DATA_WIDTH-1:0] mult_c_sig;

    logic mod_done_sig;
    logic [D_WID:0]      mod_c_sig;

    logic mod_err_unused;

    // Component instantiations
    rsa_core_mult #(
        .DATA_WIDTH (DATA_WIDTH),
        .RESET      (RESET),
        .START      (1'b1)
    ) rsa_core_mult_blk (
        .mult_clk   (core_clk),
        .mult_rst   (core_rst),
        .mult_start (ctrl_start_sig),
        .mult_a     (ctrl_m_sig),
        .mult_b     (ctrl_doutx_sig),
        .mult_done  (mult_done_sig),
        .mult_c     (mult_c_sig)
    );

    rsa_core_mod #(
        .DATA_WIDTH (DATA_WIDTH),
        .RESET      (RESET),
        .START      (1'b1)
    ) rsa_core_mod_blk (
        .mod_clk    (core_clk),
        .mod_rst    (core_rst),
        .mod_start  (mult_done_sig),
        .mod_a      (mult_c_sig),
        .mod_b      (ctrl_n_sig),
        .mod_done   (mod_done_sig),
        .mod_err    (mod_err_unused), // Deixe isso desconectado apenas se for realmente necessário
        .mod_c      (mod_c_sig)
    );

    rsa_core_ctrl #(
        .DATA_WIDTH (DATA_WIDTH),
        .RESET      (RESET),
        .LOAD       (LOAD)
    ) rsa_core_ctrl_blk (
        .ctrl_clk   (core_clk),
        .ctrl_rst   (core_rst),
        .ctrl_load  (core_load),
        .ctrl_din   (core_din),
        .ctrl_loadx (mod_done_sig),
        .ctrl_dinx  (mod_c_sig),
        .ctrl_done  (core_done),
        .ctrl_err   (core_err),
        .ctrl_c     (core_dout),
        .ctrl_start (ctrl_start_sig),
        .ctrl_n     (ctrl_n_sig),
        .ctrl_m     (ctrl_m_sig),
        .ctrl_doutx (ctrl_doutx_sig)
    );

endmodule