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
    int unsigned max_wait_cycles = 1000;


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

    int unsigned wait_cycles;

    vif.psel = 1'b0;
    vif.penable = 1'b0;
    vif.pwrite = 1'b0;
    vif.paddr = '0;
    vif.pwdata = '0;

    //  1) Iniciar o DUT com PRESETn = 0
    vif.presetn = 1'b0;

    // 2) Aguardar 10 ciclos de clock e colocar PRESETn = 1 na borda de descida do clock
    repeat(10) @(posedge vif.pclk);
    @(negedge vif.pclk);
    vif.presetn = 1'b1;

    forever begin

        seq_item_port.get_next_item(req);

        // Drive between sampling edges; SETUP spans a complete rising edge.
        @(negedge vif.pclk);
        vif.psel = 1'b1;
        vif.penable = 1'b0;
        vif.pwrite = (req.transaction_type == WRITE);
        vif.paddr = req.address;
        vif.pwdata = (req.transaction_type == WRITE) ? req.data : '0;

        @(negedge vif.pclk);
        vif.penable = 1'b1;

        wait_cycles = 0;
        forever begin
            @(posedge vif.pclk);
            if (vif.presetn !== 1'b1)
                `uvm_fatal("APB_RESET_DURING_TRANSFER", "Reset durante transferencia APB")
            if (vif.pready === 1'b1)
                break;
            wait_cycles++;
            if (wait_cycles >= max_wait_cycles)
                `uvm_fatal("APB_TRANSFER_TIMEOUT", "PREADY nao concluiu a transferencia APB")
        end

        req.pslverr = vif.pslverr;
        if (req.transaction_type == READ)
            req.data = vif.prdata;

        @(negedge vif.pclk);
        vif.psel = 1'b0;
        vif.penable = 1'b0;

        seq_item_port.item_done();

    end


endtask

