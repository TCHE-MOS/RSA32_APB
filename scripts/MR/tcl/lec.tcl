# -dofile nao define [info script] como o comando Tcl source.
source [file join $::env(PROJECT_ROOT) scripts MR tcl lec_common.tcl]
# Codigo de saida: 0 = PASS; diferente de 0 = FAIL (bits de get_exit_code).
exit $lec_status
