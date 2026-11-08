////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class driver extends uvm_driver #(seq_item);

  `uvm_component_param_utils(driver)

////////////////////////////////////////////////
// Attributes
////////////////////////////////////////////////
    virtual interface apb_rsa_if vif;


////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name, uvm_component parent);

    // Phases
    extern task run_phase(uvm_phase phase);

endclass : driver


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function driver::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

////////////////////////////////////////////////
// Build phase
////////////////////////////////////////////////
task driver::run_phase(uvm_phase phase);

    //  1) Iniciar o DUT com PRESETn = 0
    vif.presetn = 1'b0;

    // 2) Aguardar 10 ciclos de clock e colocar PRESETn = 1 na borda de descida do clock
    repeat(10) @(posedge vif.pclk);
    @(negedge vif.pclk);
    vif.presetn = 1'b1;

    forever begin

        seq_item_port.get_next_item(req);

        if (req.transaction_type == READ) begin
            @(posedge vif.pclk);
            vif.psel      = 1'b1;
            vif.penable   = 1'b0;
            vif.pwrite    = 1'b0;
            vif.paddr     = req.address;

            @(posedge vif.pclk);
            vif.penable   = 1'b1;

            @(posedge vif.pclk);
            req.data      = vif.prdata;
            vif.psel      = 1'b0;
            vif.penable   = 1'b0;
        end
        else begin
            @(posedge vif.pclk);
            vif.psel      = 1'b1;
            vif.penable   = 1'b0;
            vif.pwrite    = 1'b1;
            vif.paddr     = req.address;
            vif.pwdata    = req.data;

            @(posedge vif.pclk);
            vif.penable   = 1'b1;

            @(posedge vif.pclk);
            vif.psel      = 1'b0;
            vif.penable   = 1'b0;
        end

        seq_item_port.item_done();

    end


endtask

