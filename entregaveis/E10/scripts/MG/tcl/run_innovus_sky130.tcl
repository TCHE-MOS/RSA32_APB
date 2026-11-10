set selected_pdk sky130
if {[catch {source $::env(INNOVUS_SCRIPT)} message]} {
    puts stderr "Erro no Innovus (sky130): $message"
    exit 1
}
