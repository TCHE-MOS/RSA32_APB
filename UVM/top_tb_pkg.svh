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

    // Quantidade de casos corners por largura de EXP. Edite somente estes valores.
    // Zero desabilita a largura; o total e o watchdog sao calculados automaticamente.
    parameter integer CORNERS_CASES_EXP_4  = 10;
    parameter integer CORNERS_CASES_EXP_8  = 10;
    parameter integer CORNERS_CASES_EXP_12 = 5;
    parameter integer CORNERS_CASES_EXP_16 = 1;
    parameter integer CORNERS_CASES_EXP_32 = 1;

    parameter integer CORNERS_TOTAL_CASES = CORNERS_CASES_EXP_4
                                         + CORNERS_CASES_EXP_8
                                         + CORNERS_CASES_EXP_12
                                         + CORNERS_CASES_EXP_16
                                         + CORNERS_CASES_EXP_32;

    // Fixed X/Z campaign: all-X, all-Z and both orders at bit/nibble/byte granularity.
    parameter integer XZ_VALUES_PATTERN_COUNT = 8;

    // Address Mapping (Datasheet 5)
    parameter logic [ADDR_WIDTH-1:0] CTRL_ADDR   = 12'h000;
    parameter logic [ADDR_WIDTH-1:0] STATUS_ADDR = 12'h004;
    parameter logic [ADDR_WIDTH-1:0] IER_ADDR    = 12'h008;
    parameter logic [ADDR_WIDTH-1:0] MSG_ADDR    = 12'h00C;
    parameter logic [ADDR_WIDTH-1:0] EXP_ADDR    = 12'h010;
    parameter logic [ADDR_WIDTH-1:0] MOD_ADDR    = 12'h014;
    parameter logic [ADDR_WIDTH-1:0] RESULT_ADDR = 12'h018;
    parameter logic [ADDR_WIDTH-1:0] ID_ADDR     = 12'h01C;

    // Shared by the imported ID checker and the general APB checker (6.6).
    parameter logic [31:0] EXPECTED_ID_VALUE = 32'h5253_0200;


endpackage : top_tb_pkg
