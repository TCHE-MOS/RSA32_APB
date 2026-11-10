////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class agent extends uvm_agent;

    `uvm_component_param_utils(agent)

////////////////////////////////////////////////
// Test components instantiation
////////////////////////////////////////////////
    agent_config        config_h;
  
    monitor       	 	monitor_h;
    sequencer       	sequencer_h;
    driver          	driver_h;

    subscriber      	subscriber_h;
  
    uvm_analysis_port #(seq_item) agent_ap;


////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name, uvm_component parent);

    // Phases
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);

endclass : agent


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function agent::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

////////////////////////////////////////////////
// Build phase
////////////////////////////////////////////////
function void agent::build_phase(uvm_phase phase);
    super.build_phase(phase);

    this.agent_ap = new(.name("agent_ap"),.parent(this));
  
    config_h = agent_config::type_id::create(.name("config_h"));

    if (!uvm_config_db #(virtual apb_rsa_if)::get(this, "", "apb_rsa_if", config_h.vif))
        `uvm_fatal("NOVIF", "virtual interface apb_rsa_if nao encontrada no config_db")
  
    // Monitor creation
    monitor_h = monitor::type_id::create(.name("monitor_h"), .parent(this));
    
    // Sequencer
    sequencer_h = sequencer::type_id::create(.name("sequencer_h"), .parent(this));

    // Driver
    driver_h = driver::type_id::create(.name("driver_h"), .parent(this));

    // Subscriber creation
    subscriber_h = subscriber::type_id::create(.name("subscriber_h"), .parent(this));
    
endfunction : build_phase


function void agent::connect_phase(uvm_phase phase);
  
    agent_ap = monitor_h.monitor_ap;
  
    monitor_h.vif = config_h.vif;
    monitor_h.monitor_ap.connect(subscriber_h.analysis_export);
  
    driver_h.vif  = config_h.vif;
    driver_h.seq_item_port.connect(sequencer_h.seq_item_export);

endfunction

