# Default, alternate, and boundary device addresses.
foreach address {22 165 0 255} {
    vsim -gDEVICE_ID=$address work.uart_address_tb
    set BreakOnAssertion 2
    onbreak {quit -force -code 1}
    run 20 ms
    if {![string equal -nocase [examine /uart_address_tb/test_completed] true]} {quit -force -code 1}
    quit -sim
}
echo "PASS: addressed UART tests"
