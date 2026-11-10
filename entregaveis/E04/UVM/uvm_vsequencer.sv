////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class vsequencer extends uvm_sequencer #(seq_item);

    `uvm_component_param_utils(vsequencer)
  
  
   	sequencer       	sequencer_h;

////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name, uvm_component parent);

endclass : vsequencer


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function vsequencer::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction