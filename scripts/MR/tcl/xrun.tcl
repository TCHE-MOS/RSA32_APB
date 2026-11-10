# Simulacao RTL em batch do testbench MR (tb): o TB nao grava ondas,
# entao o banco SHM e criado aqui.
database -open waves -into $::env(WAVE_FILE) -event -default
probe -create tb -all -depth all -database waves
run
exit
