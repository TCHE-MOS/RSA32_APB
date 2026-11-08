////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: Reusable APB sequence tasks
// DUT: RSA_APB
////////////////////////////////////////////////

class apb_base_sequence extends uvm_sequence #(seq_item);

    `uvm_object_utils(apb_base_sequence)

    // Response of the most recent completed transfer, available to derived sequences.
    protected logic last_pslverr = 1'bx;

    extern function new(string name = "apb_base_sequence");

    extern protected task apb_write(
        input bit [11:0] addr,
        input logic [31:0] value = '0,
        input bit randomize_data = 1'b0
    );

    extern protected task apb_read(
        input  bit   [11:0] addr,
        output logic [31:0] value
    );

endclass : apb_base_sequence


function apb_base_sequence::new(string name = "apb_base_sequence");
    super.new(name);
endfunction


task apb_base_sequence::apb_write(
    input bit [11:0] addr,
    input logic [31:0] value = '0,
    input bit randomize_data = 1'b0
);
    seq_item wr_item;

    wr_item = seq_item::type_id::create("wr_item");

    start_item(wr_item);
    // Bypass randomization for directed values: constraint solvers generate
    // only 0/1 and cannot preserve a payload containing X/Z.
    if (randomize_data) begin
        wr_item.address_dist.constraint_mode(0);
        if (!wr_item.randomize() with {
            transaction_type == WRITE;
            address == local::addr;
        })
            `uvm_fatal("APB_WRITE_RAND", "Falha ao randomizar escrita APB")
    end else begin
        wr_item.transaction_type = WRITE;
        wr_item.address = addr;
        wr_item.data = value;
    end
    finish_item(wr_item);
    last_pslverr = wr_item.pslverr;
endtask


task apb_base_sequence::apb_read(
    input  bit   [11:0] addr,
    output logic [31:0] value
);
    seq_item rd_item;

    rd_item = seq_item::type_id::create("rd_item");

    start_item(rd_item);
    // Directed accesses must also reach addresses outside address_dist.
    rd_item.transaction_type = READ;
    rd_item.address = addr;
    rd_item.data = '0;
    finish_item(rd_item);
    last_pslverr = rd_item.pslverr;

    // The driver fills data with PRDATA before calling item_done().
    value = rd_item.data;
endtask
