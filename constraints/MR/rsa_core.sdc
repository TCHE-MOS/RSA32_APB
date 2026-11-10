# ============================================================
# SDC constraints for rsa_core
# ============================================================

# Create a 4 ns (250 MHz) clock on pclk_i (APB top clock port).
create_clock -name core_clk -period 4.0 [get_ports pclk_i]

# Apply input delay to all inputs except the clock and async reset.
set_input_delay 0.5 -clock core_clk \
    [remove_from_collection [all_inputs] [get_ports {pclk_i presetn_i}]]

# Apply output delay to all output ports
set_output_delay 0.2 -clock core_clk [all_outputs]

# Do not treat the asynchronous reset as a normal synchronous data path.
set_false_path -from [get_ports presetn_i]
