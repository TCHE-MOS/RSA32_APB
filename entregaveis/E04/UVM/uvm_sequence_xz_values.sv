////////////////////////////////////////////////
// Regbank exploration with four-state APB payloads.
// No RSA operation or dedicated SVA is started by this sequence.
////////////////////////////////////////////////

class sequence_xz_values extends apb_base_sequence;

    `uvm_object_utils(sequence_xz_values)

    typedef enum {ALL_X, ALL_Z, BIT_XZ, BIT_ZX, NIBBLE_XZ, NIBBLE_ZX,
                  BYTE_XZ, BYTE_ZX} pattern_t;

    protected virtual apb_rsa_if vif;
    protected int unsigned completed[XZ_VALUES_PATTERN_COUNT];
    protected int unsigned reserved[XZ_VALUES_PATTERN_COUNT];
    protected int unsigned changed[XZ_VALUES_PATTERN_COUNT];
    protected int unsigned reads_with_x[XZ_VALUES_PATTERN_COUNT];
    protected int unsigned reads_with_z[XZ_VALUES_PATTERN_COUNT];
    protected int unsigned response_failures;
    protected int unsigned transactions;

    extern function new(string name = "sequence_xz_values");
    extern task body();
    extern protected function logic [31:0] make_payload(pattern_t pattern);
    extern protected function int unsigned count_state(logic [31:0] value, logic state);
    extern protected function string register_name(bit [11:0] addr);
    extern protected function void check_response(bit [11:0] addr, bit writing);
    extern protected task restore_registers();
    extern protected task sweep(pattern_t pattern);

endclass : sequence_xz_values

function sequence_xz_values::new(string name = "sequence_xz_values");
    super.new(name);
endfunction

function logic [31:0] sequence_xz_values::make_payload(pattern_t pattern);
    logic [31:0] value;
    int unsigned segment_width;
    bit reverse_order;
    if (pattern == ALL_X) return 'x;
    if (pattern == ALL_Z) return 'z;
    case (pattern)
        BIT_XZ, BIT_ZX:       segment_width = 1;
        NIBBLE_XZ, NIBBLE_ZX: segment_width = 4;
        default:             segment_width = 8;
    endcase
    reverse_order = pattern inside {BIT_ZX, NIBBLE_ZX, BYTE_ZX};
    // The name describes the order printed from bit 31 down to bit 0.
    for (int unsigned index = 0; index < 32; index++)
        value[31-index] = (((index / segment_width) % 2) ^ reverse_order) ? 1'bz : 1'bx;
    return value;
endfunction

function int unsigned sequence_xz_values::count_state(logic [31:0] value, logic state);
    return $countbits(value, state);
endfunction

function string sequence_xz_values::register_name(bit [11:0] addr);
    case ({addr[11:2], 2'b00})
        CTRL_ADDR:   return "CTRL";
        STATUS_ADDR: return "STATUS";
        IER_ADDR:    return "IER";
        MSG_ADDR:    return "MSG";
        EXP_ADDR:    return "EXP";
        MOD_ADDR:    return "MOD";
        RESULT_ADDR: return "RESULT";
        ID_ADDR:     return "ID";
        default:    return "RESERVADO";
    endcase
endfunction

function void sequence_xz_values::check_response(bit [11:0] addr, bit writing);
    bit expected_error;
    bit [11:0] word_addr = {addr[11:2], 2'b00};
    expected_error = addr >= 12'h020 ||
        (writing && (word_addr == RESULT_ADDR || word_addr == ID_ADDR));
    transactions++;
    if (last_pslverr !== expected_error) begin
        response_failures++;
        `uvm_error("XZ_RESPONSE", $sformatf(
            "addr=0x%03h %s PSLVERR=%b esperado=%b", addr,
            writing ? "WRITE" : "READ", last_pslverr, expected_error))
    end
endfunction

task sequence_xz_values::restore_registers();
    // Establish a known baseline without START or SRST commands.
    apb_write(IER_ADDR, '0); check_response(IER_ADDR, 1'b1);
    apb_write(MSG_ADDR, '0); check_response(MSG_ADDR, 1'b1);
    apb_write(EXP_ADDR, '0); check_response(EXP_ADDR, 1'b1);
    apb_write(MOD_ADDR, '0); check_response(MOD_ADDR, 1'b1);
    apb_write(STATUS_ADDR, 32'h6); check_response(STATUS_ADDR, 1'b1);
endtask

