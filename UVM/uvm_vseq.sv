////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////


class vseq extends uvm_sequence;

    `uvm_object_utils(vseq)
    `uvm_declare_p_sequencer(vsequencer)

  	sequencer       	sequencer_h;
  
    env                 env_h;
    virtual apb_rsa_if   vif;
  

////////////////////////////////////////////////
// Methods
////////////////////////////////////////////////
    // New
  extern function new(string name="vseq");

    // Tasks
    extern task body();
      
    extern task pre_start();

endclass : vseq


////////////////////////////////////////////////
// New
////////////////////////////////////////////////
function vseq::new(string name="vseq");
    super.new(name);
endfunction


////////////////////////////////////////////////
// Body
////////////////////////////////////////////////
task vseq::pre_start();
        
  	$cast(env_h, this.get_sequencer().get_parent());
  
    sequencer_h = p_sequencer.sequencer_h;

    if (!uvm_config_db #(virtual apb_rsa_if)::get(p_sequencer, "", "apb_rsa_if", vif))
        `uvm_fatal("NOVIF", "Interface APB nao encontrada para controlar os cenarios SVA")

endtask


////////////////////////////////////////////////
// Body
////////////////////////////////////////////////
task vseq::body();
        
    sequence_rsa_operation  sequence_rsa_operation_h;
    sequence_soft_reset     sequence_soft_reset_h;
    sequence_corners_exp    sequence_corners_exp_h;

    sequence_rsa_operation_h    = sequence_rsa_operation::type_id::create("sequence_rsa_operation_h");
    sequence_soft_reset_h       = sequence_soft_reset   ::type_id::create("sequence_soft_reset_h");

    scoreboard::active_scenario = "rsa_operation";
    `uvm_info("SEQ_BEGIN", $sformatf("[rsa_operation] INICIO | EXP=8 bits | max_status_reads=%0d",
              sequence_rsa_operation_h.max_status_reads), UVM_LOW)
    vif.sva_rsa_operation_active = 1'b1;
    sequence_rsa_operation_h.start(sequencer_h);
    vif.sva_rsa_operation_active = 1'b0;
    scoreboard::report_sequence_result("rsa_operation");

    scoreboard::active_scenario = "soft_reset";
    `uvm_info("SEQ_BEGIN", "[soft_reset] INICIO", UVM_LOW)
    vif.sva_soft_reset_active = 1'b1;
    sequence_soft_reset_h.start(sequencer_h);
    vif.sva_soft_reset_active = 1'b0;
    scoreboard::report_sequence_result("soft_reset");

    sequence_corners_exp_h = sequence_corners_exp::type_id::create("sequence_corners_exp_h");
    void'($value$plusargs("CORNERS_CASES=%d", sequence_corners_exp_h.num_testcases));
    void'($value$plusargs("CORNERS_MAX_READS=%d", sequence_corners_exp_h.max_status_reads));
    void'($value$plusargs("CORNERS_BASE_CYCLES=%d", sequence_corners_exp_h.base_cycles));
    void'($value$plusargs("CORNERS_CYCLES_PER_EXP=%d", sequence_corners_exp_h.cycles_per_exp));
    void'($value$plusargs("CORNERS_POLL_CYCLES=%d", sequence_corners_exp_h.poll_interval_cycles));
    scoreboard::active_scenario = "corners_exp";
    `uvm_info("SEQ_BEGIN", $sformatf("[corners_exp] INICIO | perfil=EXTENSO casos=%0d base_cycles=%0d cycles_per_exp=%0d read_cap=%0d",
              sequence_corners_exp_h.num_testcases, sequence_corners_exp_h.base_cycles,
              sequence_corners_exp_h.cycles_per_exp, sequence_corners_exp_h.max_status_reads), UVM_LOW)
    sequence_corners_exp_h.start(sequencer_h);

endtask
