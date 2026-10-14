# Run after compile_all.do. Real UART packets plus deliberate TX stalls.
foreach depth {1 3 16 64} {
    vsim -gDEPTH=$depth work.sync_byte_fifo_tb
    set BreakOnAssertion 2
    onbreak {quit -force -code 1}
    run 100 us
    if {![string equal -nocase [examine /sync_byte_fifo_tb/test_completed] true]} {quit -force -code 1}
    quit -sim
}
vsim work.uart_fifo_tb
set BreakOnAssertion 2
onbreak {quit -force -code 1}
# Fault injection simulates a stalled UART sink without changing production RTL.
force -freeze /uart_fifo_tb/dut/tx_pop 0
run 12 ms
noforce /uart_fifo_tb/dut/tx_pop
run 4 ms
force -freeze /uart_fifo_tb/dut/tx_pop 0
run 2 ms
noforce /uart_fifo_tb/dut/tx_pop
run 14 ms
if {![string equal -nocase [examine /uart_fifo_tb/test_completed] true]} {quit -force -code 1}
quit -sim
echo "PASS: FIFO unit and UART integration tests"
