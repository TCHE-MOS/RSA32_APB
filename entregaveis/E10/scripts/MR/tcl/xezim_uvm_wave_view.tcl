# Run after loading the dump: gtkwave run.fst -S xezim_uvm_wave_view.tcl
# Select only the top-level DUT pins, then fit the full time range.
set facilities [dict create]
for {set i 0} {$i < [gtkwave::getNumFacs]} {incr i} {
    set name [gtkwave::getFacName $i]
    regsub {\[.*$} $name {} base
    dict set facilities $base $name
}

set traces [list]
foreach {pin legacy_signal} {
    pclk_i    pclk
    presetn_i presetn
    psel_i    psel
    penable_i penable
    pwrite_i  pwrite
    paddr_i   paddr
    pwdata_i  pwdata
    prdata_o  prdata
    pready_o  pready
    pslverr_o pslverr
    irq_o     irq
} {
    set path "top_tb.th.dut_io_pinout.$pin"
    # Existing dumps from before the monitor was added remain usable.
    if {![dict exists $facilities $path]} {
        set path "top_tb.th.apb_rsa_if.$legacy_signal"
    }
    if {[dict exists $facilities $path]} {
        lappend traces [dict get $facilities $path]
    }
}

set added [gtkwave::addSignalsFromList $traces]
gtkwave::/Time/Zoom/Zoom_Full
puts "DUT_IO_PINOUT: $added pinos adicionados; intervalo [gtkwave::getFromEntry] a [gtkwave::getToEntry]"
