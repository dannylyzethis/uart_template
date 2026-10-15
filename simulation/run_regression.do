# Headless regression: fail on compile errors, assertion errors, or incomplete tests.
onerror {quit -force -code 1}
onbreak {quit -force -code 1}
set BreakOnAssertion 2
# Run with simulation/ as the working directory.
do compile_all.do
foreach {tb duration} {uart_register_tb {45 ms} uart_system_tb {40 ms} spi_master_tb {3 us} uart_max10_tb {25 ms}} {
    vsim work.$tb
    set BreakOnAssertion 2
    onbreak {quit -force -code 1}
    run $duration
    if {![string equal -nocase [examine /$tb/test_completed] true]} {
        echo "FAIL: $tb did not reach completion"
        quit -force -code 1
    }
    echo "PASS: $tb"
    quit -sim
}
do address_tests.do
do fifo_tests.do
do i2c_matrix.do
do spi_matrix.do
echo "PASS: complete regression"
quit -force -code 0
