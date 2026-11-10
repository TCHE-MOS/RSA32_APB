set selected_pdk gpdk45
if {[catch {source $::env(INNOVUS_SCRIPT)} message]} {
    puts stderr "Erro no Innovus (gpdk45): $message"
    exit 1
}
