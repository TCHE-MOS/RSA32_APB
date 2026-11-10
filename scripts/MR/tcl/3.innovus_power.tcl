source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    set report_dir [innovus_report_stage power]
    file mkdir $report_dir
    innovus_read_stage floorplan

    foreach pin_name $power_pins {
        connect_global_net $power_net -type pg_pin -pin_base_name $pin_name -all
    }
    foreach pin_name $ground_pins {
        connect_global_net $ground_net -type pg_pin -pin_base_name $pin_name -all
    }
    set supply_nets [list $power_net $ground_net]
    add_rings -nets $supply_nets -type core_rings -follow core \
        -layer [list top $ring_horizontal_layer bottom $ring_horizontal_layer left $ring_vertical_layer right $ring_vertical_layer] \
        -width $ring_width -spacing $ring_spacing -offset 1.0
    add_stripes -nets $supply_nets -layer $ring_vertical_layer -direction vertical \
        -width $stripe_width -spacing $ring_spacing -set_to_set_distance 25 \
        -start_from left -start_offset 15
    route_special -nets $supply_nets \
        -connect {core_pin floating_stripe} \
        -core_pin_target {ring stripe} \
        -floating_stripe_target {ring stripe followpin}
    check_connectivity -nets $supply_nets -type special \
        > [flow_reports::path power_connectivity]
    write_db [file join $db_dir power_${artifact_name}]
    exit
}
