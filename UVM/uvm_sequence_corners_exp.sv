////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Description: Random RSA operands and exponent-width corners
////////////////////////////////////////////////

class sequence_corners_exp extends apb_base_sequence;

    `uvm_object_utils(sequence_corners_exp)

    typedef enum {VALID_OPERATION, INVALID_APB, ERROR_MOD_ZERO} case_kind_t;

    rand bit [31:0] din, exp, mod;
    rand bit invalid_target_id;
    int unsigned exp_width = 4;
    case_kind_t case_kind = VALID_OPERATION;

    // Extensive profile: 64-bit cycle budgets, independent of the number of reads.
    int unsigned num_testcases = CORNERS_TOTAL_CASES;
    longint unsigned base_cycles = 1024;
    longint unsigned cycles_per_exp = 256;
    longint unsigned poll_interval_cycles = 16;
    // Zero disables the optional diagnostic read cap.
    longint unsigned max_status_reads = 0;

    constraint c_exp_width {
        exp_width inside {4, 8, 12, 16, 32};
        if (exp_width == 4)  exp[31:4]  == '0;
        if (exp_width == 8)  exp[31:8]  == '0;
        if (exp_width == 12) exp[31:12] == '0;
        if (exp_width == 16) exp[31:16] == '0;
        // At width 32 all bits of exp are available.
    }

    constraint c_operation_kind {
        if (case_kind == ERROR_MOD_ZERO) mod == 0;
        else                            mod != 0;
    }

    protected virtual apb_rsa_if vif;
    protected int unsigned case_id;
    protected bit case_failed, case_timed_out;
    protected int unsigned errors_at_case_start;
    localparam int CASES_PER_WIDTH[5] = '{CORNERS_CASES_EXP_4, CORNERS_CASES_EXP_8,
        CORNERS_CASES_EXP_12, CORNERS_CASES_EXP_16, CORNERS_CASES_EXP_32};
    protected int unsigned passed[5], failed[5], timed_out[5];

    extern function new(string name = "sequence_corners_exp");
    extern task body();
    extern protected function void check_condition(bit condition, string detail);
    extern protected function bit has_case_failure();
    extern protected function longint unsigned operation_cycles();
    extern protected function void select_case(int unsigned index,
        output int unsigned width_index, output case_kind_t kind);
    extern protected function logic [31:0] reference_modexp();
    extern protected task write_readback(bit [11:0] addr, bit [31:0] value);
    extern protected task recover_core();
    extern protected task run_case();

endclass : sequence_corners_exp

function sequence_corners_exp::new(string name = "sequence_corners_exp");
    super.new(name);
endfunction

function bit sequence_corners_exp::has_case_failure();
    uvm_report_server server;
    server = uvm_report_server::get_server();
    return case_failed || server.get_severity_count(UVM_ERROR) > errors_at_case_start;
endfunction

function void sequence_corners_exp::check_condition(bit condition, string detail);
    if (!condition) begin
        case_failed = 1'b1;
        `uvm_error("CORNERS_CHECK", $sformatf("[caso=%0d EXP=%0d bits %s] FAIL | %s",
                   case_id, exp_width, case_kind.name(), detail))
    end else begin
        `uvm_info("CORNERS_CHECK", $sformatf("[caso=%0d EXP=%0d bits %s] PASS | %s",
                  case_id, exp_width, case_kind.name(), detail), UVM_LOW)
    end
endfunction

function void sequence_corners_exp::select_case(int unsigned index,
    output int unsigned width_index, output case_kind_t kind);
    int unsigned remaining;
    if (index >= CORNERS_TOTAL_CASES)
        `uvm_fatal("CORNERS_CONFIG", "Indice fora das cotas definidas em top_tb_pkg.svh")
    remaining = index;
    // Interleave enabled widths until each header quota is exhausted.
    for (int unsigned ordinal = 0; ordinal < CORNERS_TOTAL_CASES; ordinal++) begin
        foreach (CASES_PER_WIDTH[width]) begin
            if (ordinal < CASES_PER_WIDTH[width]) begin
                if (remaining == 0) begin
                    width_index = width;
                    case (ordinal % 10)
                        8:       kind = INVALID_APB;
                        9:       kind = ERROR_MOD_ZERO;
                        default: kind = VALID_OPERATION;
                    endcase
                    return;
                end
                remaining--;
            end
        end
    end
