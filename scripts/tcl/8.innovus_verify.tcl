source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    # Physical checks; not a foundry sign-off.
    set report_dir [innovus_report_stage verify]
    file mkdir $report_dir
    innovus_read_stage postroute

    check_design -type all -out_file [flow_reports::path design]
    check_timing -verbose > [flow_reports::path timing]
    check_drc > [flow_reports::path drc]
    check_connectivity -type all > [flow_reports::path connectivity]
    time_design -post_route -report_dir [flow_reports::directory setup]
    time_design -post_route -hold -report_dir [flow_reports::directory hold]
    exit
}
