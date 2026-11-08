`timescale 1ns/1ps

module soft_reset_sva #(
    parameter logic [31:0] EXPECTED_STATUS_AFTER_SRST = 32'h0
)(apb_rsa_if bus);
    import top_tb_pkg::*;

    wire transfer = bus.psel && bus.penable && bus.pready;
    wire srst_write = transfer && bus.pwrite && bus.paddr == CTRL_ADDR && bus.pwdata === 32'h2;

    sequence s_next_write(addr);
        (!transfer)[*0:$] ##1 (transfer && bus.pwrite && bus.paddr == addr);
    endsequence

    sequence s_next_read(addr);
        (!transfer)[*0:$] ##1 (transfer && !bus.pwrite && bus.paddr == addr);
    endsequence

    sequence s_soft_reset;
        s_next_write(MSG_ADDR)
        ##1 s_next_write(EXP_ADDR)
        ##1 s_next_write(MOD_ADDR)
        ##1 s_next_write(CTRL_ADDR) ##0 (bus.pwdata === 32'h1)
        ##1 s_next_read(STATUS_ADDR)
        ##1 s_next_write(CTRL_ADDR) ##0 (bus.pwdata === 32'h2)
        ##1 s_next_read(STATUS_ADDR);
    endsequence

    property p_soft_reset_order;
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        $rose(bus.sva_soft_reset_active && bus.presetn)
        |-> strong(bus.sva_soft_reset_active throughout s_soft_reset);
    endproperty

    ap_soft_reset_order: assert property (p_soft_reset_order)
        else env_pkg::scoreboard::record_assertion("soft_reset", "SOFT_RESET_ORDER", 1'b0, "Ordem incorreta ou cenario de soft reset incompleto");

    ap_soft_reset_response: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_soft_reset_active)
        transfer |-> (bus.pslverr === 1'b0)
    ) else env_pkg::scoreboard::record_assertion("soft_reset", "SOFT_RESET_RESPONSE", 1'b0, "Erro APB inesperado no soft reset");

    ap_status_after_srst: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_soft_reset_active)
        srst_write |=> strong(s_next_read(STATUS_ADDR) ##0 (bus.prdata === EXPECTED_STATUS_AFTER_SRST))
    ) else env_pkg::scoreboard::record_assertion("soft_reset", "SOFT_RESET_STATUS", 1'b0, "Leitura de STATUS apos SRST ausente ou diferente do esperado");

    cp_srst: cover property (
        @(posedge bus.pclk) bus.presetn && bus.sva_soft_reset_active && !bus.pslverr && srst_write
    );

    cp_status_after_srst: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_soft_reset_active)
        srst_write ##1 (s_next_read(STATUS_ADDR) ##0 (bus.prdata === EXPECTED_STATUS_AFTER_SRST))
    ) env_pkg::scoreboard::record_assertion("soft_reset", "SOFT_RESET_STATUS", 1'b1);

    cp_soft_reset_response: cover property (
        @(posedge bus.pclk) bus.presetn && bus.sva_soft_reset_active && transfer && bus.pslverr === 1'b0
    ) env_pkg::scoreboard::record_assertion("soft_reset", "SOFT_RESET_RESPONSE", 1'b1);

    cp_complete: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        $rose(bus.sva_soft_reset_active && bus.presetn)
        ##0 (bus.sva_soft_reset_active throughout s_soft_reset)
    ) env_pkg::scoreboard::record_assertion("soft_reset", "SOFT_RESET_ORDER", 1'b1);

endmodule
