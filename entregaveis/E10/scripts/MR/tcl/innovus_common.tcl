# Context shared by every stage of the RSA MR flow.
foreach required {PROJECT_ROOT SYNTH_RUN NETLIST_FILE SDC_FILE INNOVUS_BASE_DIR INNOVUS_DB_DIR INNOVUS_REPORT_DIR} {
    if {![info exists ::env($required)] || $::env($required) eq ""} {
        puts stderr "Erro: variavel $required ausente. Execute o script Bash da etapa."
        exit 1
    }
}

set project_name "amba_3_apb_rsa_apb_top"
set project_root $::env(PROJECT_ROOT)
set db_dir $::env(INNOVUS_DB_DIR)
set report_root $::env(INNOVUS_REPORT_DIR)

source [file join [file dirname [info script]] pdk_common.tcl]
if {!$pdk_has_lef} {
    error "PDK $pdk configurado somente para sintese Genus sem LEF; Innovus exige configuracao fisica."
}
set artifact_name "${project_name}_${pdk}"

proc innovus_stage {body} {
    if {[catch {uplevel 1 $body} result]} {
        puts stderr "Erro no fluxo Innovus: $result"
        exit 1
    }
}

proc innovus_read_stage {stage} {
    global db_dir artifact_name
    set path [file join $db_dir ${stage}_${artifact_name}]
    if {![file exists $path]} {
        error "Banco da etapa $stage ausente para esta sintese: $path. Execute a etapa anterior."
    }
    read_db $path
}

source [file join [file dirname [info script]] report_common.tcl]

proc innovus_report_stage {stage} {
    global report_root pdk
    # A repeated stage keeps earlier reports from the same synthesis.
    set stage_root [file join $report_root $stage]
    set timestamp [clock format [clock seconds] -format %Y-%m-%d_%H-%M-%S]
    set attempt "${timestamp}_[pid]_[clock clicks]_${pdk}"
    set directory [file join $stage_root $attempt]
    return [flow_reports::init $directory $pdk]
}
