#!/bin/sh
xrun \
    -64bit \
    -sv \
    -makelib svlib \
        ../rtl/rsa_core_32bits.sv \
        ../rtl/rsa_apb_top.sv \
	../rtl/rsa_apb_tb.sv \
    -endlib \
    -top svlib.tb \
    -l logs/xrun_svlog.log \
    -history_file logs/xrun.history \
    -xmlibdirname xcelium.d
