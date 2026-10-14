onerror {quit -force -code 1}
do compile_all.do
do fifo_tests.do
quit -force -code 0
