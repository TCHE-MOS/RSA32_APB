set selected_pdk gpdk45
if {[catch {source [file join [file dirname [info script]] run_genus.tcl]} message]} {
    puts stderr "Erro no Genus (gpdk45): $message"
    exit 1
}
