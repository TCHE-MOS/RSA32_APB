
# ============================================================
# APB RSA peripheral - shared constraints for all PDKs
# Constraint time unit: 1 ns
# Target clock: 100 MHz -> 10 ns
# ============================================================

# ------------------------------------------------------------
# Primary clock
# ------------------------------------------------------------

create_clock \
    -name pclk_i \
    -period 10.0 \
    [get_ports pclk_i]


# ------------------------------------------------------------
# Clock uncertainty
# ------------------------------------------------------------
# Preliminary setup margin: 2% of the 10 ns clock period.
# Adjust according to the real clock budget.

set_clock_uncertainty \
    -setup 0.2 \
    [get_clocks pclk_i]


# ------------------------------------------------------------
# APB input ports
# ------------------------------------------------------------
# Exclude asynchronous reset and primary clock.

set APB_INPUTS [get_ports {
    psel_i
    penable_i
    pwrite_i
    paddr_i*
    pwdata_i*
}]


# ------------------------------------------------------------
# Input interface delays
# ------------------------------------------------------------
# Maximum: provisional external arrival budget of 2 ns
# (20% of the clock period); confirm with the APB source.
# Minimum: provisional earliest arrival of 0 ns.

set_input_delay \
    -clock pclk_i \
    -max 2.0 \
    $APB_INPUTS

set_input_delay \
    -clock pclk_i \
    -min 0.0 \
    $APB_INPUTS


# ------------------------------------------------------------
# APB output ports
# ------------------------------------------------------------

set APB_OUTPUTS [get_ports {
    prdata_o*
    pready_o
    pslverr_o
    irq_o
}]


# ------------------------------------------------------------
# Output interface delays
# ------------------------------------------------------------
# Maximum: provisional external receiver budget of 2 ns
# (20% of the clock period); confirm with the APB receiver.
# Minimum: provisional value; replace with the
# receiver's actual hold requirement.

set_output_delay \
    -clock pclk_i \
    -max 2.0 \
    $APB_OUTPUTS

set_output_delay \
    -clock pclk_i \
    -min 0.0 \
    $APB_OUTPUTS


# ------------------------------------------------------------
# Asynchronous reset
# ------------------------------------------------------------
# presetn_i is intentionally excluded from synchronous
# input delays.
#
# Review reset timing paths and recovery/removal checks
# separately before declaring timing exceptions.
