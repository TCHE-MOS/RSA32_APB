
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
set source_dir [file join $project_root src MR RSA_APB]

set rtl_files [list \
    [file join $source_dir rsa_core_32bits.sv] \
    [file join $source_dir rsa_apb_top.sv] \
]

# Golden Design:
read_design -systemverilog -golden \
    -root amba_3_apb_rsa_apb_top {*}$rtl_files

# Revised Netlist:
set netlist_dir [file join $project_root ps_files MR rsa_apb_top_${pdk} netlist]
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
    # O RUN contem a data/hora da sintese. mtime muda ao copiar/restaurar
    # o projeto e pode empatar entre varias netlists.
    set netlist [lindex [lsort -dictionary -decreasing $netlists] 0]
    set synth_run [string range [file rootname [file tail $netlist]] 6 end]
}
if {![file isfile $netlist] || ![file readable $netlist] || [file size $netlist] == 0} {
    error "Netlist ausente, vazia ou ilegivel: $netlist"
}
puts "LEC | PDK: $pdk | Sintese: $synth_run"
puts "Golden: RTL em $source_dir (implementacao MR)"
puts "Revised: $netlist"
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

# Veredito, lido logo apos o compare (antes de comandos de diagnostico, que
# falham sem pontos nao equivalentes e alterariam o codigo de saida).
# Bits do get_exit_code (Conformal):
#   1=erro interno, 2=nenhum ponto equivalente provado, 4=erro de comando,
#   8=pontos nao mapeados, 16=nao equivalentes,
#   32=abort/nao comparados em algum compare, 64=abort/nao comparados no ultimo.
# Pontos nao mapeados (8) nao reprovam: os relatados sao flops "unreachable"
# removidos pela sintese; ficam registrados como aviso.
set lec_exit_code [get_exit_code]
set lec_fail_mask [expr {1 | 2 | 4 | 16 | 32 | 64}]
set lec_status [expr {$lec_exit_code & $lec_fail_mask}]
set lec_result [expr {$lec_status == 0 ? "PASS" : "FAIL"}]

# Diagnosis (somente com pontos nao equivalentes):
if {$lec_exit_code & 16} {
    diagnose -summary > [flow_reports::path lec_diagnosis_summary]
    diagnose -noneq -group > [flow_reports::path lec_diagnosis_groups]
    if {[catch {
        diagnose /pslverr_o -golden > [flow_reports::path lec_diagnose_pslverr]
        report_test_vector /pslverr_o -golden > [flow_reports::path lec_test_vector_pslverr]
    } result]} {
        puts "Aviso: Diagnostico PSLVERR nao disponivel: $result"
    }
    if {[catch {
        diagnose {/prdata_o[0]} -golden > [flow_reports::path lec_diagnose_prdata]
        report_test_vector {/prdata_o[0]} -golden > [flow_reports::path lec_test_vector_prdata]
    } result]} {
        puts "Aviso: Diagnostico PRDATA nao disponivel: $result"
    }
}

# Resumo:
set summary_file [flow_reports::path lec_summary txt]
set fh [open $summary_file w]
puts $fh "DESIGN=amba_3_apb_rsa_apb_top"
puts $fh "PDK=$pdk"
puts $fh "SYNTH_RUN=$synth_run"
puts $fh "GOLDEN=$source_dir"
puts $fh "REVISED=$netlist"
puts $fh "RESULT=$lec_result"
puts $fh "UNMAPPED_EXIT_BIT=[expr {($lec_exit_code & 8) ? 1 : 0}]"
puts $fh "UNMAPPED_REPORT=[flow_reports::path lec_unmapped] (inclui flops unreachable removidos pela sintese, que nao ativam o bit)"
puts $fh "CONFORMAL_EXIT_CODE=$lec_exit_code"
puts $fh "CONFORMAL_EXIT_CODE_HEX=[format 0x%X $lec_exit_code]"
close $fh

report_verification
if {$lec_exit_code & 8} {
    puts "Aviso: ha pontos nao mapeados; consulte [flow_reports::path lec_unmapped]"
}
puts "Resumo: $summary_file"
puts "=== RESULTADO LEC: $lec_result (codigo $lec_exit_code) | PDK: $pdk | Sintese: $synth_run ==="
