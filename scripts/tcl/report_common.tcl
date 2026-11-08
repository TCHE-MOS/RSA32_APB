# Shared naming for explicit reports and tool-generated report directories.
namespace eval flow_reports {
    variable root
    variable suffix

    proc init {directory tag} {
        variable root
        variable suffix
        if {![regexp {^[a-z0-9_]+$} $tag]} {
            error "Sufixo de relatorio invalido: $tag"
        }
        set root [file normalize $directory]
        set suffix $tag
        file mkdir $root
        return $root
    }

    proc path {name {extension rpt}} {
        variable root
        variable suffix
        return [file join $root ${name}_${suffix}.${extension}]
    }

    proc directory {name} {
        variable root
        variable suffix
        set result [file join $root ${name}_${suffix}]
        file mkdir $result
        return $result
    }
}
