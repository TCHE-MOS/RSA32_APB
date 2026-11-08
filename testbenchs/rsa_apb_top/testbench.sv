`timescale 1ns/1ps

module testbench;
    localparam integer DATA_WIDTH = 32;
    localparam integer ADDR_WIDTH = 12;
    // Configurable via -defparam; default clock is 100 MHz (10 ns).
    parameter realtime CLOCK_PERIOD_NS = 10.0;
    localparam integer RESET_WAIT_CYCLES = 5;
    localparam integer APB_TIMEOUT_CYCLES = 20;
    localparam integer TEST_ROUNDS = 30;
    localparam integer RSA_ROUNDS = 10;
    localparam integer RSA_TIMEOUT_POLLS = 10000;
    localparam integer EXPECTED_CHECKS = 8 + TEST_ROUNDS * 8 + RSA_ROUNDS * 15;
    // +MOD_ZERO adds a valid preparation (15 checks) and an error case (12 checks).
    localparam integer MOD_ZERO_CHECKS = 27;
    localparam integer MAX_CHECKS = EXPECTED_CHECKS + MOD_ZERO_CHECKS;
    localparam integer GLOBAL_TIMEOUT_CYCLES = 1000 + (RSA_ROUNDS + 2) * (RSA_TIMEOUT_POLLS * 3 + 100);
    localparam string TABLE_BORDER =
        "+-----+------------+-------------+-------+------------+------------+------------+--------+";

    localparam logic [ADDR_WIDTH-1:0] CTRL_ADDR   = 12'h000;
    localparam logic [ADDR_WIDTH-1:0] STATUS_ADDR = 12'h004;
    localparam logic [ADDR_WIDTH-1:0] IER_ADDR    = 12'h008;
    localparam logic [ADDR_WIDTH-1:0] MSG_ADDR    = 12'h00C;
    localparam logic [ADDR_WIDTH-1:0] EXP_ADDR    = 12'h010;
    localparam logic [ADDR_WIDTH-1:0] MOD_ADDR    = 12'h014;
    localparam logic [ADDR_WIDTH-1:0] RESULT_ADDR = 12'h018;
    localparam logic [ADDR_WIDTH-1:0] ID_ADDR     = 12'h01C;

    logic pclk_i = 1'b0;
    logic presetn_i;
    logic psel_i, penable_i, pwrite_i;
    logic [ADDR_WIDTH-1:0] paddr_i;
    logic [DATA_WIDTH-1:0] pwdata_i;
    wire [DATA_WIDTH-1:0] prdata_o;
    wire pready_o, pslverr_o, irq_o;

    logic [DATA_WIDTH-1:0] generic_value;
    logic [DATA_WIDTH-1:0] expected_registers [0:7];
    logic [DATA_WIDTH-1:0] last_write_data [0:7];
    bit write_seen [0:7];
    string failure_details [0:MAX_CHECKS-1];
    string scoreboard_phase;
    integer checks = 0;
    integer errors = 0;
    integer expected_checks_count = EXPECTED_CHECKS;
    bit mod_zero_enabled = 1'b0;
    string vcd_path;

    amba_3_apb_rsa_apb_top
`ifndef POST_SYNTHESIS
    #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        // rsa_core_ctrl waits for LOAD to fall between MSG, EXP and MOD.
        .LOAD_GAP(1)
    )
