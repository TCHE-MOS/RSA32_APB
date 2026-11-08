////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class sequence_soft_reset extends apb_base_sequence;

    `uvm_object_param_utils(sequence_soft_reset)

////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name="sequence_soft_reset");

    // Tasks
    extern task body();

endclass : sequence_soft_reset


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function sequence_soft_reset::new(string name="sequence_soft_reset");
    super.new(name);
endfunction


////////////////////////////////////////////////
// Body
////////////////////////////////////////////////

task sequence_soft_reset::body();

        logic [31:0] status_before_reset;
        logic [31:0] status_after_reset;

        // 3) Carregar operandos:
        // 3.1) Escrever em 0x0C o valor <dado1>
        apb_write(.addr(MSG_ADDR), .randomize_data(1'b1));

        // 3.2) Escrever em 0x10 o valor <dado2>
        apb_write(.addr(EXP_ADDR), .randomize_data(1'b1));

        // 3.3) Escrever em 0x14 o valor <dado3>
        apb_write(.addr(MOD_ADDR), .randomize_data(1'b1));
        
        // 4) Disparar o start da operação
        // 4.1) Escrever em 0x00 o valor 0x01
        apb_write(CTRL_ADDR, 32'h0000_0001);

        // 5) Ler o status register antes do soft reset
        apb_read(STATUS_ADDR, status_before_reset);

        // 6) Aplicar soft reset
        // 6.1) Escrever em 0x00 o valor 0x02
        apb_write(CTRL_ADDR, 32'h0000_0002);

        // 7) Ler o status register após o soft reset
        apb_read(STATUS_ADDR, status_after_reset);

endtask

