////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class scoreboard extends uvm_scoreboard;

    `uvm_component_utils(scoreboard)

    typedef struct {
        string scenario;
        string id;
        int unsigned passed;
        int unsigned failed;
        realtime last_time_ns;
        string detail;
    } assertion_row_t;

    static assertion_row_t assertion_rows[$];
    static int assertion_indices[string];
    static string active_scenario = "inicializacao";
    static bit assertion_table_printed = 0;
    static bit execution_complete = 0;
    static int unsigned sequence_transactions[string];
    static int unsigned sequence_failures[string];
    static int unsigned corners_case_id = 0;
    static int unsigned corners_width = 0;
    static int unsigned corners_kind = 0;

    static function string corners_group(int unsigned width, int unsigned kind);
        return $sformatf("corners%0d_%s", width, kind == 1 ? "INV" : (kind == 2 ? "ERR" : "OK"));
    endfunction

    static function void begin_corners_case(int unsigned id, int unsigned width, int unsigned kind);
        corners_case_id = id;
        corners_width = width;
        corners_kind = kind;
        active_scenario = corners_group(width, kind);
        void'(register_assertion(active_scenario, "CORNERS_EXP_WIDTH"));
        void'(register_assertion(active_scenario, "CORNERS_RESPONSE"));
        void'(register_assertion(active_scenario, "CORNERS_READBACK"));
        void'(register_assertion(active_scenario, "CORNERS_READ_DELAY"));
        void'(register_assertion(active_scenario, "CORNERS_W1C"));
        if (kind == 1) begin
            void'(register_assertion(active_scenario, "CORNERS_RO_PRESERVED"));
        end else begin
            void'(register_assertion(active_scenario, "CORNERS_STATUS"));
            void'(register_assertion(active_scenario, "CORNERS_COMPLETION"));
            void'(register_assertion(active_scenario, kind == 2 ? "CORNERS_ERROR_RESULT" : "CORNERS_RESULT_VALUE"));
        end
    endfunction

    static function int register_assertion(string scenario, string id);
        string key;
        assertion_row_t row;
        key = {scenario, "/", id};
        if (!assertion_indices.exists(key)) begin
            row.scenario = scenario;
            row.id = id;
            row.passed = 0;
            row.failed = 0;
            row.last_time_ns = 0;
            row.detail = "";
            assertion_rows.push_back(row);
            assertion_indices[key] = assertion_rows.size() - 1;
        end
        return assertion_indices[key];
    endfunction

    static function void init_assertion_log();
        assertion_rows.delete();
        assertion_indices.delete();
        sequence_transactions.delete();
        sequence_failures.delete();
        corners_case_id = 0;
        corners_width = 0;
        corners_kind = 0;
        assertion_table_printed = 0;
        execution_complete = 0;
        active_scenario = "inicializacao";
        void'(register_assertion("APB", "APB_SETUP_ACCESS"));
        void'(register_assertion("APB", "APB_ZERO_WAIT"));
        void'(register_assertion("APB", "APB_CTRL_READ_ZERO"));
        void'(register_assertion("APB", "APB_ID_VALUE"));
        void'(register_assertion("APB", "APB_STATUS_RESERVED"));
        void'(register_assertion("APB", "APB_IER_RESERVED"));
        void'(register_assertion("APB", "APB_IRQ_STATUS"));
        void'(register_assertion("APB", "APB_CONTROL_STABLE"));
        void'(register_assertion("APB", "APB_WRITE_DATA_STABLE"));
        void'(register_assertion("APB", "APB_WAIT_HOLD"));
        void'(register_assertion("APB", "APB_ACCESS_END"));
        void'(register_assertion("APB", "APB_ACCESS_ENTRY"));
        void'(register_assertion("APB", "APB_KNOWN_PHASE"));
        void'(register_assertion("APB", "APB_KNOWN_CONTROL"));
        void'(register_assertion("APB", "APB_KNOWN_WRITE_DATA"));
        void'(register_assertion("APB", "APB_KNOWN_READY"));
        void'(register_assertion("APB", "APB_KNOWN_ERROR"));
        void'(register_assertion("APB", "APB_KNOWN_READ_DATA"));
        void'(register_assertion("APB", "SVA_SCENARIO_CONFLICT"));
        void'(register_assertion("rsa_operation", "RSA_OPERATION_ORDER"));
        void'(register_assertion("rsa_operation", "RSA_OPERATION_RESPONSE"));
        void'(register_assertion("rsa_operation", "RSA_RESULT_BEFORE_DONE"));
        void'(register_assertion("rsa_operation", "RSA_RESULT_VALUE"));
        void'(register_assertion("rsa_operation", "RSA_STATUS_VALUE"));
        void'(register_assertion("soft_reset", "SOFT_RESET_ORDER"));
        void'(register_assertion("soft_reset", "SOFT_RESET_RESPONSE"));
        void'(register_assertion("soft_reset", "SOFT_RESET_STATUS"));
    endfunction

    static function void record_assertion(
        string scenario, string id, bit passed, string detail = ""
    );
        int index;
        index = register_assertion(scenario, id);
        if (passed) begin
            assertion_rows[index].passed++;
            if (assertion_rows[index].failed == 0)
                assertion_rows[index].last_time_ns = $realtime;
            if (id == "RSA_OPERATION_ORDER" || id == "RSA_RESULT_BEFORE_DONE" ||
                id == "SOFT_RESET_ORDER" || id == "SOFT_RESET_STATUS")
                uvm_pkg::uvm_report_info("SVA_DEBUG", $sformatf("[%s][%s] PASS", scenario, id), UVM_LOW);
        end else begin
            assertion_rows[index].failed++;
            assertion_rows[index].last_time_ns = $realtime;
            assertion_rows[index].detail = detail;
            sequence_failures[scenario == "APB" ? active_scenario : scenario]++;
            uvm_pkg::uvm_report_error(id, detail);
        end
    endfunction

    static function void report_sequence_result(string scenario);
        int unsigned missing = 0;
        int unsigned failures;
        string result;
        foreach (assertion_rows[index]) begin
            if (assertion_rows[index].scenario == scenario &&
                assertion_rows[index].passed == 0 && assertion_rows[index].failed == 0)
                missing++;
        end
        failures = sequence_failures.exists(scenario) ? sequence_failures[scenario] : 0;
        result = failures != 0 ? "FAIL" : (missing != 0 ? "INCOMPLETO" : "PASS");
        uvm_pkg::uvm_report_info("SEQ_RESULT", $sformatf(
            "[%s] %s | transacoes=%0d falhas_SVA=%0d verificacoes_sem_resultado=%0d",
            scenario, result, sequence_transactions.exists(scenario) ? sequence_transactions[scenario] : 0,
            failures, missing), UVM_LOW);
    endfunction

    static function string table_cell(string value, int width, bit align_right = 0);
        while (value.len() < width)
            value = align_right ? {" ", value} : {value, " "};
        return value;
    endfunction

    static function void print_assertion_table(
        int unsigned corners_planned = 0, int unsigned corners_completed = 0,
        bit corners_running = 0, int unsigned current_case = 0
    );
        string border;
        string result;
        string instant;
        uvm_report_server server;
        bit aborted;
        int passed = 0;
        int failed = 0;
        int unexercised = 0;
        int interrupted = 0;
        if (assertion_table_printed) return;
        assertion_table_printed = 1;
        server = uvm_report_server::get_server();
        aborted = !execution_complete || server.get_severity_count(UVM_FATAL) != 0;
        border = "+----------------+----------------------------+-------------+---------+---------+--------------+";
        $display("\n[SVA] RESULTADOS DAS ASSERTIONS | %s | cenario atual: %s",
                 aborted ? "EXECUCAO INTERROMPIDA" : "FIM DA EXECUCAO", active_scenario);
        if (corners_planned != 0) begin
            $display("[CAMPANHA] planejados=%0d concluidos=%0d interrompidos=%0d nao_iniciados=%0d caso_atual=%0d",
                corners_planned, corners_completed, corners_running,
                corners_planned - corners_completed - int'(corners_running), current_case);
        end
        $display("%s", border);
        $display("| %s | %s | %s | %s | %s | %s |",
                 table_cell("Cenario", 14), table_cell("Assertion", 26),
                 table_cell("Resultado", 11), table_cell("Acertos", 7, 1),
                 table_cell("Falhas", 7, 1), table_cell("Instante(ns)", 12, 1));
        $display("%s", border);
        foreach (assertion_rows[index]) begin
            if (assertion_rows[index].failed != 0) begin
                result = "FAIL";
                failed++;
            end else if (assertion_rows[index].passed != 0) begin
                result = "PASS";
                passed++;
            end else if (aborted && assertion_rows[index].scenario == active_scenario) begin
                result = "INTERROMP.";
                interrupted++;
            end else begin
                result = "NAO EXERC.";
                unexercised++;
            end
            instant = (assertion_rows[index].passed + assertion_rows[index].failed == 0)
                ? "--" : $sformatf("%0.3f", assertion_rows[index].last_time_ns);
            $display("| %s | %s | %s | %s | %s | %s |",
                     table_cell(assertion_rows[index].scenario, 14),
                     table_cell(assertion_rows[index].id, 26), table_cell(result, 11),
                     table_cell($sformatf("%0d", assertion_rows[index].passed), 7, 1),
                     table_cell($sformatf("%0d", assertion_rows[index].failed), 7, 1),
                     table_cell(instant, 12, 1));
        end
        $display("%s", border);
        $display("[SVA] Assertions: %0d PASS | %0d FAIL | %0d NAO EXERCITADAS | %0d INTERROMPIDAS",
                 passed, failed, unexercised, interrupted);
        foreach (assertion_rows[index]) begin
            if (assertion_rows[index].failed != 0)
                $display("[SVA][%s][%s] %s", table_cell(assertion_rows[index].scenario, 0),
                         table_cell(assertion_rows[index].id, 0), table_cell(assertion_rows[index].detail, 0));
        end
        $display("[SVA] Instante indica a ultima ocorrencia; havendo falha, indica a ultima falha.");
        $display("[SVA] Contagens finais UVM: ERROR=%0d | FATAL=%0d\n",
                 server.get_severity_count(UVM_ERROR), server.get_severity_count(UVM_FATAL));
    endfunction

////////////////////////////////////////////////
// Analysis Export
////////////////////////////////////////////////
    `uvm_analysis_imp_decl(_apb_rsa)
    uvm_analysis_imp_apb_rsa #(seq_item, scoreboard) analysis_export_apb_rsa_aep;

    //protected uvm_tlm_analysis_fifo #(seq_item) apb_rsa_fifo;