`endif
    dut (
        .pclk_i(pclk_i),
        .presetn_i(presetn_i),
        .psel_i(psel_i),
        .penable_i(penable_i),
        .pwrite_i(pwrite_i),
        .paddr_i(paddr_i),
        .pwdata_i(pwdata_i),
        .prdata_o(prdata_o),
        .pready_o(pready_o),
        .pslverr_o(pslverr_o),
        .irq_o(irq_o)
    );
    always #(CLOCK_PERIOD_NS / 2) pclk_i = ~pclk_i;

    // Driver: change APB inputs on falling edges, away from DUT sampling.
    task automatic drive_bus_idle;
        psel_i = 1'b0;
        penable_i = 1'b0;
        pwrite_i = 1'b0;
        paddr_i = '0;
        pwdata_i = '0;
    endtask

    task automatic wait_clock_cycles(input integer cycles);
        repeat (cycles) @(posedge pclk_i);
        // Allow sequential assignments and combinational outputs to settle.
        #1;
    endtask

    task automatic apply_hardware_reset;
        drive_bus_idle();
        presetn_i = 1'b0;
        wait_clock_cycles(2);
        @(negedge pclk_i);
        presetn_i = 1'b1;
        // Release the reset synchronizer before issuing the software reset.
        wait_clock_cycles(RESET_WAIT_CYCLES);
    endtask

    task automatic drive_apb_setup(
        input bit write_access,
        input logic [ADDR_WIDTH-1:0] address,
        input logic [DATA_WIDTH-1:0] write_data
    );
        @(negedge pclk_i);
        psel_i = 1'b1;
        penable_i = 1'b0;
        pwrite_i = write_access;
        paddr_i = address;
        pwdata_i = write_data;
    endtask

    task automatic drive_apb_access;
        // SETUP spans one rising edge before ACCESS is asserted.
        @(negedge pclk_i);
        penable_i = 1'b1;
    endtask

    task automatic monitor_apb_completion(
        output logic [DATA_WIDTH-1:0] read_data
    );
        integer cycles;
        bit completed;
        cycles = 0;
        completed = 1'b0;
        while (!completed && cycles < APB_TIMEOUT_CYCLES) begin
            @(posedge pclk_i);
            cycles = cycles + 1;
            if (pready_o === 1'b1) begin
                completed = 1'b1;
                // Sample at the completing edge, before deasserting ACCESS.
                read_data = prdata_o;
                if (pslverr_o !== 1'b0)
                    $fatal(1, "APB error: address=0x%03h write=%b PSLVERR=%b",
                           paddr_i, pwrite_i, pslverr_o);
            end
        end
        if (!completed)
            $fatal(1, "APB timeout: address=0x%03h", paddr_i);
        @(negedge pclk_i);
        drive_bus_idle();
    endtask

    task automatic apb_write(
        input logic [ADDR_WIDTH-1:0] address,
        input logic [DATA_WIDTH-1:0] write_data
    );
        logic [DATA_WIDTH-1:0] unused_read_data;
        drive_apb_setup(1'b1, address, write_data);
        drive_apb_access();
        monitor_apb_completion(unused_read_data);
        last_write_data[address >> 2] = write_data;
        write_seen[address >> 2] = 1'b1;
    endtask

    task automatic apb_read(
        input logic [ADDR_WIDTH-1:0] address,
        output logic [DATA_WIDTH-1:0] read_data
    );
        drive_apb_setup(1'b0, address, '0);
        drive_apb_access();
        monitor_apb_completion(read_data);
    endtask

    task automatic initialize_scoreboard;
        integer index;
        checks = 0;
        errors = 0;
        for (index = 0; index < 8; index = index + 1) begin
            last_write_data[index] = '0;
            write_seen[index] = 1'b0;
        end
    endtask

    task automatic scoreboard_begin_phase(input string phase_name);
        scoreboard_phase = phase_name;
        if (checks != 0)
            $display("%s", TABLE_BORDER);
        $display("\n[SCB] %s", phase_name);
        $display("%s", TABLE_BORDER);
        $display("|   # | Tempo (ns) | Registro    | End.  | Enviado    | Esperado   | Lido       | Status |");
        $display("%s", TABLE_BORDER);
    endtask

    // Scoreboard: compare expected and observed data, including X/Z detection.
    task automatic scoreboard_check(
        input string register_name,
        input logic [ADDR_WIDTH-1:0] address,
        input logic [DATA_WIDTH-1:0] expected_data,
        input logic [DATA_WIDTH-1:0] observed_data,
        input bit is_output = 1'b0
    );
        string sent_text;
        string result_text;
        string unknown_text;
        string address_text;
        if (is_output) begin
            address_text = "--";
            sent_text = "--";
        end else begin
            address_text = $sformatf("0x%03h", address);
            if (write_seen[address >> 2])
                sent_text = $sformatf("0x%08h", last_write_data[address >> 2]);
            else
                sent_text = "--";
        end
        unknown_text = "";
        if ($isunknown(observed_data))
            unknown_text = " [X/Z no dado lido]";
        checks = checks + 1;
        if (observed_data !== expected_data) begin
            result_text = "FAIL";
            if (errors < MAX_CHECKS)
                failure_details[errors] = $sformatf(
                    "#%0d [%s] %s @%s: esperado=0x%08h, lido=0x%08h, XOR=0x%08h%s",
                    checks, scoreboard_phase, register_name, address_text, expected_data, observed_data,
                    expected_data ^ observed_data,
                    unknown_text);
            errors = errors + 1;
        end else
            result_text = "PASS";
        $display("| %3d | %10.0f | %-11s | %-5s | %-10s | 0x%08h | 0x%08h | %-6s |",
                 checks, $realtime, register_name, address_text, sent_text,
                 expected_data, observed_data, result_text);
    endtask

    task automatic read_and_check_register(
        input string register_name,
        input logic [ADDR_WIDTH-1:0] address
    );
        logic [DATA_WIDTH-1:0] observed_data;
        apb_read(address, observed_data);
        scoreboard_check(register_name, address, expected_registers[address >> 2], observed_data);
    endtask

    task automatic apply_software_reset;
        // CTRL[1]=SRST; START is issued only in the later RSA phase.
        apb_write(CTRL_ADDR, 32'h0000_0002);
        wait_clock_cycles(RESET_WAIT_CYCLES);
        $display("[RESET] CTRL.SRST enviado; %0d clocks de espera concluidos.",
                 RESET_WAIT_CYCLES);
    endtask

    task automatic check_reset_values;
        integer index;
        for (index = 0; index < 8; index = index + 1)
            expected_registers[index] = '0;
        expected_registers[ID_ADDR >> 2] = 32'h5253_0200;
        scoreboard_begin_phase("Valores apos reset");
        read_and_check_register("CTRL", CTRL_ADDR);
        read_and_check_register("STATUS", STATUS_ADDR);
        read_and_check_register("IER", IER_ADDR);
        read_and_check_register("MSG", MSG_ADDR);
        read_and_check_register("EXP", EXP_ADDR);
        read_and_check_register("MOD", MOD_ADDR);
        read_and_check_register("RESULT", RESULT_ADDR);
        read_and_check_register("ID", ID_ADDR);
    endtask

    task automatic write_and_check_register(
        input string register_name,
        input logic [ADDR_WIDTH-1:0] address,
        input logic [DATA_WIDTH-1:0] write_data,
        input logic [DATA_WIDTH-1:0] implemented_mask
    );
        apb_write(address, write_data);
        // The reference comes from the stimulus, never from DUT internals.
        expected_registers[address >> 2] = write_data & implemented_mask;
        read_and_check_register(register_name, address);
    endtask

    task automatic test_register_writes(input integer round_number);
        logic [DATA_WIDTH-1:0] round_value;
        // Reproducible patterns: round 1 uses DATA; low bits cycle through IER's states.
        round_value = generic_value + 32'h9E37_79B9 * (round_number - 1);
        scoreboard_begin_phase($sformatf("Rodada %02d/%0d | Escrita e leitura imediata",
                                        round_number, TEST_ROUNDS));
        write_and_check_register("IER", IER_ADDR, round_value, 32'h0000_0003);
        write_and_check_register("MSG", MSG_ADDR, round_value, 32'hFFFF_FFFF);
        write_and_check_register("EXP", EXP_ADDR, round_value ^ 32'hA5A5_A5A5,
                                 32'hFFFF_FFFF);
        write_and_check_register("MOD", MOD_ADDR, round_value ^ 32'h5A5A_5A5A,
                                 32'hFFFF_FFFF);
    endtask

    task automatic check_register_retention(input integer round_number);
        // Distinct operands expose address aliasing and unintended overwrites.
        scoreboard_begin_phase($sformatf("Rodada %02d/%0d | Retencao apos todas as escritas",
                                        round_number, TEST_ROUNDS));
        read_and_check_register("IER", IER_ADDR);
        read_and_check_register("MSG", MSG_ADDR);
        read_and_check_register("EXP", EXP_ADDR);
        read_and_check_register("MOD", MOD_ADDR);
    endtask

    // Independent binary modular exponentiation; 64-bit products avoid 32-bit overflow.
    function automatic logic [DATA_WIDTH-1:0] reference_modexp(
        input logic [DATA_WIDTH-1:0] message,
        input logic [DATA_WIDTH-1:0] exponent,
        input logic [DATA_WIDTH-1:0] modulus
    );
        logic [63:0] accumulator, factor, product;
        logic [DATA_WIDTH-1:0] remaining_exponent;
        accumulator = 64'd1 % modulus;
        factor = {32'b0, message} % modulus;
        remaining_exponent = exponent;
        while (remaining_exponent != 0) begin
            if (remaining_exponent[0]) begin
                product = accumulator * factor;
                accumulator = product % modulus;
            end
            product = factor * factor;
            factor = product % modulus;
            remaining_exponent = remaining_exponent >> 1;
        end
        reference_modexp = accumulator[DATA_WIDTH-1:0];
    endfunction

    task automatic select_rsa_vector(
        input integer round_number,
        output logic [DATA_WIDTH-1:0] message,
        output logic [DATA_WIDTH-1:0] exponent,
        output logic [DATA_WIDTH-1:0] modulus
    );
        case (round_number)
             1: begin message = 65;           exponent = 17; modulus = 3233;         end
             2: begin message = 123;          exponent = 7;  modulus = 3233;         end
             3: begin message = 0;            exponent = 5;  modulus = 97;           end
             4: begin message = 1;            exponent = 13; modulus = 257;          end
             5: begin message = 42;           exponent = 0;  modulus = 97;           end
             6: begin message = 32'h12345678; exponent = 1;  modulus = 65521;        end
             7: begin message = 32'h80000001; exponent = 2;  modulus = 32'hFFFFFFFB; end
             8: begin message = 32'hFFFFFFFF; exponent = 3;  modulus = 32'hFFFFFFFB; end
             9: begin message = 123456789;    exponent = 7;  modulus = 65537;        end
            10: begin message = 32'hFEDCBA98; exponent = 17; modulus = 32'h8000000B; end
            default: $fatal(1, "Invalid RSA round: %0d", round_number);
        endcase
    endtask

    task automatic check_irq(input bit expected_irq);
        // A physical output has no APB address or write-data field.
        scoreboard_check("IRQ", '0, {31'b0, expected_irq}, {31'b0, irq_o}, 1'b1);
    endtask

    task automatic start_rsa_operation;
        expected_registers[STATUS_ADDR >> 2] = '0;
        read_and_check_register("STATUS.IDLE", STATUS_ADDR);
        check_irq(1'b0);
        apb_write(CTRL_ADDR, 32'h0000_0001);
        expected_registers[STATUS_ADDR >> 2] = 32'h0000_0001;
        read_and_check_register("STATUS.BUSY", STATUS_ADDR);
    endtask

    task automatic wait_rsa_completion;
        logic [DATA_WIDTH-1:0] status_data;
        integer polls;
        bit completed;
        polls = 0;
        completed = 1'b0;
        while (!completed && polls < RSA_TIMEOUT_POLLS) begin
            apb_read(STATUS_ADDR, status_data);
            polls = polls + 1;
            if ($isunknown(status_data))
                $fatal(1, "RSA [%s]: STATUS contains X/Z: 0x%08h", scoreboard_phase, status_data);
            completed = !status_data[0] && (status_data[1] || status_data[2]);
        end
        if (!completed)
            $fatal(1, "RSA timeout [%s]: %0d polls, STATUS=0x%08h",
                   scoreboard_phase, polls, status_data);
        // DONE=1, BUSY=0, ERROR=0. Polling itself does not inflate the check count.
        expected_registers[STATUS_ADDR >> 2] = 32'h0000_0002;
        scoreboard_check("STATUS.DONE", STATUS_ADDR, 32'h0000_0002, status_data);
        check_irq(1'b1);
        read_and_check_register("RESULT", RESULT_ADDR);
    endtask

    task automatic clear_rsa_status;
        // Both sticky flags are W1C; IRQ must fall after acknowledging them.
        apb_write(STATUS_ADDR, 32'h0000_0006);
        expected_registers[STATUS_ADDR >> 2] = '0;
        read_and_check_register("STATUS.IDLE", STATUS_ADDR);
        check_irq(1'b0);
    endtask

    task automatic test_rsa_vector(
        input string label,
        input logic [DATA_WIDTH-1:0] message, exponent, modulus
    );
        expected_registers[RESULT_ADDR >> 2] = reference_modexp(message, exponent, modulus);
        scoreboard_begin_phase({label, " | Carga dos operandos"});
        write_and_check_register("IER", IER_ADDR, 32'h0000_0003, 32'h0000_0003);
        write_and_check_register("MSG", MSG_ADDR, message, 32'hFFFF_FFFF);
        write_and_check_register("EXP", EXP_ADDR, exponent, 32'hFFFF_FFFF);
        write_and_check_register("MOD", MOD_ADDR, modulus, 32'hFFFF_FFFF);
        scoreboard_begin_phase($sformatf("%s | Execucao: MSG^EXP mod MOD = 0x%08h",
                                        label, expected_registers[RESULT_ADDR >> 2]));
        start_rsa_operation();
        wait_rsa_completion();
        scoreboard_begin_phase({label, " | Preservacao dos operandos e limpeza"});
        read_and_check_register("MSG", MSG_ADDR);
        read_and_check_register("EXP", EXP_ADDR);
        read_and_check_register("MOD", MOD_ADDR);
        clear_rsa_status();
    endtask

    task automatic test_rsa_operation(input integer round_number);
        logic [DATA_WIDTH-1:0] message, exponent, modulus;
        select_rsa_vector(round_number, message, exponent, modulus);
        test_rsa_vector($sformatf("RSA %02d/%0d", round_number, RSA_ROUNDS),
                        message, exponent, modulus);
    endtask

    // Independent reproduction of UVM corners case 10; no UVM or SVA is used here.
    task automatic test_mod_zero;
        logic [DATA_WIDTH-1:0] previous_result, result_data, status_data;
        integer polls;
        bit completed;

        // Recreate the valid result that preceded the failing UVM operation.
        test_rsa_vector("MOD_ZERO | Preparacao", 32'h0F1C_3861,
                        32'h0000_0009, 32'hC7C6_4DFB);
        scoreboard_begin_phase("MOD_ZERO | MSG=0x1C2F4FF3 EXP=10 MOD=0");
        write_and_check_register("MSG", MSG_ADDR, 32'h1C2F_4FF3, 32'hFFFF_FFFF);
        write_and_check_register("EXP", EXP_ADDR, 32'h0000_000A, 32'hFFFF_FFFF);
        write_and_check_register("MOD", MOD_ADDR, 32'h0000_0000, 32'hFFFF_FFFF);
        apb_read(RESULT_ADDR, previous_result);
        scoreboard_check("RESULT.PRE", RESULT_ADDR,
                         expected_registers[RESULT_ADDR >> 2], previous_result);
        start_rsa_operation();

        polls = 0;
        completed = 1'b0;
        while (!completed && polls < RSA_TIMEOUT_POLLS) begin
            apb_read(STATUS_ADDR, status_data);
            polls++;
            if ($isunknown(status_data))
                $fatal(1, "MOD_ZERO: STATUS contains X/Z: 0x%08h", status_data);
            completed = !status_data[0] && (status_data[1] || status_data[2]);
        end
        if (!completed)
            $fatal(1, "MOD_ZERO: timeout after %0d polls, STATUS=0x%08h", polls, status_data);

        // Datasheet 4.1/4.4: ERROR instead of DONE, BUSY cleared.
        scoreboard_check("STATUS.ERR", STATUS_ADDR, 32'h0000_0004, status_data);
        check_irq(1'b1);
        apb_read(RESULT_ADDR, result_data);
        // Datasheet 6.5: retain the value observed before the failed operation.
        scoreboard_check("RESULT.KEEP", RESULT_ADDR, previous_result, result_data);
        $display("[MOD_ZERO] polls=%0d STATUS=0x%08h BUSY=%b DONE=%b ERROR=%b RESULT_BEFORE=0x%08h RESULT_AFTER=0x%08h",
                 polls, status_data, status_data[0], status_data[1], status_data[2],
                 previous_result, result_data);
        clear_rsa_status();
    endtask

    task automatic report_results;
        integer index;
        $display("%s", TABLE_BORDER);
        $display("\n[SCB] RESUMO | regbank=%0d rodadas | RSA=%0d rodadas | MOD_ZERO=%b | previstas=%0d | realizadas=%0d | acertos=%0d | falhas=%0d | tempo=%0.0f ns",
                 TEST_ROUNDS, RSA_ROUNDS, mod_zero_enabled, expected_checks_count,
                 checks, checks - errors, errors, $realtime);
        if (errors != 0) begin
            $display("[SCB] Detalhes das divergencias:");
            for (index = 0; index < errors && index < MAX_CHECKS; index = index + 1)
                $display("  %s", failure_details[index]);
        end
        if (checks != expected_checks_count)
            $fatal(1, "Incomplete test: checks=%0d expected=%0d", checks, expected_checks_count);
        if (errors != 0)
            $fatal(1, "TEST FAIL: %0d errors in %0d checks", errors, checks);
        $display("TEST PASS: %0d checks, %0d errors", checks, errors);
    endtask

    task automatic run_test;
        integer round_number;
        mod_zero_enabled = $test$plusargs("MOD_ZERO");
        expected_checks_count = EXPECTED_CHECKS + (mod_zero_enabled ? MOD_ZERO_CHECKS : 0);
        if (!$value$plusargs("DATA=%h", generic_value))
            generic_value = 32'h1234_567B;
        $display("\n[TEST] amba_3_apb_rsa_apb_top | clock=%0.6f ns | dado=0x%08h | rodadas=%0d",
                 CLOCK_PERIOD_NS, generic_value, TEST_ROUNDS);
        initialize_scoreboard();
        apply_hardware_reset();
        apply_software_reset();
        check_reset_values();
        for (round_number = 1; round_number <= TEST_ROUNDS; round_number = round_number + 1) begin
            test_register_writes(round_number);
            check_register_retention(round_number);
        end
        for (round_number = 1; round_number <= RSA_ROUNDS; round_number = round_number + 1)
            test_rsa_operation(round_number);
        if (mod_zero_enabled) test_mod_zero();
        report_results();
    endtask

    initial begin
        if ($value$plusargs("VCD=%s", vcd_path)) begin
            $dumpfile(vcd_path);
            $dumpvars(0, testbench);
        end
        run_test();
        $finish;
    end

    // Independent watchdog also catches a stalled driver.
    initial begin
        #(CLOCK_PERIOD_NS * GLOBAL_TIMEOUT_CYCLES);
        $fatal(1, "Global simulation timeout");
    end
endmodule
