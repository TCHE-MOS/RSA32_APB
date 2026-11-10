set selected_pdk tsmc28
if {[catch {source [file join [file dirname [info script]] run_genus.tcl]} message]} {
    puts stderr "Erro no Genus (tsmc28): $message"
    exit 1
}
