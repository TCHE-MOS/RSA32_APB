database -open waves -into $::env(WAVE_FILE) -event -default
probe -create [scope -tops] -all -depth all -database waves
run