////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class sequence_test_id extends apb_base_sequence;

    `uvm_object_param_utils(sequence_test_id)

////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name="sequence_test_id");

    // Tasks
    extern task body();

endclass : sequence_test_id


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function sequence_test_id::new(string name="sequence_test_id");
    super.new(name);
endfunction


////////////////////////////////////////////////
// Body
////////////////////////////////////////////////

task sequence_test_id::body();

        logic [31:0] status_before_test_id;
        logic [31:0] status_after_test_id;

        // 1) Ler o register ID antes do teste
        apb_read(ID_ADDR, status_before_test_id);

        // 2) Escrever em 0x1C o valor 0xFFFF_FFFF
        apb_write(ID_ADDR, 32'hFFFF_FFFF);

        // 3) Ler o register ID depois do teste
        apb_read(ID_ADDR, status_after_test_id);


endtask

