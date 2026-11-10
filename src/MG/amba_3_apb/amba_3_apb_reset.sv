
module amba_3_apb_reset #(
    parameter LATENCY = 2
)(
    // Clock and Reset:
    input  logic pclk_i,
    input  logic presetn_i,

    // Software Reset:
    input  logic srst_i,

    // RSA Core Reset:
    output logic rsa_rst_o
);

// Reset Synchronizer Registers:
logic [LATENCY-1:0] reset_sync_reg;
logic presetnsync;

// Reset Synchronizer:
always_ff @(posedge pclk_i or negedge presetn_i)
    begin
        if (!presetn_i)
            begin
                reset_sync_reg <= '0;
            end
        else
            begin
                reset_sync_reg <= (reset_sync_reg << 1) | {{(LATENCY-1){1'b0}}, 1'b1};
            end
    end

// Internal reset with synchronized release:
assign presetnsync = reset_sync_reg[LATENCY-1];

// RSA Core Reset:
assign rsa_rst_o = !presetnsync || srst_i;

endmodule: amba_3_apb_reset
