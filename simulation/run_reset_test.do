onerror {quit -force -code 1}
do compile_all.do
vsim work.reset_synchronizer_tb
set BreakOnAssertion 2
onbreak {quit -force -code 1}
run 3 us
if {![string equal -nocase [examine /reset_synchronizer_tb/test_completed] true]} {quit -force -code 1}
quit -force -code 0
