# ####################################################################

#  Created by Genus(TM) Synthesis Solution 22.18-s061_1 on Mon Nov 09 16:57:31 -03 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design amba_3_apb_rsa_apb_top

set_clock_gating_check -setup 0.0 
set_wire_load_mode "segmented"
