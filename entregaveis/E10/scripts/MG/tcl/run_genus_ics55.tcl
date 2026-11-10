set selected_pdk ics55
if {[catch {source [file join [file dirname [info script]] run_genus.tcl]} message]} {
    puts stderr "Erro no Genus (ics55): $message"
    exit 1
}
