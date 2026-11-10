set selected_pdk sky130
if {[catch {source [file join [file dirname [info script]] run_genus.tcl]} message]} {
    puts stderr "Erro no Genus (sky130): $message"
    exit 1
}
