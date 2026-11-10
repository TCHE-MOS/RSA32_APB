////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


package top_test_pkg;

    import uvm_pkg::*;
    import sequence_pkg::*;
    import agent_pkg::*;
    import env_pkg::*;
    import top_seq_pkg::*;


    // Components
    `include "uvm_test_base.sv"
    `include "uvm_test_rsa_operation.sv"


endpackage : top_test_pkg