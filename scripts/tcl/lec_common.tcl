
# Log:
set_log_file -replace $::env(LEC_LOG)

# Technology and report naming follow the selected synthesis PDK.
set pdk_require_lef 0
source [file join [file dirname [info script]] pdk_common.tcl]
unset pdk_require_lef
source [file join [file dirname [info script]] report_common.tcl]
flow_reports::init $::env(REPORT_DIR) $pdk
read_library -liberty -replace -both {*}$lib_files

# RTL Files:
set project_root $::env(PROJECT_ROOT)
set source_dir [file join $project_root src amba_3_apb]

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

# Golden Design:
read_design -systemverilog -golden \
    -root amba_3_apb_rsa_apb_top {*}$rtl_files

# Revised Netlist:
set netlist_dir [file join $project_root ps_files rsa_apb_top_${pdk} netlist]
if {[info exists ::env(SYNTH_RUN)] && $::env(SYNTH_RUN) ne ""} {
    set synth_run $::env(SYNTH_RUN)
    if {![regexp [format {^amba_3_apb_rsa_apb_top_[0-9_-]+_%s$} $pdk] $synth_run]} {
        error "SYNTH_RUN invalido para $pdk: $synth_run"
    }
    set netlist [file join $netlist_dir synth_${synth_run}.v]
} else {
    set netlists [glob -nocomplain -directory $netlist_dir synth_amba_3_apb_rsa_apb_top_*_${pdk}.v]
    if {[llength $netlists] == 0} {
        error "Nenhuma netlist de sintese encontrada para $pdk em $netlist_dir"
    }
    set netlist_times {}
    foreach f $netlists {
        lappend netlist_times [list [file mtime $f] $f]
    }
    set netlist [lindex [lindex [lsort -integer -decreasing -index 0 $netlist_times] 0] 1]
    set synth_run [string range [file rootname [file tail $netlist]] 6 end]
}
if {![file isfile $netlist] || ![file readable $netlist] || [file size $netlist] == 0} {
    error "Netlist ausente, vazia ou ilegivel: $netlist"
}
set provenance [open [flow_reports::path synthesis_inputs txt] w]
puts $provenance "Synthesis: $synth_run"
puts $provenance "Netlist: $netlist"
puts $provenance "Liberty: $lib_files"
close $provenance

read_design -verilog -revised \
    -root amba_3_apb_rsa_apb_top $netlist

# Design Reports:
report_design_data > [flow_reports::path design_data]
report_black_box -detail > [flow_reports::path black_box]

# Sequential Constant Modeling:
set_flatten_model -seq_constant

# Logic Equivalence Checking:
set_system_mode lec

# Remodel Sequential Constants:
remodel -seq_constant -seq_constant_feedback -repeat

# Remap Key Points:
map_key_points

# Compare:
add_compared_points -all
compare

# LEC Reports:
report_compare_data -class nonequivalent > [flow_reports::path lec_nonequivalent]
report_unmapped_points > [flow_reports::path lec_unmapped]
report_verification > [flow_reports::path lec_verification]

# Diagnosis Summary:
diagnose -summary > [flow_reports::path lec_diagnosis_summary]

# Diagnosis Groups:
diagnose -noneq -group > [flow_reports::path lec_diagnosis_groups]

# Diagnose PSLVERR:
if {[catch {
    diagnose /pslverr_o -golden > [flow_reports::path lec_diagnose_pslverr]
    report_test_vector /pslverr_o -golden > [flow_reports::path lec_test_vector_pslverr]
} result]} {
    puts "Aviso: Diagnostico PSLVERR nao disponivel: $result"
}

# Diagnose PRDATA[0]:
if {[catch {
    diagnose {/prdata_o[0]} -golden > [flow_reports::path lec_diagnose_prdata]
    report_test_vector {/prdata_o[0]} -golden > [flow_reports::path lec_test_vector_prdata]
} result]} {
    puts "Aviso: Diagnostico PRDATA nao disponivel: $result"
}
