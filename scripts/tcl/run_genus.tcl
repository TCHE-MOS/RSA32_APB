
set project_name "amba_3_apb_rsa_apb_top"
set project_root $::env(PROJECT_ROOT)
set run_id $::env(RUN)
set output_dir $::env(OUTPUT_DIR)
set report_dir $::env(REPORT_DIR)
set source_dir [file join $project_root src amba_3_apb]
set sdc_file [file join $project_root constraints amba_3_apb_rsa_apb_top.sdc]
set_db / .use_scan_seqs_for_non_dft false
set_db init_hdl_search_path [list \
    [file join $project_root src rsa32 v2] \
    $source_dir]

set rtl_files [list \
    [file join $project_root src rsa32 v2 rsa32_core_kogge_stone_adder.sv] \
    [file join $project_root src rsa32 v2 rsa32_core_mult.sv] \
    [file join $project_root src rsa32 v2 rsa32_core_mod.sv] \
    [file join $project_root src rsa32 v2 rsa32_core_ctrl.sv] \
    [file join $project_root src rsa32 v2 rsa32_core_top.sv] \
    [file join $source_dir amba_3_apb_adrec.sv] \
    [file join $source_dir amba_3_apb_data_o_mux.sv] \
    [file join $source_dir amba_3_apb_data_io_top.sv] \
    [file join $source_dir amba_3_apb_control.sv] \
    [file join $source_dir amba_3_apb_regbank.sv] \
    [file join $source_dir amba_3_apb_reset.sv] \
    [file join $source_dir amba_3_apb_rsa_wrapper_control.sv] \
    [file join $source_dir amba_3_apb_rsa_wrapper_data.sv] \
    [file join $source_dir amba_3_apb_rsa_wrapper_top.sv] \
    [file join $source_dir amba_3_apb_rsa_apb_top.sv] \
]

source [file join [file dirname [info script]] pdk_common.tcl]
source [file join [file dirname [info script]] report_common.tcl]
flow_reports::init $report_dir $pdk
set lib_dirs {}
foreach lib_file $lib_files {
    lappend lib_dirs [file dirname $lib_file]
}
set_db init_lib_search_path [lsort -unique $lib_dirs]
read_libs $lib_files
if {$pdk_has_lef} {
    set_db lef_library [list $tech_lef $cell_lef]
} else {
    puts "PDK $pdk: sintese logica com Liberty, sem LEF."
}

foreach rtl_file $rtl_files {
    read_hdl -language sv $rtl_file
}

elaborate $project_name

set_time_unit -nanoseconds 1.0
read_sdc $sdc_file

check_design -unresolved > [flow_reports::path check_unresolved]
report_clocks > [flow_reports::path clocks]

set_db syn_generic_effort high
syn_generic

set_db syn_map_effort high
set_db syn_opt_effort high
syn_map
syn_opt

write_db $project_name -to_file [file join $output_dir db "synth_${run_id}.db"]
write_hdl > [file join $output_dir netlist "synth_${run_id}.v"]
write_sdc > [file join $output_dir sdc "synth_${run_id}.sdc"]
write_sdf > [file join $output_dir sdf "synth_${run_id}.sdf"]


report_timing -max_paths 100 > [flow_reports::path timing_max]
report_area > [flow_reports::path area]
report_power > [flow_reports::path power]
report_gates > [flow_reports::path gates]
report_qor > [flow_reports::path qor]
check_design > [flow_reports::path check_design]

exit
