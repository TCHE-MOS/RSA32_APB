# ============================================================
# Conformal 23.20 - RTL lint
# Top: amba_3_apb_rsa_apb_top
# ============================================================

set_dofile_abort exit
set_log_file -replace $::env(LINT_LOG)

source [file join [file dirname [info script]] report_common.tcl]
flow_reports::init $::env(REPORT_DIR) rtl

set project_root $::env(PROJECT_ROOT)
set source_dir [file join $project_root src MR RSA_APB]
set rtl_files [list \
    [file join $source_dir rsa_core_32bits.sv] \
    [file join $source_dir rsa_apb_top.sv] \
]

read_design {*}$rtl_files -systemverilog -golden -noelaborate
elaborate_design -golden -root amba_3_apb_rsa_apb_top

report_design_data -golden -summary > [flow_reports::path design_data]
report_black_box -golden -detail > [flow_reports::path black_box]
report_rule_check -all -verbose -design -golden > [flow_reports::path rule_check]

exit
