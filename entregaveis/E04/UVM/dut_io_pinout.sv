`ifndef RSA_APB_DUT_IO_PINOUT_SV
`define RSA_APB_DUT_IO_PINOUT_SV

`timescale 1ns/1ps

// Passive waveform monitor. Every port observes a DUT pin without driving it.
module dut_io_pinout_monitor (
    input wire                      pclk_i,
    input wire                      presetn_i,
    input wire                      psel_i,
    input wire                      penable_i,
    input wire                      pwrite_i,
    input wire [top_tb_pkg::ADDR_WIDTH-1:0] paddr_i,
    input wire [top_tb_pkg::DATA_WIDTH-1:0] pwdata_i,
    input wire [top_tb_pkg::DATA_WIDTH-1:0] prdata_o,
    input wire                      pready_o,
    input wire                      pslverr_o,
    input wire                      irq_o
);
endmodule

`endif
