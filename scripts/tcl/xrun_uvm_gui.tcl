# Ondas do topo UVM para depuracao no SimVision.
database -open waves -into $::env(WAVE_FILE) -event -default
probe -create top_tb -all -depth all -database waves
run
