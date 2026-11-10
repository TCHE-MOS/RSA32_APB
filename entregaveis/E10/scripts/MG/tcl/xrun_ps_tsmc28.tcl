# Xcelium gate-level run. SDF is annotated at elaboration by -sdf_cmd_file.
# Xrun -input evaluates commands interactively: info script may be empty.
source [file join $::env(PROJECT_ROOT) scripts MG tcl report_common.tcl]
flow_reports::init $::env(REPORT_DIR) tsmc28

set provenance [open [flow_reports::path simulation_inputs txt] w]
foreach name {SYNTH_RUN NETLIST_FILE SDF_FILE TSMC28_VERILOG_FILE CLOCK_PERIOD_NS SDF_LOG} {
    puts $provenance "$name: $::env($name)"
}
puts $provenance "DUT scope: testbench.dut"
puts $provenance "Model defines: POST_SYNTHESIS, NTC, RECREM"
puts $provenance "SDF selection: MAXIMUM (corner characterized by the synthesis Liberty)"
close $provenance

database -open waves -into $::env(WAVE_FILE) -event -default
probe -create testbench -all -depth all -database waves
run
exit
