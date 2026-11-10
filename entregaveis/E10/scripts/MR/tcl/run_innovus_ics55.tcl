set selected_pdk ics55
if {[catch {source $::env(INNOVUS_SCRIPT)} message]} {
    puts stderr "Erro no Innovus (ics55): $message"
    exit 1
}
