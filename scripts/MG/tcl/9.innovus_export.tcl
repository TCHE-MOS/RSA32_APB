source [file join [file dirname [info script]] innovus_common.tcl]

innovus_stage {
    # Experimental Export:
    set output_dir [file join $db_dir export]

    file mkdir $output_dir

    # Restore Post-route Database:
    innovus_read_stage postroute

    # DEF:
    write_def [file join $output_dir ${artifact_name}.def]

    # Verilog Netlist:
    write_netlist [file join $output_dir ${artifact_name}.v]

    # SDF:
    write_sdf [file join $output_dir ${artifact_name}.sdf]

    # Physical implementation constraints, including the synthesized clock budget.
    write_sdc [file join $output_dir ${artifact_name}.sdc]

    # Experimental GDSII:
    # Standard-cell layouts and validated GDS layer map are unavailable.
    write_stream [file join $output_dir ${project_name}_experimental_${pdk}.gds]

    exit
}
