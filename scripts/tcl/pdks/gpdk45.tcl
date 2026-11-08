set pdk_root [pdk_env GPDK45_ROOT [pdk_env INNOVUS_TECH_DIR /home/cadence/DDI221/JLS221/etc/rtls/tutorial/libraries]]
set lib_files [list [file join $pdk_root LIB typical.lib]]
set tech_lef [file join $pdk_root LEF gsclib045_tech.lef]
set cell_lef [file join $pdk_root LEF gsclib045_macro.lef]
set process_node 45
set core_site CoreSite
set pin_layer M3
set ring_horizontal_layer M5
set ring_vertical_layer M4
set power_net VDD
set ground_net VSS
set power_pins {VDD}
set ground_pins {VSS}
set cts_buffers {CLKBUFX2 CLKBUFX4 CLKBUFX8}
set cts_inverters {CLKINVX2 CLKINVX4 CLKINVX8}
