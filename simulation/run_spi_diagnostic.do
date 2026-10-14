# Focused SPI regression; the previously failing cases must now pass.
# Run in simulation/. Override MODE/BITS using Tcl before invoking this script.
onerror {quit -force -code 1}
onbreak {quit -force -code 1}
set BreakOnAssertion 2
if {![info exists MODE]} {set MODE 0}
if {![info exists BITS]} {set BITS 8}
vcom -2002 -work work ../testbench/spi_modes_tb.vhd
vsim -gMODE=$MODE -gBITS=$BITS work.spi_modes_tb
set BreakOnAssertion 2
onbreak {quit -force -code 1}
run 25 us
if {![string equal -nocase [examine /spi_modes_tb/test_completed] true]} {
    quit -force -code 1
}
quit -force -code 0
