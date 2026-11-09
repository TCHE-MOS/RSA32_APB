# Ondas do topo UVM, incluindo interface APB e DUT.
database -open waves -into $::env(WAVE_FILE) -event -default
probe -create top_tb -all -depth all -database waves
run
exit
