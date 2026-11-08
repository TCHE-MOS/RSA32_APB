////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


package top_tb_pkg;

    // Basic parameters
    parameter integer DATA_WIDTH = 32;
    parameter integer ADDR_WIDTH = 12;
    parameter integer CLOCK_PERIOD_NS = 10;

    // Address Mapping (Datasheet 5)
    parameter logic [ADDR_WIDTH-1:0] CTRL_ADDR   = 12'h000;
    parameter logic [ADDR_WIDTH-1:0] STATUS_ADDR = 12'h004;
    parameter logic [ADDR_WIDTH-1:0] IER_ADDR    = 12'h008;
    parameter logic [ADDR_WIDTH-1:0] MSG_ADDR    = 12'h00C;
    parameter logic [ADDR_WIDTH-1:0] EXP_ADDR    = 12'h010;
    parameter logic [ADDR_WIDTH-1:0] MOD_ADDR    = 12'h014;
    parameter logic [ADDR_WIDTH-1:0] RESULT_ADDR = 12'h018;
    parameter logic [ADDR_WIDTH-1:0] ID_ADDR     = 12'h01C;

    // Expected ID value (Datasheet 6.6)
    parameter logic [31:0] EXPECTED_ID_VALUE = 32'h5253_0200;

endpackage : top_tb_pkg