////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name, uvm_component parent);

    // Phases
    extern function void build_phase(uvm_phase phase);
    extern function void write_apb_rsa(seq_item t);


endclass : scoreboard


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function scoreboard::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

////////////////////////////////////////////////
// Build phase
////////////////////////////////////////////////
function void scoreboard::build_phase(uvm_phase phase);
    super.build_phase(phase);

    analysis_export_apb_rsa_aep = new("analysis_export_apb_rsa_aep", this);
    
    //apb_rsa_fifo = new("apb_rsa_fifo", this);
    
endfunction : build_phase



////////////////////////////////////////////////
// Write function
////////////////////////////////////////////////
function void scoreboard::write_apb_rsa(seq_item t);
    string register_name;
    string status_detail;
    bit expected_pslverr;
    bit corners_context;
    logic [top_tb_pkg::ADDR_WIDTH-1:0] word_addr;
    word_addr = {t.address[top_tb_pkg::ADDR_WIDTH-1:2], 2'b00};
    case (word_addr)
        top_tb_pkg::CTRL_ADDR:   register_name = "CTRL";
        top_tb_pkg::STATUS_ADDR: register_name = "STATUS";
        top_tb_pkg::IER_ADDR:    register_name = "IER";
        top_tb_pkg::MSG_ADDR:    register_name = "MSG";
        top_tb_pkg::EXP_ADDR:    register_name = "EXP";
        top_tb_pkg::MOD_ADDR:    register_name = "MOD";
        top_tb_pkg::RESULT_ADDR: register_name = "RESULT";
        top_tb_pkg::ID_ADDR:     register_name = "ID";
        default:                register_name = "RESERVADO";
    endcase
    status_detail = "";
    if (word_addr == top_tb_pkg::CTRL_ADDR && t.transaction_type == WRITE)
        status_detail = $sformatf(" START=%b SRST=%b", t.data[0], t.data[1]);
    if (word_addr == top_tb_pkg::STATUS_ADDR && t.transaction_type == READ)
        status_detail = $sformatf(" BUSY=%b DONE=%b ERROR=%b", t.data[0], t.data[1], t.data[2]);
    expected_pslverr = 1'b0;
    corners_context = active_scenario == corners_group(corners_width, corners_kind);
    if (corners_context) begin
        expected_pslverr = t.transaction_type == WRITE &&
            (word_addr == top_tb_pkg::RESULT_ADDR || word_addr == top_tb_pkg::ID_ADDR);
        status_detail = {status_detail, $sformatf(" caso=%0d EXP_BITS=%0d PSLVERR_EXPECTED=%b",
                         corners_case_id, corners_width, expected_pslverr)};
    end
    sequence_transactions[active_scenario]++;
    `uvm_info("SEQ_DEBUG", $sformatf(
        "[%s][%0d] t=%0.3fns %s %s addr=0x%03h data=0x%08h PSLVERR=%b RESPOSTA=%s%s",
        active_scenario, sequence_transactions[active_scenario], $realtime,
        t.transaction_type == WRITE ? "WRITE" : "READ", register_name, t.address,
        t.data, t.pslverr, t.pslverr === expected_pslverr ? "PASS" : "FAIL", status_detail), UVM_LOW)
endfunction
