if {![file exists work]} {
    do compile_all.do
}

vsim work.spi_master_tb
set BreakOnAssertion 2
run 3 us

if {[examine /spi_master_tb/test_completed] ne "TRUE"} {
    echo "ERROR: SPI mode 1 testbench did not reach completion"
    quit -code 1
}

echo "SPI mode 1 testbench complete"
