# ============================================================
# Conformal 23.20 - RTL lint
# Top: amba_3_apb_rsa_apb_top
# ============================================================

set_dofile_abort exit
set_log_file -replace $::env(LINT_LOG)

source [file join [file dirname [info script]] report_common.tcl]
flow_reports::init $::env(REPORT_DIR) rtl

set project_root $::env(PROJECT_ROOT)
set source_dir [file join $project_root src MG amba_3_apb]
set rtl_files [list \
    [file join $project_root src MG rsa32 v2 rsa32_core_kogge_stone_adder.sv] \
    [file join $project_root src MG rsa32 v2 rsa32_core_mult.sv] \
    [file join $project_root src MG rsa32 v2 rsa32_core_mod.sv] \
    [file join $project_root src MG rsa32 v2 rsa32_core_ctrl.sv] \
    [file join $project_root src MG rsa32 v2 rsa32_core_top.sv] \
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

read_design {*}$rtl_files -systemverilog -golden -noelaborate
elaborate_design -golden -root amba_3_apb_rsa_apb_top

report_design_data -golden -summary > [flow_reports::path design_data]
report_black_box -golden -detail > [flow_reports::path black_box]
report_rule_check -all -verbose -design -golden > [flow_reports::path rule_check]

exit
