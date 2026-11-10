////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class monitor  extends uvm_monitor;

  `uvm_component_param_utils(monitor)

////////////////////////////////////////////////
// Attributes
////////////////////////////////////////////////
    virtual interface apb_rsa_if vif;

////////////////////////////////////////////////
// Object instantiation
////////////////////////////////////////////////
    // Analysis Port
    uvm_analysis_port #(seq_item) monitor_ap;

////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name, uvm_component parent);

    // Phases
    extern function void build_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);

endclass : monitor


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function monitor::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

////////////////////////////////////////////////
// Build phase
////////////////////////////////////////////////
function void monitor::build_phase(uvm_phase phase);
    
    super.build_phase(phase);

    this.monitor_ap = new(.name("monitor_ap"),.parent(this));

endfunction


////////////////////////////////////////////////
// Build phase
////////////////////////////////////////////////
task monitor::run_phase(uvm_phase phase);
    seq_item observed_item;

    forever begin
        @(posedge vif.pclk);
        if (vif.presetn === 1'b1 && vif.psel === 1'b1 &&
            vif.penable === 1'b1 && vif.pready === 1'b1) begin
            observed_item = seq_item::type_id::create("observed_item");
            observed_item.transaction_type = vif.pwrite ? WRITE : READ;
            observed_item.address = vif.paddr;
            observed_item.data = vif.pwrite ? vif.pwdata : vif.prdata;
            observed_item.pslverr = vif.pslverr;
            monitor_ap.write(observed_item);
        end
    end

endtask
