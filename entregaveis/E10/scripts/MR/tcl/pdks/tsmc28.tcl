# TSMC28 HPC+: sintese logica apenas, sem arquivos LEF.
# Biblioteca instalada localmente: BWP30P140, TT 1.0 V / 25 C.
set pdk_has_lef 0
set process_node 28
set pdk_root [pdk_env TSMC28_ROOT /tsmc28]
set lib_files [pdk_env TSMC28_LIB_FILES [list \
    [file join $pdk_root tcbn28hpcplusbwp30p140tt1v25c.lib]]]
# O override deve ser uma lista Tcl de arquivos Liberty do corner desejado.
if {[catch {llength $lib_files} lib_count] || $lib_count == 0} {
    error "TSMC28_LIB_FILES deve ser uma lista Tcl nao vazia de arquivos Liberty."
}
