set pdk_root [pdk_env ICS55_ROOT [file join $pdk_base icsprout55-v1.10.102-a7b1e2edbb12d056]]
set std_cell [file join $pdk_root IP STD_cell ics55_LLSC_H7C_V1p10C100 ics55_LLSC_H7CR]
set lib_dir [pdk_env ICS55_LIB_ROOT [file join $pdk_base icsprout55-liberty-r-v1.10.102-c9ed7480e1a5b5d5 liberty]]
set lib_files [list [file join $lib_dir ics55_LLSC_H7CR_typ_tt_1p2_25_nldm.lib]]
set tech_lef [file join $pdk_root prtech techLEF N551P6M.lef]
set cell_lef [file join $std_cell lef ics55_LLSC_H7CR_ecos.lef]
set process_node 55
set core_site core7
set pin_layer MET3
set ring_horizontal_layer MET5
set ring_vertical_layer MET4
set power_net VDD
set ground_net VSS
set power_pins {VDD}
set ground_pins {VSS}
set cts_buffers {BUFX2H7R BUFX4H7R BUFX8H7R}
set cts_inverters {INVX2H7R INVX4H7R INVX8H7R}
