onerror {quit -force -code 1}
do compile_all.do
vcom -2002 -work work ../testbench/i2c_test_slave.vhd
vcom -2002 -work work ../testbench/uart_max10_tb.vhd
vsim work.uart_max10_tb
set BreakOnAssertion 2
onbreak {quit -force -code 1}
run 25 ms
if {![string equal -nocase [examine /uart_max10_tb/test_completed] true]} {quit -force -code 1}
quit -force -code 0
