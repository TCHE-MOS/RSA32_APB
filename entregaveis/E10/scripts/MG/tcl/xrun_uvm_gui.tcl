# Ondas do topo UVM para depuracao no SimVision.
database -open waves -into $::env(WAVE_FILE) -event -default
probe -create top_tb -all -depth all -database waves
# VCD portavel com os sinais da hierarquia estatica (interface APB e DUT).
database -open waves_vcd -vcd -into $::env(VCD_FILE)
probe -create top_tb -all -depth all -database waves_vcd
run
