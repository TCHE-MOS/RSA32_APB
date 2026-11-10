////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class test_rsa_operation extends test_base;

    `uvm_component_utils(test_rsa_operation)


////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name = "", uvm_component parent = null);

    // Phases
    extern function void build_phase(uvm_phase phase);

endclass : test_rsa_operation


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function test_rsa_operation::new(string name="", uvm_component parent = null);
    super.new(name, parent);
endfunction

////////////////////////////////////////////////
// Build phase
////////////////////////////////////////////////
function void test_rsa_operation::build_phase(uvm_phase phase);
    super.build_phase(phase);

  //sequence_rsa_operation::type_id::set_type_override(sequence_rsa_operation::get_type());

endfunction : build_phase