task sequence_xz_values::sweep(pattern_t pattern);
    logic [31:0] payload, before_value, after_value;
    logic before_error, write_error, after_error;
    bit [11:0] addr;
    bit [11:0] retention_addr[4] = '{IER_ADDR, MSG_ADDR, EXP_ADDR, MOD_ADDR};

    payload = make_payload(pattern);
    vif.xz_pattern_id = int'(pattern);
    vif.xz_payload = payload;
    `uvm_info("XZ_BEGIN", $sformatf(
        "[%s] INICIO | enderecos=0x000..0xFFF (passo=1 byte) | PWDATA=%032b X=%0d Z=%0d",
        pattern.name(), payload, count_state(payload, 1'bx), count_state(payload, 1'bz)), UVM_LOW)
    `uvm_info("XZ_TABLE", "t(ns) | rotina | endereco | registrador | ANTES[31:0] | ENVIADO[31:0] | DEPOIS[31:0] | PSLVERR R/W/R | X/Z depois | efeito", UVM_LOW)

    for (int unsigned index = 0; index < (1 << ADDR_WIDTH); index++) begin
        addr = index;
        vif.xz_address = addr;
        apb_read(addr, before_value);
        before_error = last_pslverr;
        check_response(addr, 1'b0);

        apb_write(addr, payload);
        write_error = last_pslverr;
        check_response(addr, 1'b1);
        // The driver holds PWDATA after item_done. Detect lost X/Z before
        // interpreting any observation of the DUT as a result of this payload.
        if (vif.pwdata !== payload)
            `uvm_fatal("XZ_TRANSPORT", $sformatf(
                "[%s] addr=0x%03h PWDATA=%032b enviado=%032b",
                pattern.name(), addr, vif.pwdata, payload))

        // apb_write finishes at a falling edge; add a full cycle before reading.
        @(negedge vif.pclk);
        apb_read(addr, after_value);
        after_error = last_pslverr;
        check_response(addr, 1'b0);

        completed[pattern]++;
        if (addr >= 12'h020) reserved[pattern]++;
        if (after_value !== before_value) changed[pattern]++;
        if (count_state(after_value, 1'bx) != 0) reads_with_x[pattern]++;
        if (count_state(after_value, 1'bz) != 0) reads_with_z[pattern]++;
        `uvm_info("XZ_ROW", $sformatf(
            "%0.3f | %-9s | 0x%03h | %-9s | %032b | %032b | %032b | %b/%b/%b | %02d/%02d | %s",
            $realtime, pattern.name(), addr, register_name(addr), before_value, payload,
            after_value, before_error, write_error, after_error,
            count_state(after_value, 1'bx), count_state(after_value, 1'bz),
            after_value === before_value ? "PRESERVADO" : "ALTERADO"), UVM_LOW)
    end

    // Observe storage again after all reserved writes, before cleaning it up.
    foreach (retention_addr[index]) begin
        apb_read(retention_addr[index], after_value);
        check_response(retention_addr[index], 1'b0);
        `uvm_info("XZ_RETENTION", $sformatf(
            "[%s] %s addr=0x%03h APOS_RESERVADOS=%032b X=%0d Z=%0d PSLVERR=%b",
            pattern.name(), register_name(retention_addr[index]), retention_addr[index],
            after_value, count_state(after_value, 1'bx), count_state(after_value, 1'bz), last_pslverr), UVM_LOW)
    end
endtask

task sequence_xz_values::body();
    pattern_t patterns[XZ_VALUES_PATTERN_COUNT] = '{ALL_X, ALL_Z, BIT_XZ, BIT_ZX,
        NIBBLE_XZ, NIBBLE_ZX, BYTE_XZ, BYTE_ZX};
    pattern_t summary_pattern;
    int unsigned total_completed = 0;
    realtime started_at = $realtime;

    if (!uvm_config_db #(virtual apb_rsa_if)::get(get_sequencer(), "", "apb_rsa_if", vif))
        `uvm_fatal("XZ_NOVIF", "Interface APB nao encontrada para observar dados de quatro estados")
    // A sequence instance may be started more than once.
    response_failures = 0;
    transactions = 0;
    foreach (completed[index]) begin
        completed[index] = 0;
        reserved[index] = 0;
        changed[index] = 0;
        reads_with_x[index] = 0;
        reads_with_z[index] = 0;
    end
    vif.xz_values_active = 1'b1;
    foreach (patterns[index]) begin
        restore_registers();
        sweep(patterns[index]);
    end
    restore_registers();
    vif.xz_values_active = 1'b0;
    foreach (patterns[index]) begin
        // Materialize the enum before name(): some simulators resolve an
        // indexed enum expression using a different imported enum type.
        summary_pattern = patterns[index];
        total_completed += completed[index];
        `uvm_info("XZ_SUMMARY", $sformatf(
            "%-9s | enderecos=%0d reservados=%0d alterados=%0d leituras_com_X=%0d leituras_com_Z=%0d",
            summary_pattern.name(), completed[index], reserved[index], changed[index],
            reads_with_x[index], reads_with_z[index]), UVM_LOW)
    end
    if (total_completed != XZ_VALUES_PATTERN_COUNT * (1 << ADDR_WIDTH))
        `uvm_fatal("XZ_INCOMPLETE", "Varredura incompleta do espaco de enderecos")
    `uvm_info("XZ_RESULT", $sformatf(
        "CONCLUIDO | rotinas=%0d enderecos=%0d transacoes=%0d falhas_resposta=%0d duracao=%0.3fns | dados invalidos: observacao, sem criterio SVA dedicado",
        XZ_VALUES_PATTERN_COUNT, total_completed, transactions, response_failures, $realtime - started_at), UVM_LOW)
endtask
