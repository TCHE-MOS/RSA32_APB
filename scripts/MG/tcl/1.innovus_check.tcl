source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    # Verify imported design and timing constraints.
    set report_dir [innovus_report_stage check]
    file mkdir $report_dir

    innovus_read_stage init

    check_library > [flow_reports::path library]
    check_netlist > [flow_reports::path netlist]
    check_timing -verbose > [flow_reports::path timing_constraints]
    time_design -pre_place -report_dir [flow_reports::directory pre_place]

    exit
}
