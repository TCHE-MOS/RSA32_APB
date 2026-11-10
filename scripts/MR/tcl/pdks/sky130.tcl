set pdk_root [pdk_env SKY130_ROOT [file join $lambda_root sky130]]
set std_cell [file join $pdk_root libs sky130hd]
set lib_files [list [file join $std_cell nldm sky130_fd_sc_hd__tt_025C_1v80.lib.gz]]
set tech_lef [file join $pdk_root base apr sky130_fd_sc.tlef]
set cell_lef [file join $std_cell lef sky130_fd_sc_hd_merged.lef]
set process_node 130
set core_site unithd
set pin_layer met3
set ring_horizontal_layer met5
set ring_vertical_layer met4
set ring_width 2.0
set ring_spacing 2.0
set stripe_width 2.0
set power_net VPWR
set ground_net VGND
set power_pins {VPWR VPB}
set ground_pins {VGND VNB}
set cts_buffers {sky130_fd_sc_hd__clkbuf_2 sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8}
set cts_inverters {sky130_fd_sc_hd__clkinv_2 sky130_fd_sc_hd__clkinv_4 sky130_fd_sc_hd__clkinv_8}
