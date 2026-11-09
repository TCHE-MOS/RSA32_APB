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

    // Verification clock counter; budgets are independent of APB polling frequency.
    longint unsigned cycle_count = 0;
    always @(posedge pclk) cycle_count <= cycle_count + 1;

    // Observation context for the X/Z sequence; no dedicated SVA at this stage.
    bit xz_values_active = 1'b0;
    int unsigned xz_pattern_id = 0;
    logic [ADDR_WIDTH-1:0] xz_address;
    logic [DATA_WIDTH-1:0] xz_payload;

    // Verification-only controls; these signals are not connected to the DUT.
    bit sva_rsa_operation_active = 1'b0;
    bit sva_soft_reset_active = 1'b0;
    bit sva_test_id_active = 1'b0;

    // Context of one corners-exp case; no connection to DUT ports.
    bit sva_corners_exp_active = 1'b0;
    int unsigned sva_corners_case_id = 0;
    int unsigned sva_corners_cases_planned = 0;
    int unsigned sva_corners_cases_completed = 0;
    int unsigned sva_corners_exp_width = 4;
    bit [1:0] sva_corners_case_kind = 0;
    bit sva_corners_recovery = 1'b0;
    bit sva_corners_readback_active = 1'b0;
    logic [ADDR_WIDTH-1:0] sva_corners_readback_addr;
    logic [DATA_WIDTH-1:0] sva_corners_readback_data;

    // Expected data and observation windows published by the current testcase.
    bit sva_corners_operation_active = 1'b0;
    bit sva_corners_result_check = 1'b0;
    logic [ADDR_WIDTH-1:0] sva_corners_result_addr;
    logic [DATA_WIDTH-1:0] sva_corners_expected_result;


endinterface
