////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


package env_pkg;

    import uvm_pkg::*;

    import sequence_pkg::*;
    import agent_pkg::*;

    // Components
    `include "uvm_scoreboard.sv"
    `include "uvm_vsequencer.sv"
    `include "env_config.svh"
    `include "uvm_env.sv"


endpackage : env_pkg