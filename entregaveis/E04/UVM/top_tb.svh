////////////////////////////////////////////////
// Curso de Verificação de Circuitos Digitais
// Outubro 2026
// Description: UVM Testbench
// DUT: RSA_APB
////////////////////////////////////////////////

`timescale 1ns/1ps

module top_tb;

////////////////////////////////////////////////
// UVM package
////////////////////////////////////////////////
import uvm_pkg::*;

////////////////////////////////////////////////
// Testbench packages
////////////////////////////////////////////////
import top_tb_pkg::*;
import top_test_pkg::*;

////////////////////////////////////////////////
// Test Harrness instantiation
////////////////////////////////////////////////
  top_th  th();

////////////////////////////////////////////////
// UVM configuration and Run
////////////////////////////////////////////////
initial begin

    uvm_config_db #(virtual apb_rsa_if)::set(
        .cntxt(uvm_root::get()),
        .inst_name("*"),
        .field_name("apb_rsa_if"),
        .value(th.apb_rsa_if)
    );

    run_test();

end

final begin
    $display("[TIMING] Tempo simulado global: %0.3f ns", $realtime);
    env_pkg::scoreboard::print_assertion_table(
        th.apb_rsa_if.sva_corners_cases_planned, th.apb_rsa_if.sva_corners_cases_completed,
        th.apb_rsa_if.sva_corners_exp_active, th.apb_rsa_if.sva_corners_case_id);
end


endmodule
