# Run from quartus/: quartus_sta -t check_cdc.tcl
project_open uart_max10_top
create_timing_netlist
read_sdc
update_timing_netlist
foreach {pattern expected} {
    {*|uart_rx_sync[0]} 1
    {*|sda_sync[0]} 2
    {*|scl_sync[0]} 2
    {*|reset_sync[*]} 2
} {
    set count [get_collection_size [get_registers $pattern]]
    if {$count != $expected} {error "CDC register match failed: $pattern expected $expected got $count"}
}
# Verify asynchronous pad exceptions do not cut synchronizer settling paths.
foreach stem {uart_rx_sync sda_sync scl_sync reset_sync} {
    set sources [get_registers [format {*|%s[0]} $stem]]
    set targets [get_registers [format {*|%s[1]} $stem]]
    set paths [get_timing_paths -from $sources -to $targets -npaths 10]
    if {[get_collection_size $paths] != [get_collection_size $sources]} {
        error "Missing timed inter-stage path for $stem"
    }
}
set paths [get_timing_paths -from [get_registers {*|uart_rx_sync[1]}] -to [get_registers {*|uart_rx_sync[2]}]]
if {[get_collection_size $paths] != 1} {error "Missing UART stage 1 to 2 timing path"}
report_metastability -file output_files/cdc_metastability.rpt
report_exceptions -file output_files/cdc_exceptions.rpt
puts "PASS: CDC endpoints and all seven synchronizer inter-stage paths remain timed"
delete_timing_netlist
project_close
