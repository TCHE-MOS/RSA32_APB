################################################################################
# Genus synthesis script: RSA_APB (amba_3_apb_rsa_apb_top + rsa_core)
#
# Run from the folder that holds this genus/ directory:
#     genus -f genus/run_genus.tcl | tee genus/genus.log
#
# Edit the three variables in the "USER SETTINGS" block.
################################################################################

############################# USER SETTINGS ####################################
# Typical-corner liberty file(s) of your technology
set LIB_FILES    {../LIB}
# Folder with rsa_core_32bits.sv and rsa_apb_top.sv (default: the folder above genus/)
set RTL_DIR      {../rtl/RSA_APB}
# Clock period in ns (used by rsa_apb.sdc)
set CLK_PERIOD   10.0
################################################################################

set TOP          amba_3_apb_rsa_apb_top
set OUT_DIR      [file join $RTL_DIR genus_out]
set RPT_DIR      [file join $OUT_DIR reports]
file mkdir $OUT_DIR
file mkdir $RPT_DIR

# ---- Setup
set_db init_lib_search_path [file dirname [lindex $LIB_FILES 0]]
set_db library              $LIB_FILES
set_db init_hdl_search_path $RTL_DIR
set_db hdl_error_on_blackbox true
set_db information_level    6

# ---- Read RTL (rsa_core.v is Verilog-2001, the wrapper is SystemVerilog)
read_hdl -sv rsa_core_32bits.sv
read_hdl -sv    rsa_apb_top.sv

# ---- Elaborate (default parameters: DATA_WIDTH 32, ADDR_WIDTH 12,
#      LOAD_GAP 1, SRST_CYCLES 2)
elaborate $TOP
current_design $TOP

check_design -unresolved
check_design > [file join $RPT_DIR check_design_elab.rpt]

# ---- Constraints
read_sdc [file join $RTL_DIR genus rsa_apb.sdc]

# ---- Synthesis
set_db syn_generic_effort medium
set_db syn_map_effort     medium
set_db syn_opt_effort     medium

syn_generic
syn_map
syn_opt

# ---- Reports
report_timing -max_paths 10          > [file join $RPT_DIR timing.rpt]
report_timing -unconstrained -max_paths 3 > [file join $RPT_DIR timing_unconstrained.rpt]
report_area                          > [file join $RPT_DIR area.rpt]
report_gates                         > [file join $RPT_DIR gates.rpt]
report_power                         > [file join $RPT_DIR power.rpt]
report_qor                           > [file join $RPT_DIR qor.rpt]
report_clock_gating                  > [file join $RPT_DIR clock_gating.rpt]
check_design                         > [file join $RPT_DIR check_design_final.rpt]
check_timing_intent                  > [file join $RPT_DIR check_timing_intent.rpt]

# ---- Outputs
write_hdl > [file join $OUT_DIR ${TOP}_netlist.v]
write_sdc > [file join $OUT_DIR ${TOP}.sdc]
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split \
          > [file join $OUT_DIR ${TOP}.sdf]
write_db -to_file [file join $OUT_DIR ${TOP}.db]

puts "Netlist: [file join $OUT_DIR ${TOP}_netlist.v]"
exit
