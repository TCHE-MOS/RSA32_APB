////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


package sequence_pkg;

    import uvm_pkg::*;
    import top_tb_pkg::*;

    // Basic parameters
    typedef enum {READ, WRITE} transaction_type_t;

    // File list
    `include "uvm_seq_item.sv"

    // Sequence
    `include "uvm_sequence.sv"
    `include "uvm_sequence_rsa_operation.sv"
    `include "uvm_sequence_soft_reset.sv"
    `include "uvm_sequence_test_id.sv"

endpackage : sequence_pkg