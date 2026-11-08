`timescale 1ns/1ps

module corners_exp_sva(apb_rsa_if bus);
    import top_tb_pkg::*;

    wire transfer = bus.psel && bus.penable && bus.pready;
    wire [ADDR_WIDTH-1:0] word_addr = {bus.paddr[ADDR_WIDTH-1:2], 2'b00};
    // Datasheet 6.7: writes to read-only registers fail in every testcase.
    wire expected_error = bus.pwrite && (word_addr == RESULT_ADDR || word_addr == ID_ADDR);
    wire operand_write = transfer && bus.pwrite && bus.pslverr === 1'b0 &&
                         bus.sva_corners_readback_active;
    wire operand_read = transfer && !bus.pwrite && bus.pslverr === 1'b0 &&
                        bus.sva_corners_readback_active;
    wire exp_write = operand_write && word_addr == EXP_ADDR;
    wire status_read = transfer && !bus.pwrite && word_addr == STATUS_ADDR && bus.pslverr === 1'b0;
    wire terminal_status = status_read && (bus.prdata[1] || bus.prdata[2]);
    wire start_write = transfer && bus.pwrite && word_addr == CTRL_ADDR &&
                       bus.pslverr === 1'b0 && bus.pwdata[0] === 1'b1 && bus.pwdata[1] === 1'b0;
    wire result_check = transfer && !bus.pwrite && bus.pslverr === 1'b0 && bus.sva_corners_result_check;
    wire clear_write = transfer && bus.pwrite && word_addr == STATUS_ADDR &&
                       bus.pslverr === 1'b0 && bus.pwdata[2:1] === 2'b11 && !bus.sva_corners_operation_active;
    wire [31:0] expected_status = bus.sva_corners_case_kind == 2 ? 32'h4 : 32'h2;

    function automatic string result_id();
        case (bus.sva_corners_case_kind)
            1: return "CORNERS_RO_PRESERVED";
            2: return "CORNERS_ERROR_RESULT";
            default: return "CORNERS_RESULT_VALUE";
        endcase
    endfunction

    sequence s_next_status;
        (!transfer)[*0:$] ##1 status_read;
    endsequence

    function automatic bit exp_fits_width(logic [31:0] value, int unsigned width);
        if ($isunknown(value)) return 1'b0;
        case (width)
            4:  return value[31:4] == '0;
            8:  return value[31:8] == '0;
            12: return value[31:12] == '0;
            16: return value[31:16] == '0;
            32: return 1'b1;
            default: return 1'b0;
        endcase
    endfunction

    // This is logging context only; temporal checks remain in assert property.
    int unsigned logged_case_id = 0;
    bit logged_active = 1'b0;
    always @(posedge bus.pclk) begin
        if (bus.sva_corners_exp_active) begin
            if (!logged_active || bus.sva_corners_case_id != logged_case_id) begin
                env_pkg::scoreboard::begin_corners_case(bus.sva_corners_case_id,
                    bus.sva_corners_exp_width, bus.sva_corners_case_kind);
                logged_case_id = bus.sva_corners_case_id;
            end
        end
        logged_active = bus.sva_corners_exp_active;
    end

    function automatic void record_check(string id, bit passed, string detail);
        string context_detail;
        context_detail = $sformatf("[caso=%0d EXP=%0d bits tipo=%0d] %s",
            bus.sva_corners_case_id, bus.sva_corners_exp_width, bus.sva_corners_case_kind, detail);
        env_pkg::scoreboard::record_assertion(
            env_pkg::scoreboard::corners_group(bus.sva_corners_exp_width, bus.sva_corners_case_kind),
            id, passed, context_detail);
        // Ordinary response successes are already visible in SEQ_DEBUG.
        if (passed && (id != "CORNERS_RESPONSE" || expected_error) &&
            (id != "CORNERS_STATUS" || terminal_status))
            uvm_pkg::uvm_report_info("CORNERS_SVA", {id, " PASS | ", context_detail}, uvm_pkg::UVM_LOW);
    endfunction

    ap_exp_width: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        exp_write |-> exp_fits_width(bus.pwdata, bus.sva_corners_exp_width)
    ) else record_check("CORNERS_EXP_WIDTH", 1'b0,
        $sformatf("EXP aplicado=0x%08h excede a largura selecionada", $sampled(bus.pwdata)));

    ap_response: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active)
        transfer |-> bus.pslverr === expected_error
    ) else record_check("CORNERS_RESPONSE", 1'b0,
        $sformatf("addr=0x%03h PWRITE=%b PSLVERR EXPECTED=%b ACTUAL=%b",
            $sampled(bus.paddr), $sampled(bus.pwrite), $sampled(expected_error), $sampled(bus.pslverr)));

    ap_readback: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        operand_read |-> (bus.paddr === bus.sva_corners_readback_addr &&
                          !$isunknown(bus.prdata) && bus.prdata === bus.sva_corners_readback_data)
    ) else record_check("CORNERS_READBACK", 1'b0,
        $sformatf("addr EXPECTED=0x%03h ACTUAL=0x%03h data EXPECTED=0x%08h ACTUAL=0x%08h",
            $sampled(bus.sva_corners_readback_addr), $sampled(bus.paddr),
            $sampled(bus.sva_corners_readback_data), $sampled(bus.prdata)));

    // Datasheet 4.1/4.4: valid completion has DONE only; MOD=0 has ERROR only.
    ap_status: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        (status_read && bus.sva_corners_operation_active)
        |-> (bus.prdata === 32'h1 || bus.prdata === expected_status)
    ) else record_check("CORNERS_STATUS", 1'b0,
        $sformatf("STATUS esperado BUSY=0x01 ou final=0x%08h ACTUAL=0x%08h",
            $sampled(expected_status), $sampled(bus.prdata)));

    // No fixed arithmetic latency is specified. The testcase watchdog bounds execution.
    ap_completion: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (start_write && bus.sva_corners_exp_active && !bus.sva_corners_recovery)
        |=> strong((bus.sva_corners_exp_active && bus.sva_corners_operation_active && !bus.sva_corners_recovery)
            throughout ((!terminal_status)[*0:$] ##1 terminal_status))
    ) else record_check("CORNERS_COMPLETION", 1'b0,
        "START sem leitura de conclusao antes do encerramento ou recuperacao do caso");

    // Expected data comes from independent arithmetic or from the read before the rejected operation.
    // Datasheet 6.5 requires RESULT retention on MOD=0; 6.7 rejects writes to RESULT/ID.
    ap_result: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        result_check |-> (word_addr === bus.sva_corners_result_addr &&
            !$isunknown({bus.prdata, bus.sva_corners_expected_result}) &&
            bus.prdata === bus.sva_corners_expected_result)
    ) else record_check(result_id(), 1'b0,
        $sformatf("addr EXPECTED=0x%03h ACTUAL=0x%03h RESULT EXPECTED=0x%08h ACTUAL=0x%08h",
            $sampled(bus.sva_corners_result_addr), $sampled(word_addr),
            $sampled(bus.sva_corners_expected_result), $sampled(bus.prdata)));

    ap_w1c: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (clear_write && bus.sva_corners_exp_active && !bus.sva_corners_recovery)
        |=> strong((bus.sva_corners_exp_active && !bus.sva_corners_recovery)
            throughout (s_next_status ##0 (bus.prdata === 32'h0)))
    ) else record_check("CORNERS_W1C", 1'b0, "STATUS nao retornou zero apos limpar DONE/ERROR com W1C");

    // The current driver has one IDLE sample between ordinary transfers.
    // The extra falling-edge wait in write_readback adds a second IDLE sample.
    ap_read_delay: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        operand_write |=> !bus.psel ##1 !bus.psel
    ) else record_check("CORNERS_READ_DELAY", 1'b0,
        "Ciclo adicional de espera entre escrita e leitura nao foi respeitado");

    // Match actual observations; vacuous implications do not produce PASS.
    cp_status: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        status_read && bus.sva_corners_operation_active && (bus.prdata === 32'h1 || bus.prdata === expected_status)
    ) record_check("CORNERS_STATUS", 1'b1, $sformatf("STATUS=0x%08h", $sampled(bus.prdata)));

    cp_completion: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (start_write && bus.sva_corners_exp_active && !bus.sva_corners_recovery)
        ##1 ((bus.sva_corners_exp_active && bus.sva_corners_operation_active && !bus.sva_corners_recovery)
            throughout ((!terminal_status)[*0:$] ##1 terminal_status))
    ) record_check("CORNERS_COMPLETION", 1'b1, "Conclusao observada por polling");

    cp_result: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        result_check && word_addr === bus.sva_corners_result_addr &&
        !$isunknown({bus.prdata, bus.sva_corners_expected_result}) && bus.prdata === bus.sva_corners_expected_result
    ) record_check(result_id(), 1'b1, $sformatf("RESULT EXPECTED=0x%08h ACTUAL=0x%08h",
        $sampled(bus.sva_corners_expected_result), $sampled(bus.prdata)));

    cp_w1c: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (clear_write && bus.sva_corners_exp_active && !bus.sva_corners_recovery)
        ##1 ((bus.sva_corners_exp_active && !bus.sva_corners_recovery)
            throughout (s_next_status ##0 (bus.prdata === 32'h0)))
    ) record_check("CORNERS_W1C", 1'b1, "STATUS=0 apos W1C");

    cp_exp_width: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        exp_write && exp_fits_width(bus.pwdata, bus.sva_corners_exp_width)
    ) record_check("CORNERS_EXP_WIDTH", 1'b1, $sformatf("EXP=0x%08h", $sampled(bus.pwdata)));

    cp_response: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active)
        transfer && bus.pslverr === expected_error
    ) record_check("CORNERS_RESPONSE", 1'b1,
        $sformatf("addr=0x%03h PSLVERR EXPECTED=%b ACTUAL=%b",
            $sampled(bus.paddr), $sampled(expected_error), $sampled(bus.pslverr)));

    cp_readback: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        operand_read && bus.paddr === bus.sva_corners_readback_addr &&
        !$isunknown(bus.prdata) && bus.prdata === bus.sva_corners_readback_data
    ) record_check("CORNERS_READBACK", 1'b1,
        $sformatf("addr=0x%03h EXPECTED=0x%08h ACTUAL=0x%08h",
            $sampled(bus.paddr), $sampled(bus.sva_corners_readback_data), $sampled(bus.prdata)));

    cp_read_delay: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_corners_exp_active || bus.sva_corners_recovery)
        operand_write ##1 !bus.psel ##1 !bus.psel
    ) record_check("CORNERS_READ_DELAY", 1'b1, "Ciclo adicional de espera observado");
endmodule
