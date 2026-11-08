if {![info exists ::env(DB_FILE)] || ![file isfile $::env(DB_FILE)]} {
    error "Genus database not found. Run genus_nogui.sh before genus_gui.sh."
}

read_db $::env(DB_FILE)
gui_show
