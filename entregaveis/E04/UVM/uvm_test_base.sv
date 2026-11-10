////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class test_base extends uvm_test;

    `uvm_component_utils(test_base)

////////////////////////////////////////////////
// Test components instantiation
////////////////////////////////////////////////
    // Environment
    env                      env_h;
    env_config               env_config_h;

    // Virtual sequence
    vseq    vseq_h;

    // Agent configuration
    //agent_config agent_config_h;

    // Misc
    uvm_factory factory;
    uvm_coreservice_t cs = uvm_coreservice_t::get();

////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
    extern function new(string name = "", uvm_component parent = null);

    // Phases
    extern function void build_phase(uvm_phase phase);
    extern function void start_of_simulation_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);

endclass : test_base


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function test_base::new(string name="", uvm_component parent = null);
    super.new(name, parent);
endfunction

////////////////////////////////////////////////
// Build phase
////////////////////////////////////////////////
function void test_base::build_phase(uvm_phase phase);
    super.build_phase(phase);
    scoreboard::init_assertion_log();

    // Env creation
    env_h = env::type_id::create(.name("env_h"), .parent(this));

    // Env config creation
    env_config_h = env_config::type_id::create(.name("env_config_h"));

    // Config
    uvm_config_db #(env_config)::set(
        .cntxt          (this),
        .inst_name      ("*"),
        .field_name     ("env_config"),
        .value          (env_config_h)
    );

endfunction : build_phase


function void test_base::start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);

    if(uvm_report_enabled(UVM_HIGH)) begin
        this.print();
        factory = cs.get_factory();
        factory.print();
    end

endfunction


task test_base::run_phase(uvm_phase phase);
    void'(super.randomize());

    vseq_h = vseq::type_id::create(.name("vseq_h"));

    phase.raise_objection(this);

    vseq_h.start(env_h.vsequencer_h);
    scoreboard::execution_complete = 1'b1;

    phase.drop_objection(this);

endtask

