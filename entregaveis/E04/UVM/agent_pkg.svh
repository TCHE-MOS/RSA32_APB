////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


package agent_pkg;

    import uvm_pkg::*;

	import sequence_pkg::*;

    // Components
    `include "uvm_monitor.sv"
    `include "uvm_driver.sv"
    `include "uvm_sequencer.sv"
    `include "uvm_subscriber.sv"
    `include "agent_config.svh"
    `include "uvm_agent.sv"


endpackage : agent_pkg