source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    # Placement and pre-CTS timing optimization.
    set report_dir [innovus_report_stage place]
    file mkdir $report_dir
    innovus_read_stage power

    place_opt_design
    time_design -pre_cts -report_dir [flow_reports::directory pre_cts]

    write_db [file join $db_dir place_${artifact_name}]
    exit
}
