# Conformal LEC (Tcl mode): RTL Verilog x RTL SystemVerilog
# Invocado por scripts/RSA4/bash/run_rsa_lec.sh: lec -64 -nogui -tclmode -dofile rsa_lec.tcl
# Variaveis obrigatorias: LEC_GOLDEN, LEC_REVISED, LEC_TOP, LEC_OUTPUT_DIR

foreach name {LEC_GOLDEN LEC_REVISED LEC_TOP LEC_OUTPUT_DIR} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        puts stderr "ERRO: variavel de ambiente $name ausente."
        exit 2
    }
}

set golden  $::env(LEC_GOLDEN)
set revised $::env(LEC_REVISED)
set top     $::env(LEC_TOP)
set outdir  $::env(LEC_OUTPUT_DIR)
set compared 0

puts "=== LEC: $top | Golden (Verilog) vs Revised (SystemVerilog) ==="

set cmd_error [catch {
    # Arquivos RTL independentes com o mesmo nome de modulo raiz.
    # Nenhuma biblioteca de celulas e necessaria para RTL-to-RTL puro.
    read_design $golden  -verilog2k    -golden  -root $top
    read_design $revised -systemverilog -revised -root $top

    report_design_data -both
    report_black_box -detail

    set_system_mode lec
    report_mapped_points -summary
    report_unmapped_points -summary

    # Compara todos os pontos mapeados, incluindo POs e registradores.
    add_compared_points -all
    set_compare_effort high
    compare
    set compared 1

    # A tabela de comparacao e a principal evidência do resultado.
    report_compare_data -summary
    report_compare_data -class nonequivalent
    report_compare_data -class abort
    report_statistics
    report_verification
} cmd_message]

if {$cmd_error} {
    puts stderr "ERRO durante execucao do LEC: $cmd_message"
}

# Bits do get_exit_code (Conformal):
# 1=erro interno, 2=nenhum ponto equivalente provado, 4=erro comando,
# 8=pontos nao mapeados, 16=nao equivalentes,
# 32=abort/uncompared em qualquer compare, 64=abort/uncompared no ultimo.
set status [get_exit_code]
if {$cmd_error && $status == 0} {
    set status 4
}
if {!$compared && $status == 0} {
    set status 2
}
set result [expr {$status == 0 && $compared ? "PASS" : "FAIL"}]

set fh [open [file join $outdir summary.txt] w]
puts $fh "DESIGN=$top"
puts $fh "GOLDEN=$golden"
puts $fh "REVISED=$revised"
puts $fh "COMPARE_EXECUTED=$compared"
puts $fh "RESULT=$result"
puts $fh "CONFORMAL_EXIT_CODE=$status"
puts $fh "CONFORMAL_EXIT_CODE_HEX=[format 0x%X $status]"
if {$cmd_error} {
    puts $fh "SCRIPT_ERROR=$cmd_message"
}
close $fh

puts "=== RESULTADO LEC: $result (codigo $status) ==="
exit $status
