`timescale 1ns/1ps

// Verificacoes do bloco de identificacao (func. 10, Datasheet 6.6).
// Independentes de qual seja o valor do ID: ele deve ser conhecido (sem X/Z),
// responder sem erro na leitura e permanecer estavel, inclusive depois de uma
// tentativa de escrita (registrador somente leitura).
module test_id_sva #(
    // Se CHECK_ID_VALUE=1, o ID lido deve ser igual a EXPECTED_ID (Datasheet 6.6)
    parameter bit          CHECK_ID_VALUE = 1'b1,
    parameter logic [31:0] EXPECTED_ID    = 32'h5253_0200 
)(apb_rsa_if bus);
    import top_tb_pkg::*;

    wire transfer = bus.psel && bus.penable && bus.pready;
    wire id_read  = transfer && !bus.pwrite && bus.paddr == ID_ADDR;

    logic [31:0] first_id;
    bit          first_id_valid = 1'b0;

    always @(posedge bus.pclk or negedge bus.presetn) begin
        if (bus.presetn !== 1'b1)
            first_id_valid <= 1'b0;
        else if (id_read && !first_id_valid) begin
            first_id       <= bus.prdata;
            first_id_valid <= 1'b1;
        end
    end

    ap_id_read_response: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_test_id_active)
        id_read |-> (bus.pslverr === 1'b0)
    ) else env_pkg::scoreboard::record_assertion("test_id", "ID_READ_RESPONSE", 1'b0, "Leitura do ID respondeu com PSLVERR");

    ap_id_read_known: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_test_id_active)
        id_read |-> (!$isunknown(bus.prdata) && (!CHECK_ID_VALUE || bus.prdata === EXPECTED_ID))
    ) else env_pkg::scoreboard::record_assertion("test_id", "ID_READ_KNOWN", 1'b0,
        $sformatf("ID lido = 0x%08h (X/Z ou diferente do esperado 0x%08h)", $sampled(bus.prdata), EXPECTED_ID));

    // Toda leitura de ID deve repetir a primeira (antes e depois da escrita em 0x1C)
    ap_id_read_stable: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_test_id_active)
        (id_read && first_id_valid) |-> (bus.prdata === first_id)
    ) else env_pkg::scoreboard::record_assertion("test_id", "ID_READ_STABLE", 1'b0,
        $sformatf("ID mudou: primeira leitura 0x%08h, atual 0x%08h", $sampled(first_id), $sampled(bus.prdata)));

    cp_id_read_response: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_test_id_active)
        id_read && bus.pslverr === 1'b0
    ) env_pkg::scoreboard::record_assertion("test_id", "ID_READ_RESPONSE", 1'b1);

    cp_id_read_known: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_test_id_active)
        id_read && !$isunknown(bus.prdata) && (!CHECK_ID_VALUE || bus.prdata === EXPECTED_ID)
    ) env_pkg::scoreboard::record_assertion("test_id", "ID_READ_KNOWN", 1'b1);

    // PASS de estabilidade somente apos uma leitura que repete a primeira
    // (ou seja, depois de existir uma leitura anterior de referencia).
    cp_id_read_stable: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_test_id_active)
        id_read && first_id_valid && bus.prdata === first_id
    ) env_pkg::scoreboard::record_assertion("test_id", "ID_READ_STABLE", 1'b1);

    // Cenario completo: leitura -> escrita 0xFFFF_FFFF em ID -> leitura
    cp_id_scenario: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_test_id_active)
        id_read ##1 (!transfer)[*0:$] ##1 (transfer && bus.pwrite && bus.paddr == ID_ADDR)
        ##1 (!transfer)[*0:$] ##1 id_read
    ) env_pkg::scoreboard::record_assertion("test_id", "ID_SCENARIO_RUN", 1'b1);

endmodule
