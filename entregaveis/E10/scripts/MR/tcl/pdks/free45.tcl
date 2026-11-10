set pdk_root [pdk_env FREEPDK45_ROOT [file join $lambda_root freepdk45]]
set std_cell [file join $pdk_root libs nangate45]
set lib_files [list [file join $std_cell nldm NangateOpenCellLibrary_typical.lib]]
set tech_lef [file join $pdk_root base apr freepdk45.tech.lef]
set cell_lef [file join $std_cell lef NangateOpenCellLibrary.macro.mod.lef]
set process_node 45
set core_site FreePDK45_38x28_10R_NP_162NW_34O
set pin_layer metal3
set ring_horizontal_layer metal5
set ring_vertical_layer metal4
set power_net VDD
set ground_net VSS
set power_pins {VDD}
set ground_pins {VSS}
set cts_buffers {CLKBUF_X1 CLKBUF_X2 CLKBUF_X3}
set cts_inverters {INV_X2 INV_X4 INV_X8}
