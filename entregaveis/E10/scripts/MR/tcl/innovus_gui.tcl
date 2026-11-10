source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    # The final database is the default; fallback requires explicit auto mode.
    set selected_stage postroute
    if {[info exists ::env(INNOVUS_DB_STAGE)] && $::env(INNOVUS_DB_STAGE) ne ""} {
        set selected_stage $::env(INNOVUS_DB_STAGE)
    }
    if {$selected_stage eq "auto"} {
        set stages {postroute route cts place power floorplan init}
    } else {
        set stages [list $selected_stage]
    }
    set restored false
    foreach stage $stages {
        if {$stage ni {postroute route cts place power floorplan init}} {
            error "Etapa de banco invalida: $stage"
        }
        set db_path [file join $db_dir ${stage}_${artifact_name}]
        if {[file exists $db_path]} {
            puts "Abrindo banco GUI: $db_path"
            innovus_read_stage $stage
            set restored true
            break
        }
    }
    if {!$restored} {
        error "Banco $selected_stage ausente para $::env(SYNTH_RUN). Execute a etapa correspondente ou selecione uma etapa existente com INNOVUS_DB_STAGE."
    }
    gui_show
    gui_fit
}
