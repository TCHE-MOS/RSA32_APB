source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    innovus_read_stage init
    set_db floorplan_default_tech_site $core_site
    create_floorplan -core_density_size {1.0 0.60 10 10 10 10}
    edit_pin -side Left -layer $pin_layer -spread_type center -spacing 0.6 \
        -pin [get_db [get_db ports -if {.direction == in}] .name]
    edit_pin -side Right -layer $pin_layer -spread_type center -spacing 0.6 \
        -pin [get_db [get_db ports -if {.direction == out}] .name]
    write_db [file join $db_dir floorplan_${artifact_name}]
    exit
}
