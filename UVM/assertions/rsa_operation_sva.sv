`timescale 1ns/1ps

module rsa_operation_sva(apb_rsa_if bus);
    import top_tb_pkg::*;

    wire transfer = bus.psel && bus.penable && bus.pready;
    wire [ADDR_WIDTH-1:0] word_addr = {bus.paddr[ADDR_WIDTH-1:2], 2'b00};
    wire status_read = transfer && !bus.pwrite && word_addr == STATUS_ADDR && bus.pslverr === 1'b0;
    wire done_read = status_read && bus.prdata === 32'h2;
    wire result_read = transfer && !bus.pwrite && word_addr == RESULT_ADDR;
    wire start_write = transfer && bus.pwrite && word_addr == CTRL_ADDR &&
                       bus.pslverr === 1'b0 && bus.pwdata[0] === 1'b1 && bus.pwdata[1] === 1'b0;

    typedef struct packed {
        logic [31:0] msg;
        logic [31:0] exponent;
        logic [31:0] modulus;
    } operands_t;

    operands_t operands, started_operands;
    logic [31:0] expected_result;
    bit expected_valid = 1'b0;

    // Independent arithmetic reference: M**e mod n, with 64-bit products.
    function automatic logic [31:0] reference_modexp(
        input logic [31:0] msg, exponent, modulus
    );
        logic [63:0] accumulator, factor, divisor;
        if ($isunknown({msg, exponent, modulus}) || modulus == 0)
            return 'x;
        divisor = {32'b0, modulus};
        accumulator = 64'd1 % divisor;
        factor = {32'b0, msg} % divisor;
        for (int unsigned index = 0; index < 32; index++) begin
            if (exponent[index])
                accumulator = (accumulator * factor) % divisor;
            factor = (factor * factor) % divisor;
        end
        return accumulator[31:0];
    endfunction

    // Capture bus values only when the slave accepts the write.
    always @(posedge bus.pclk or negedge bus.presetn) begin
        if (bus.presetn !== 1'b1) begin
            operands <= '0;
            started_operands <= '0;
            expected_result <= 'x;
            expected_valid <= 1'b0;
        end else if (transfer && bus.pwrite && bus.pslverr === 1'b0) begin
            case (word_addr)
                MSG_ADDR: operands.msg <= bus.pwdata;
                EXP_ADDR: operands.exponent <= bus.pwdata;
                MOD_ADDR: operands.modulus <= bus.pwdata;
                CTRL_ADDR: begin
                    if (bus.pwdata[1] === 1'b1)
                        expected_valid <= 1'b0;
                    else if (bus.pwdata[0] === 1'b1) begin
                        started_operands <= operands;
                        expected_result <= reference_modexp(operands.msg, operands.exponent, operands.modulus);
                        expected_valid <= !$isunknown(operands) && operands.modulus != 0;
                        if (bus.sva_rsa_operation_active)
                            uvm_pkg::uvm_report_info("RSA_REFERENCE", $sformatf(
                                "MSG=0x%08h EXP=0x%08h MOD=0x%08h EXPECTED=0x%08h",
                                operands.msg, operands.exponent, operands.modulus,
                                reference_modexp(operands.msg, operands.exponent, operands.modulus)), uvm_pkg::UVM_LOW);
                    end
                end
            endcase
        end
    end

    sequence s_next_write(addr);
        (!transfer)[*0:$] ##1 (transfer && bus.pwrite && word_addr == addr);
    endsequence

    sequence s_next_read(addr);
        (!transfer)[*0:$] ##1 (transfer && !bus.pwrite && word_addr == addr);
    endsequence

    sequence s_operation;
        s_next_write(MSG_ADDR)
        ##1 s_next_write(EXP_ADDR)
        ##1 s_next_write(MOD_ADDR)
        ##1 s_next_write(CTRL_ADDR) ##0 (bus.pwdata === 32'h1)
        ##1 ((!transfer || (status_read && !done_read))[*0:$] ##1 done_read)
        ##1 s_next_read(RESULT_ADDR);
    endsequence

    property p_operation_order;
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        $rose(bus.sva_rsa_operation_active && bus.presetn)
        |-> strong(bus.sva_rsa_operation_active throughout s_operation);
    endproperty

    ap_operation_order: assert property (p_operation_order)
        else env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_OPERATION_ORDER", 1'b0, "Ordem incorreta ou cenario RSA incompleto");

    ap_operation_response: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_rsa_operation_active)
        transfer |-> (bus.pslverr === 1'b0)
    ) else env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_OPERATION_RESPONSE", 1'b0, "Erro APB inesperado na operacao RSA");

    ap_result_after_done: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        (start_write && bus.sva_rsa_operation_active)
        |=> strong(bus.sva_rsa_operation_active throughout ((!result_read)[*0:$] ##1 done_read))
    ) else env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_RESULT_BEFORE_DONE", 1'b0, "STATUS=0x02 nao observado antes de RESULT ou do encerramento");

    ap_status_value: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_rsa_operation_active)
        status_read |-> (bus.prdata === 32'h1 || bus.prdata === 32'h2)
    ) else env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_STATUS_VALUE", 1'b0,
        $sformatf("Operacao valida exige BUSY=0x01 ou DONE=0x02; STATUS=0x%08h", $sampled(bus.prdata)));

    cp_status_value: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_rsa_operation_active)
        status_read && (bus.prdata === 32'h1 || bus.prdata === 32'h2)
    ) env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_STATUS_VALUE", 1'b1);

    ap_result_value: assert property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_rsa_operation_active)
        (result_read && bus.pslverr === 1'b0)
        |-> (expected_valid && !$isunknown(bus.prdata) && bus.prdata === expected_result)
    ) else env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_RESULT_VALUE", 1'b0,
        $sformatf("MSG=0x%08h EXP=0x%08h MOD=0x%08h EXPECTED=0x%08h ACTUAL=0x%08h REF_VALID=%b",
            $sampled(started_operands.msg), $sampled(started_operands.exponent),
            $sampled(started_operands.modulus), $sampled(expected_result),
            $sampled(bus.prdata), $sampled(expected_valid)));

    cp_result_value: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_rsa_operation_active)
        result_read && bus.pslverr === 1'b0 && expected_valid
        && !$isunknown(bus.prdata) && bus.prdata === expected_result
    ) begin
        env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_RESULT_VALUE", 1'b1);
        uvm_pkg::uvm_report_info("RSA_RESULT_VALUE", $sformatf(
            "MSG=0x%08h EXP=0x%08h MOD=0x%08h EXPECTED=0x%08h ACTUAL=0x%08h",
            $sampled(started_operands.msg), $sampled(started_operands.exponent),
            $sampled(started_operands.modulus), $sampled(expected_result), $sampled(bus.prdata)), uvm_pkg::UVM_LOW);
    end

    cp_done: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1 || !bus.sva_rsa_operation_active)
        start_write ##1 ((!result_read)[*0:$] ##1 done_read)
    ) env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_RESULT_BEFORE_DONE", 1'b1);

    cp_operation_response: cover property (
        @(posedge bus.pclk) bus.presetn && bus.sva_rsa_operation_active && transfer && bus.pslverr === 1'b0
    ) env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_OPERATION_RESPONSE", 1'b1);

    cp_complete: cover property (
        @(posedge bus.pclk) disable iff (bus.presetn !== 1'b1)
        $rose(bus.sva_rsa_operation_active && bus.presetn)
        ##0 (bus.sva_rsa_operation_active throughout s_operation)
    ) env_pkg::scoreboard::record_assertion("rsa_operation", "RSA_OPERATION_ORDER", 1'b1);

endmodule
