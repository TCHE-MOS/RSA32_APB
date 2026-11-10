////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class env extends uvm_env;

    `uvm_component_utils(env)

////////////////////////////////////////////////
// Test components instantiation
////////////////////////////////////////////////
    env_config           	env_config_h;
    vsequencer           	vsequencer_h;
    scoreboard          	scoreboard_h;

    agent               	agent_h;


////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name, uvm_component parent);

    // Phases
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
    extern function void start_of_simulation_phase(uvm_phase phase);

endclass : env


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function env::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

////////////////////////////////////////////////
// Build phase
////////////////////////////////////////////////
function void env::build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(env_config)::get(
        .cntxt          (this),
        .inst_name      (""),
        .field_name     ("env_config"),
        .value          (env_config_h)
    )) begin
        `uvm_error( get_name(), "Could not get the environment configuration handle from config database")
    end

    // Virtual Sequencer creation
    vsequencer_h = vsequencer::type_id::create(.name("vsequencer_h"), .parent(this));

    // Scoreboard creation
    if (env_config_h.has_scoreboard) begin
        scoreboard_h = scoreboard::type_id::create(.name ("scoreboard_h"), .parent(this));
    end
    
    // Agent creation
    agent_h = agent::type_id::create(.name("agent_h"), .parent(this));

    agent_h.config_h = env_config_h.config_h;
    
    
endfunction : build_phase


function void env::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Agent - Scoreboard connection
    if (env_config_h.has_scoreboard) begin
        agent_h.agent_ap.connect(scoreboard_h.analysis_export_apb_rsa_aep);
    end

    // Vsequencer - Agent(suquencer) connection
    vsequencer_h.sequencer_h = agent_h.sequencer_h;

endfunction


function void env::start_of_simulation_phase(uvm_phase phase);
    //report_server server = new;
    
    super.start_of_simulation_phase(phase);

    //report_server::set_server(server);

endfunction