endfunction

function longint unsigned sequence_corners_exp::operation_cycles();
    if (case_kind == ERROR_MOD_ZERO) return base_cycles;
    return base_cycles + cycles_per_exp * ({32'b0, exp} + 64'd1);
endfunction

function logic [31:0] sequence_corners_exp::reference_modexp();
    logic [63:0] accumulator, factor, divisor;
    if (mod == 0) return 'x;
    divisor = {32'b0, mod};
    accumulator = 64'd1 % divisor;
    factor = {32'b0, din} % divisor;
    for (int unsigned index = 0; index < 32; index++) begin
        if (exp[index]) accumulator = (accumulator * factor) % divisor;
        factor = (factor * factor) % divisor;
    end
    return accumulator[31:0];
endfunction

task sequence_corners_exp::write_readback(bit [11:0] addr, bit [31:0] value);
    logic [31:0] observed;
    vif.sva_corners_readback_addr = addr;
    vif.sva_corners_readback_data = value;
    vif.sva_corners_readback_active = 1'b1;
    apb_write(addr, value);
    case_failed = has_case_failure();
    if (!case_failed) begin
        // apb_write returns on a falling edge; the next edge adds a full cycle.
        @(negedge vif.pclk);
        apb_read(addr, observed);
        case_failed = has_case_failure();
    end
    vif.sva_corners_readback_active = 1'b0;
endtask

task sequence_corners_exp::recover_core();
    logic [31:0] status;
    vif.sva_corners_recovery = 1'b1;
    vif.sva_corners_operation_active = 1'b0;
    vif.sva_corners_result_check = 1'b0;
    vif.sva_corners_readback_active = 1'b0;
    `uvm_info("CORNERS_RECOVERY", $sformatf("[caso=%0d] Aplicando SRST", case_id), UVM_LOW)
    apb_write(CTRL_ADDR, 32'h2);
    if (!vif.sva_corners_exp_active)
        check_condition(last_pslverr === 1'b0, "SRST aceito");
    // Clear sticky completion/error events sampled around the reset pulse.
    @(negedge vif.pclk);
    apb_write(STATUS_ADDR, 32'h6);
    if (!vif.sva_corners_exp_active)
        check_condition(last_pslverr === 1'b0, "Limpeza W1C apos SRST aceita");
    for (int unsigned attempt = 0; attempt < 10; attempt++) begin
        @(negedge vif.pclk);
        apb_read(STATUS_ADDR, status);
        if (last_pslverr === 1'b0 && status === 32'h0) begin
            `uvm_info("CORNERS_RECOVERY", "STATUS=0: nucleo pronto para o proximo caso", UVM_LOW)
            vif.sva_corners_recovery = 1'b0;
            return;
        end
    end
    `uvm_fatal("CORNERS_RECOVERY", $sformatf(
        "[caso=%0d] SRST nao recuperou o nucleo: STATUS=0x%08h PSLVERR=%b",
        case_id, status, last_pslverr))
endtask

task sequence_corners_exp::run_case();
    logic [31:0] previous_result, observed, status, expected;
    bit [11:0] invalid_addr;
    bit completed;
    longint unsigned reads, budget, started_cycle, elapsed_cycles, remaining, poll_cycles;
    bit read_limit_hit;

    expected = reference_modexp();
    `uvm_info("CORNERS_BEGIN", $sformatf(
        "[caso=%0d EXP=%0d bits %s] DIN=0x%08h EXP=0x%08h MOD=0x%08h EXPECTED=0x%08h",
        case_id, exp_width, case_kind.name(), din, exp, mod, expected), UVM_LOW)

    write_readback(MSG_ADDR, din);
    if (case_failed) return;
    write_readback(EXP_ADDR, exp);
    if (case_failed) return;
    write_readback(MOD_ADDR, mod);
    if (case_failed) return;

    if (case_kind == INVALID_APB) begin
        // A forbidden write is checked independently of RSA computation latency.
        invalid_addr = invalid_target_id ? ID_ADDR : RESULT_ADDR;
        apb_read(invalid_addr, previous_result);
        case_failed = has_case_failure();
        check_condition(!$isunknown(previous_result), "Leitura anterior a escrita proibida");
        if (case_failed) return;
        apb_write(invalid_addr, ~previous_result);
        case_failed = has_case_failure();
        @(negedge vif.pclk);
        vif.sva_corners_result_addr = invalid_addr;
        vif.sva_corners_expected_result = previous_result;
        vif.sva_corners_result_check = 1'b1;
        apb_read(invalid_addr, observed);
        vif.sva_corners_result_check = 1'b0;
        case_failed = has_case_failure();
        return;
    end

    apb_read(RESULT_ADDR, previous_result);
    case_failed = has_case_failure();
    check_condition(!$isunknown(previous_result),
                    $sformatf("RESULT antes de START=0x%08h", previous_result));
    if (case_failed) return;
    budget = operation_cycles();
    // Keep about 1024 observations even for long operations; DONE/ERROR are sticky.
    poll_cycles = poll_interval_cycles;
    if (max_status_reads == 0 && budget / 1024 > poll_cycles)
        poll_cycles = budget / 1024;
    `uvm_info("CORNERS_BUDGET", $sformatf(
        "[caso=%0d] limite=%0d ciclos polling_interval=%0d ciclos read_cap=%0d",
        case_id, budget, poll_cycles, max_status_reads), UVM_LOW)
    vif.sva_corners_expected_result = case_kind == ERROR_MOD_ZERO ? previous_result : expected;
    vif.sva_corners_operation_active = 1'b1;
    apb_write(CTRL_ADDR, 32'h1);
    started_cycle = vif.cycle_count;
    case_failed = has_case_failure();
    if (case_failed) return;

    completed = 1'b0;
    read_limit_hit = 1'b0;
    reads = 0;
    status = 'x;
    elapsed_cycles = 0;
    while (elapsed_cycles < budget) begin
        // Finish an APB transfer before evaluating the deadline; never abandon an item.
        apb_read(STATUS_ADDR, status);
        reads++;
        elapsed_cycles = vif.cycle_count - started_cycle;
        case_failed = has_case_failure();
        if ($isunknown(status)) begin
            check_condition(1'b0, $sformatf("Polling invalido STATUS=0x%08h", status));
            return;
        end
        if (elapsed_cycles > budget) break;
        if (status[1] || status[2]) begin
            completed = 1'b1;
            break;
        end
        if (case_failed) return;
        if (max_status_reads != 0 && reads >= max_status_reads) begin
            read_limit_hit = 1'b1;
            break;
        end
        remaining = budget - elapsed_cycles;
        // Reserve the current driver's three cycles for a final status transfer.
        if (remaining > 3) remaining -= 3;
        else remaining = 0;
        if (remaining > poll_cycles) remaining = poll_cycles;
        repeat (remaining) @(negedge vif.pclk);
        elapsed_cycles = vif.cycle_count - started_cycle;
    end
    `uvm_info("CORNERS_POLL", $sformatf(
        "[caso=%0d] leituras=%0d ciclos=%0d limite=%0d STATUS=0x%08h",
        case_id, reads, elapsed_cycles, budget, status), UVM_LOW)
    if (!completed) begin
        case_timed_out = 1'b1;
        check_condition(1'b0, read_limit_hit
            ? "TIMEOUT: limite diagnostico de leituras atingido; resultado nao validado"
            : "TIMEOUT: orcamento de ciclos atingido sem DONE/ERROR; resultado nao validado");
        return;
    end

    vif.sva_corners_result_addr = RESULT_ADDR;
    vif.sva_corners_result_check = 1'b1;
    apb_read(RESULT_ADDR, observed);
    vif.sva_corners_result_check = 1'b0;
    vif.sva_corners_operation_active = 1'b0;
    case_failed = has_case_failure();
endtask

task sequence_corners_exp::body();
    int unsigned widths[5] = '{4, 8, 12, 16, 32};
    int unsigned width_index, passed_total, failed_total, timeout_total;
    int unsigned planned_counts[5];
    case_kind_t planned_kind;
    logic [31:0] status;
    realtime started_at;

    if (!uvm_config_db #(virtual apb_rsa_if)::get(get_sequencer(), "", "apb_rsa_if", vif))
        `uvm_fatal("CORNERS_NOVIF", "Interface APB nao encontrada para aguardar o clock")
    vif.sva_corners_exp_active = 1'b0;
    vif.sva_corners_operation_active = 1'b0;
    vif.sva_corners_result_check = 1'b0;
    vif.sva_corners_readback_active = 1'b0;
    vif.sva_corners_recovery = 1'b0;
    errors_at_case_start = uvm_report_server::get_server().get_severity_count(UVM_ERROR);
    foreach (CASES_PER_WIDTH[index]) begin
        if (CASES_PER_WIDTH[index] < 0)
            `uvm_fatal("CORNERS_CONFIG", "As cotas de top_tb_pkg.svh nao podem ser negativas")
    end
    if (num_testcases == 0 || num_testcases > CORNERS_TOTAL_CASES || base_cycles == 0 || cycles_per_exp == 0 || poll_interval_cycles == 0)
        `uvm_fatal("CORNERS_CONFIG", "Casos devem estar entre 1 e CORNERS_TOTAL_CASES; os parametros de ciclos devem ser positivos")
    vif.sva_corners_cases_planned = num_testcases;
    vif.sva_corners_cases_completed = 0;
    foreach (passed[index]) begin
        passed[index] = 0;
        failed[index] = 0;
        timed_out[index] = 0;
        planned_counts[index] = 0;
    end
    for (int unsigned index = 0; index < num_testcases; index++) begin
        select_case(index, width_index, planned_kind);
        planned_counts[width_index]++;
    end
    foreach (widths[index]) begin
        `uvm_info("CORNERS_PLAN", $sformatf("EXP_BITS=%0d CASOS=%0d",
                  widths[index], planned_counts[index]), UVM_LOW)
    end
    case_id = 0;
    case_failed = 1'b0;
    case_timed_out = 1'b0;
    apb_read(STATUS_ADDR, status);
    if (last_pslverr !== 1'b0 || status !== 32'h0) recover_core();

    for (int unsigned testcase = 0; testcase < num_testcases; testcase++) begin
        case_id = testcase + 1;
        select_case(testcase, width_index, case_kind);
        exp_width = widths[width_index];
        case_failed = 1'b0;
        case_timed_out = 1'b0;
        if (!this.randomize())
            `uvm_fatal("CORNERS_RAND", $sformatf("Falha ao randomizar caso %0d, EXP=%0d bits", case_id, exp_width))
        errors_at_case_start = uvm_report_server::get_server().get_severity_count(UVM_ERROR);
        vif.sva_corners_case_id = case_id;
        vif.sva_corners_exp_width = exp_width;
        vif.sva_corners_case_kind = case_kind;
        vif.sva_corners_exp_active = 1'b1;
        started_at = $realtime;
        run_case();
        case_failed = has_case_failure();

        if (case_failed) begin
            recover_core();
        end else begin
            // DONE/ERROR are sticky W1C flags; normal cases do not need a reset.
            apb_write(STATUS_ADDR, 32'h6);
            @(negedge vif.pclk);
            apb_read(STATUS_ADDR, status);
            case_failed = has_case_failure();
            if (case_failed) recover_core();
        end
        case_failed = has_case_failure();
        vif.sva_corners_cases_completed++;
        vif.sva_corners_exp_active = 1'b0;
        if (case_failed) failed[width_index]++;
        else             passed[width_index]++;
        if (case_timed_out) timed_out[width_index]++;
        `uvm_info("CORNERS_RESULT", $sformatf(
            "[caso=%0d EXP=%0d bits %s] %s | duracao=%0.3fns",
            case_id, exp_width, case_kind.name(),
            case_timed_out ? "TIMEOUT" : (case_failed ? "FAIL" : "PASS"), $realtime - started_at), UVM_LOW)
    end
    passed_total = 0;
    failed_total = 0;
    timeout_total = 0;
    foreach (widths[index]) begin
        passed_total += passed[index];
        failed_total += failed[index];
        timeout_total += timed_out[index];
        `uvm_info("CORNERS_SUMMARY", $sformatf(
            "EXP=%0d bits | PASS=%0d FAIL=%0d (inclui TIMEOUT=%0d)",
            widths[index], passed[index], failed[index], timed_out[index]), UVM_LOW)
    end
    `uvm_info("CORNERS_SUMMARY", $sformatf(
        "TOTAL=%0d PASS=%0d FAIL=%0d (inclui TIMEOUT=%0d)",
        num_testcases, passed_total, failed_total, timeout_total), UVM_LOW)
endtask
