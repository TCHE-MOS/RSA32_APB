set selected_pdk free45
if {[catch {source [file join [file dirname [info script]] run_genus.tcl]} message]} {
    puts stderr "Erro no Genus (free45): $message"
    exit 1
}
