source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    # Project:
    set output_dir $db_dir

    # Automatic Via Generation:
    set_db add_route_vias_auto true

    # Restore CTS Database:
    innovus_read_stage cts

    # Routing:
    route_design

    # Save Routed Database:
    write_db [file join $output_dir route_${artifact_name}]

    exit
}
