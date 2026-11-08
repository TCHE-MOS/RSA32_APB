`timescale 1ns/1ps

module apb_protocol_sva(apb_rsa_if bus);

    wire transfer = bus.psel && bus.penable && bus.pready;

    ap_setup_access: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && !bus.penable) |=> (bus.psel && bus.penable)
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_SETUP_ACCESS", 1'b0, "SETUP deve ser seguido de ACCESS");

    ap_control_stable: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && (!bus.penable || !bus.pready))
        |=> $stable({bus.paddr, bus.pwrite})
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_CONTROL_STABLE", 1'b0, "Endereco ou direcao mudou durante a transferencia");

    ap_write_data_stable: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && bus.pwrite && (!bus.penable || !bus.pready))
        |=> $stable(bus.pwdata)
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_WRITE_DATA_STABLE", 1'b0, "PWDATA mudou durante a escrita");

    ap_wait_hold: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && bus.penable && !bus.pready) |=> (bus.psel && bus.penable)
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_WAIT_HOLD", 1'b0, "ACCESS foi interrompido antes de PREADY");

    ap_access_end: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        transfer |=> !bus.penable
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_ACCESS_END", 1'b0, "PENABLE deve baixar apos a conclusao");

    ap_access_entry: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && bus.penable) |-> $past(bus.psel && (!bus.penable || !bus.pready))
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_ACCESS_ENTRY", 1'b0, "ACCESS sem SETUP ou espera anterior");

    ap_known_phase: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        !$isunknown({bus.psel, bus.penable})
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_PHASE", 1'b0, "PSEL ou PENABLE contem X/Z");

    ap_known_control: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        bus.psel |-> !$isunknown({bus.paddr, bus.pwrite})
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_CONTROL", 1'b0, "Endereco ou direcao contem X/Z");

    ap_known_write_data: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && bus.pwrite) |-> !$isunknown(bus.pwdata)
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_WRITE_DATA", 1'b0, "PWDATA contem X/Z em escrita selecionada");

    ap_known_ready: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && bus.penable) |-> !$isunknown(bus.pready)
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_READY", 1'b0, "PREADY contem X/Z durante ACCESS");

    ap_known_error: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        transfer |-> !$isunknown(bus.pslverr)
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_ERROR", 1'b0, "PSLVERR contem X/Z na conclusao");

    ap_known_read_data: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (transfer && !bus.pwrite && !bus.pslverr) |-> !$isunknown(bus.prdata)
    ) else env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_READ_DATA", 1'b0, "PRDATA contem X/Z em leitura concluida sem erro");

    ap_scenario_exclusive: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        !(bus.sva_rsa_operation_active && bus.sva_soft_reset_active)
    ) else env_pkg::scoreboard::record_assertion("APB", "SVA_SCENARIO_CONFLICT", 1'b0, "Dois cenarios SVA foram ativados simultaneamente");

    // Log PASS only for a matching observation, never for a vacuous implication.
    cp_setup_access: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && !bus.penable) ##1 (bus.psel && bus.penable))
        env_pkg::scoreboard::record_assertion("APB", "APB_SETUP_ACCESS", 1'b1);
    cp_control_stable: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && (!bus.penable || !bus.pready)) ##1 $stable({bus.paddr, bus.pwrite}))
        env_pkg::scoreboard::record_assertion("APB", "APB_CONTROL_STABLE", 1'b1);
    cp_write_data_stable: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && bus.pwrite && (!bus.penable || !bus.pready)) ##1 $stable(bus.pwdata))
        env_pkg::scoreboard::record_assertion("APB", "APB_WRITE_DATA_STABLE", 1'b1);
    cp_wait_hold: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (bus.psel && bus.penable && !bus.pready) ##1 (bus.psel && bus.penable))
        env_pkg::scoreboard::record_assertion("APB", "APB_WAIT_HOLD", 1'b1);
    cp_access_end: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        transfer ##1 !bus.penable)
        env_pkg::scoreboard::record_assertion("APB", "APB_ACCESS_END", 1'b1);
    cp_access_entry: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        bus.psel && bus.penable && $past(bus.psel && (!bus.penable || !bus.pready)))
        env_pkg::scoreboard::record_assertion("APB", "APB_ACCESS_ENTRY", 1'b1);
    cp_known_phase: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        !$isunknown({bus.psel, bus.penable}))
        env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_PHASE", 1'b1);
    cp_known_control: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        bus.psel && !$isunknown({bus.paddr, bus.pwrite}))
        env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_CONTROL", 1'b1);
    cp_known_write_data: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        bus.psel && bus.pwrite && !$isunknown(bus.pwdata))
        env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_WRITE_DATA", 1'b1);
    cp_known_ready: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        bus.psel && bus.penable && !$isunknown(bus.pready))
        env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_READY", 1'b1);
    cp_known_error: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        transfer && !$isunknown(bus.pslverr))
        env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_ERROR", 1'b1);
    cp_known_read_data: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        transfer && !bus.pwrite && !bus.pslverr && !$isunknown(bus.prdata))
        env_pkg::scoreboard::record_assertion("APB", "APB_KNOWN_READ_DATA", 1'b1);
    cp_scenario_exclusive: cover property (@(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        !(bus.sva_rsa_operation_active && bus.sva_soft_reset_active))
        env_pkg::scoreboard::record_assertion("APB", "SVA_SCENARIO_CONFLICT", 1'b1);

endmodule
