source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    set report_dir [innovus_report_stage init]
    file mkdir $db_dir $report_dir

    set_db design_process_node $process_node
    set_db add_route_vias_auto true
    set_db init_power_nets [list $power_net]
    set_db init_ground_nets [list $ground_net]

    # Consume the mapped netlist and SDC from the same Genus execution.
    read_mmmc $::env(MMMC_FILE)
    read_physical -lef [list $tech_lef $cell_lef]
    read_netlist -top $project_name $::env(NETLIST_FILE)
    init_design

    check_timing -verbose > [flow_reports::path timing_constraints]
    write_db [file join $db_dir init_${artifact_name}]

    # Record provenance and select this run only after initialization succeeds.
    set provenance [open [file join $db_dir synthesis_inputs_${pdk}.txt] w]
    puts $provenance "RSA implementation: src/rsa32/v2"
    puts $provenance "PDK: $pdk"
    puts $provenance "Liberty: $lib_files"
    puts $provenance "LEF: [list $tech_lef $cell_lef]"
    puts $provenance "Synthesis: $::env(SYNTH_RUN)"
    puts $provenance "Netlist: $::env(NETLIST_FILE)"
    puts $provenance "SDC: $::env(SDC_FILE)"
    close $provenance

    set marker [file join $::env(INNOVUS_BASE_DIR) active_run]
    set temporary "${marker}.[pid].tmp"
    set handle [open $temporary w]
    puts $handle $::env(SYNTH_RUN)
    close $handle
    file rename -force $temporary $marker
    exit
}
