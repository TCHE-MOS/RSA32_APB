set selected_pdk free45
if {[catch {source $::env(INNOVUS_SCRIPT)} message]} {
    puts stderr "Erro no Innovus (free45): $message"
    exit 1
}
