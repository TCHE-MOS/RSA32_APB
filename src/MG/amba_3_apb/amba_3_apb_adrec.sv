module amba_3_apb_adrec #(
    parameter   ADDR_WIDTH = 12,
                A_WID = ADDR_WIDTH - 1
)(
    // APB Address:
    input  logic [A_WID:0] paddr_i,

    // Reduced Address and Validation:
    output logic [3:0]    oaddr_o,
    output logic          addr_valid_o
);

// Word index; byte-offset bits [1:0] do not affect register selection.
assign oaddr_o = paddr_i[5:2];

// Eight 32-bit registers occupy byte addresses 0x000 through 0x01F.
assign addr_valid_o = ~|paddr_i[A_WID:5];

endmodule: amba_3_apb_adrec
