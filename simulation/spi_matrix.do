# Full supported-width matrix, including the fastest SPI divider.
onerror {quit -force -code 1}
onbreak {quit -force -code 1}
vcom -2002 -work work ../testbench/spi_modes_tb.vhd
set cases 0
foreach mode {0 1 2 3} {
    for {set bits 5} {$bits <= 32} {incr bits} {
        foreach divider {0 1 7} {
            vsim -gMODE=$mode -gBITS=$bits -gDIVIDER=$divider work.spi_modes_tb
            set BreakOnAssertion 2
            onbreak {quit -force -code 1}
            run 25 us
            if {![string equal -nocase [examine /spi_modes_tb/test_completed] true]} {quit -force -code 1}
            incr cases
            quit -sim
        }
    }
}
echo "PASS: SPI matrix ($cases cases)"
