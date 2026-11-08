////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////

`timescale 1ns/1ps

interface apb_rsa_if #(
        parameter DATA_WIDTH = 32,
        parameter ADDR_WIDTH = 12
    )
    (
        input logic pclk
);

    // Interface signals
    logic presetn;
    logic psel; 
    logic penable; 
    logic pwrite;
    logic [ADDR_WIDTH-1:0] paddr;
    logic [DATA_WIDTH-1:0] pwdata;
    logic [DATA_WIDTH-1:0] prdata;
    logic  pready;
    logic  pslverr;
    logic  irq;

    // Verification-only controls; these signals are not connected to the DUT.
    bit sva_rsa_operation_active = 1'b0;
    bit sva_soft_reset_active = 1'b0;


endinterface
