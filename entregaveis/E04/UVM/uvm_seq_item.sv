////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class seq_item extends uvm_sequence_item;

    `uvm_object_utils_begin(seq_item)
    `uvm_object_utils_end

////////////////////////////////////////////////
// Fields
////////////////////////////////////////////////
    // Write or READ
    rand transaction_type_t     transaction_type;
    rand logic [31:0]           data;
    rand logic [11:0]           address;
    logic                      pslverr;

////////////////////////////////////////////////
// Constraints
////////////////////////////////////////////////
    constraint address_dist {
        address dist {
            'h00    := 5,
            'h04    := 5,
            'h08    := 5,
            'h0C    := 5,
            'h10    := 5,
            'h14    := 5,
            'h18    := 5,
            'h1C    := 5
        };
    }


////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
  extern function new(string name="");

endclass : seq_item


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function seq_item::new(string name="");
    super.new(name);
endfunction




