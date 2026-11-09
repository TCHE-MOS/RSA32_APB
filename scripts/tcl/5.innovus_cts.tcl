source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    set report_dir [innovus_report_stage cts]
    file mkdir $report_dir
    innovus_read_stage place

    set_db cts_buffer_cells $cts_buffers
    set_db cts_inverter_cells $cts_inverters
    ccopt_design
    time_design -post_cts -report_dir [flow_reports::directory post_cts]
    write_db [file join $db_dir cts_${artifact_name}]
    exit
}
