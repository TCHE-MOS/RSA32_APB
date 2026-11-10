source [file join [file dirname [info script]] pdk_common.tcl]
if {![file isfile $::env(SDC_FILE)] || ![file readable $::env(SDC_FILE)]} {
    error "SDC ausente ou ilegivel: $::env(SDC_FILE)"
}

create_library_set \
    -name lib_typical \
    -timing $lib_files

create_rc_corner \
    -name rc_typical \
    -temperature 25 \
    -pre_route_res 1.0 \
    -pre_route_cap 1.0 \
    -post_route_res {1.0 1.0 1.0} \
    -post_route_cap {1.0 1.0 1.0}

create_timing_condition \
    -name tc_typical \
    -library_sets [list lib_typical]

create_delay_corner \
    -name dc_typical \
    -timing_condition tc_typical \
    -rc_corner rc_typical

create_constraint_mode \
    -name mode_functional \
    -sdc_files [list $::env(SDC_FILE)]

create_analysis_view \
    -name view_typical \
    -constraint_mode mode_functional \
    -delay_corner dc_typical

set_analysis_view \
    -setup view_typical \
    -hold view_typical
