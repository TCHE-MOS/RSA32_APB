proc pdk_env {name fallback} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $fallback
}

set pdk [pdk_env PDK gpdk45]
if {$pdk ni {sky130 gpdk45 free45 ics55 tsmc28}} {
    error "PDK invalido: $pdk"
}
if {[info exists selected_pdk] && $selected_pdk ne $pdk} {
    error "Tcl $selected_pdk incompativel com PDK=$pdk"
}
set pdk_base [pdk_env PDK_BASE /home/aluno/eda-pdks-docker/home/.sc/cache/dataroot]
set lambda_root [pdk_env LAMBDAPDK_ROOT [file join $pdk_base lambdapdk-v0.2.22-967925fc5309e6d4 lambdapdk]]
set ring_width 1.0
set ring_spacing 1.5
set stripe_width 0.8
set pdk_has_lef 1
source [file join [file dirname [info script]] pdks ${pdk}.tcl]
set pdk_inputs $lib_files
# LEC consumes Liberty only; physical flows keep LEF validation enabled.
if {$pdk_has_lef && (![info exists pdk_require_lef] || $pdk_require_lef)} {
    set pdk_inputs [concat $pdk_inputs [list $tech_lef $cell_lef]]
}
foreach input $pdk_inputs {
    if {![file isfile $input] || ![file readable $input]} {
        error "Arquivo do PDK $pdk ausente ou ilegivel: $input"
    }
}
