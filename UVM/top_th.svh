////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////

`timescale 1ns/1ps

module top_th;

////////////////////////////////////////////////
// Testbench packages
////////////////////////////////////////////////
import top_tb_pkg::*;

////////////////////////////////////////////////
// Clock generation
////////////////////////////////////////////////
    logic pclk = 1'b0;

    always begin
        #(CLOCK_PERIOD_NS / 2) pclk = ~pclk;
    end

////////////////////////////////////////////////
// Interface instantiation
////////////////////////////////////////////////
    apb_rsa_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) apb_rsa_if (
        .pclk (pclk)
    );

////////////////////////////////////////////////
// Interface assertions
////////////////////////////////////////////////
    apb_protocol_sva apb_protocol_sva_h(apb_rsa_if);
    rsa_operation_sva rsa_operation_sva_h(apb_rsa_if);
    soft_reset_sva soft_reset_sva_h(apb_rsa_if);
    corners_exp_sva corners_exp_sva_h(apb_rsa_if);

////////////////////////////////////////////////
// DUT instantiation
////////////////////////////////////////////////
    amba_3_apb_rsa_apb_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        // rsa_core_ctrl waits for LOAD to fall between MSG, EXP and MOD.
        .LOAD_GAP   (1)
    ) dut (
        .pclk_i     (pclk),
        .presetn_i  (apb_rsa_if.presetn),
        .psel_i     (apb_rsa_if.psel),
        .penable_i  (apb_rsa_if.penable),
        .pwrite_i   (apb_rsa_if.pwrite),
        .paddr_i    (apb_rsa_if.paddr),
        .pwdata_i   (apb_rsa_if.pwdata),
        .prdata_o   (apb_rsa_if.prdata),
        .pready_o   (apb_rsa_if.pready),
        .pslverr_o  (apb_rsa_if.pslverr),
        .irq_o      (apb_rsa_if.irq)
    );

    // One waveform scope containing only the top-level DUT pins.
    dut_io_pinout_monitor dut_io_pinout (
        .pclk_i     (pclk),
        .presetn_i  (apb_rsa_if.presetn),
        .psel_i     (apb_rsa_if.psel),
        .penable_i  (apb_rsa_if.penable),
        .pwrite_i   (apb_rsa_if.pwrite),
        .paddr_i    (apb_rsa_if.paddr),
        .pwdata_i   (apb_rsa_if.pwdata),
        .prdata_o   (apb_rsa_if.prdata),
        .pready_o   (apb_rsa_if.pready),
        .pslverr_o  (apb_rsa_if.pslverr),
        .irq_o      (apb_rsa_if.irq)
    );

endmodule
