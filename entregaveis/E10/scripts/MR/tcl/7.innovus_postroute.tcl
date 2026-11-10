source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    # Post-route timing optimization:
    set report_dir [innovus_report_stage postroute]

    file mkdir $report_dir

    # Restore Routed Database:
    innovus_read_stage route

    # Disable Signal Integrity Analysis:
    set_db delaycal_enable_si false

    # Post-route Optimization:
    opt_design -post_route -setup
    opt_design -post_route -hold

    # Timing Reports:
    time_design -post_route -report_dir [flow_reports::directory setup]
    time_design -post_route -hold -report_dir [flow_reports::directory hold]

    # Save Post-route Database:
    write_db [file join $db_dir postroute_${artifact_name}]

    exit
}
