////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class subscriber extends uvm_subscriber #(seq_item);

    `uvm_component_param_utils(subscriber)

////////////////////////////////////////////////
// Covergroups
////////////////////////////////////////////////
    covergroup apb_rsa with function sample (seq_item item);
        option.per_instance = 1;

        transaction_type: coverpoint item.transaction_type;
    endgroup


////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
// New
extern function new(string name, uvm_component parent);

      extern virtual function void write(seq_item t);

endclass : subscriber


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function subscriber::new(string name, uvm_component parent);
    super.new(name, parent);
  
  apb_rsa = new();
 
  
endfunction

////////////////////////////////////////////////
// 
////////////////////////////////////////////////
function void subscriber::write(seq_item t);
    
  apb_rsa.sample(t);

 endfunction

