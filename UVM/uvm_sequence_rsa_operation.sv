////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class sequence_rsa_operation extends uvm_sequence #(seq_item);

    `uvm_object_param_utils(sequence_rsa_operation)

    seq_item item;
    int unsigned max_status_reads = 25_000;

////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name="sequence_rsa_operation");

    // Tasks
    extern task body();

endclass : sequence_rsa_operation


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function sequence_rsa_operation::new(string name="sequence_rsa_operation");
    super.new(name);
endfunction


////////////////////////////////////////////////
// Body
////////////////////////////////////////////////

task sequence_rsa_operation::body();

        logic [31:0] status_value;
        status_value = 'x;

        item = seq_item::type_id::create("item");

        // 3) Carregar operandos:
        // 3.1) Escrever em 0x0C o valor <dado1>
        start_item(item);
        if (!item.randomize() with {
            transaction_type == WRITE;
            address          == MSG_ADDR;
        }) begin
            `uvm_fatal("MSG_RAND", "Falha ao randomizar MSG")
        end
        finish_item(item);

        // 3.2) EXP aleatorio de 8 bits, estendido com zeros para 32 bits.
        start_item(item);
        if (!item.randomize() with {
            transaction_type == WRITE;
            address          == EXP_ADDR;
            data[31:8]       == 24'h000000;
        }) begin
            `uvm_fatal("EXP_RAND", "Falha ao randomizar EXP de 8 bits")
        end
        finish_item(item);

        //3.3) Escrever em 0x14 o valor <dado3>
        start_item(item);
        if (!item.randomize() with {
            transaction_type == WRITE;
            address == MOD_ADDR;
        }) begin
            `uvm_fatal("MOD_RAND", "Falha ao randomizar MOD")
        end
        finish_item(item);

        // 4) Diparar o start da operação
        // 4.1) Escrever em 0x00 o valor 0x01
        start_item(item);
        if (!item.randomize() with {
            transaction_type == WRITE;
            address          == CTRL_ADDR;
            data             == 'h01;
        }) begin
            `uvm_fatal("START_RAND", "Falha ao randomizar START")
        end
        finish_item(item);

        // 5) Consultar STATUS ate observar DONE (0x02).
        repeat (max_status_reads) begin
            start_item(item);
            if (!item.randomize() with {
                transaction_type == READ;
                address          == STATUS_ADDR;
            }) begin
                `uvm_fatal("RSA_STATUS_RAND", "Falha ao randomizar leitura de STATUS")
            end
            finish_item(item);

            // O driver captura PRDATA em item.data antes de item_done().
            status_value = item.data;
            if (status_value === 32'h0000_0002)
                break;
        end

        if (status_value !== 32'h0000_0002) begin
            `uvm_fatal("RSA_POLL_TIMEOUT", $sformatf(
                "STATUS nao retornou 0x02 apos %0d leituras. Ultimo valor: 0x%08h",
                max_status_reads, status_value))
        end


        // 6) Ler o resultado
        // 6.1) Ler do endereço 0x18
        start_item(item);
        if (!item.randomize() with {
            transaction_type == READ;
            address          == RESULT_ADDR;
        }) begin
            `uvm_fatal("RESULT_RAND", "Falha ao randomizar leitura de RESULT")
        end
        finish_item(item);

endtask
