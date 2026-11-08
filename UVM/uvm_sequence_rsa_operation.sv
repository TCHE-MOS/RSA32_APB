////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class sequence_rsa_operation extends apb_base_sequence;

    `uvm_object_param_utils(sequence_rsa_operation)

    int unsigned max_status_reads = 10_000;

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
        logic [31:0] result_value;

        // 3) Carregar operandos:
        // 3.1) Escrever em 0x0C o valor <dado1>
        apb_write(.addr(MSG_ADDR), .randomize_data(1'b1));

        // 3.2) Escrever em 0x10 o valor <dado2>
        apb_write(.addr(EXP_ADDR), .randomize_data(1'b1));

        //3.3) Escrever em 0x14 o valor <dado3>
        apb_write(.addr(MOD_ADDR), .randomize_data(1'b1));
        
        // 4) Diparar o start da operação
        // 4.1) Escrever em 0x00 o valor 0x01
        apb_write(CTRL_ADDR, 32'h0000_0001);

        // 5) Consultar STATUS até o valor ser 0x02
        repeat (max_status_reads) begin
            apb_read(STATUS_ADDR, status_value);
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
        apb_read(RESULT_ADDR, result_value);

endtask
