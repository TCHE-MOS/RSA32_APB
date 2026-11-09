load -run $::env(IMC_COV_RUN)

# GUI loading does not regenerate reports unless explicitly requested.
if {[info exists ::env(IMC_GENERATE_REPORTS)] && $::env(IMC_GENERATE_REPORTS) eq "1"} {
    source [file join [file dirname [info script]] report_common.tcl]
    flow_reports::init $::env(REPORT_DIR) rtl
    set provenance [open [flow_reports::path coverage_inputs txt] w]
    puts $provenance "Coverage database: $::env(IMC_COV_RUN)"
    close $provenance
    report -summary -cumulative on -inst -local off -out [flow_reports::path coverage]
    report_metrics -out [flow_reports::directory coverage_html] -overwrite -detail -metrics all -all
}
