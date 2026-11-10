load -run $::env(IMC_COV_RUN)

# GUI loading does not regenerate reports unless explicitly requested.
if {[info exists ::env(IMC_GENERATE_REPORTS)] && $::env(IMC_GENERATE_REPORTS) eq "1"} {
    source [file join $::env(PROJECT_ROOT) scripts MG tcl report_common.tcl]
    flow_reports::init $::env(REPORT_DIR) rtl
    set provenance [open [flow_reports::path coverage_inputs txt] w]
    puts $provenance "Coverage database: $::env(IMC_COV_RUN)"
    close $provenance
    # Percentuais por itens cobertos (com denominadores), sem misturar a
    # cobertura funcional da UVM com a cobertura estrutural do DUT.
    report -summary -cumulative on -inst -local off -metrics all -all \
        -out [flow_reports::path coverage]
    report -summary -cumulative on -inst -local off -grading covered \
        -metrics code:fsm:covergroup:assertion -all \
        -out [flow_reports::path coverage_rates] *
    report -detail -inst -metrics covergroup -all \
        -out [flow_reports::path coverage_covergroups]
    report_metrics -out [flow_reports::directory coverage_html] -overwrite -detail -metrics all -all
}
