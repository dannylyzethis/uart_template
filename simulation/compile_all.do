# ModelSim Compilation Script for UART Register Interface
# Compiles all source files and testbenches
# Author: RF Test Automation Engineering

onerror {quit -force -code 1}

# Create work library if it does not exist
if {![file exists work]} {vlib work}
vmap work work

# Compile source files in dependency order
echo "Compiling VHDL source files..."

vcom -2002 -work work ../src/sync_byte_fifo.vhd

# 1. Basic UART core
vcom -2002 -work work ../src/uart_core.vhd

# 2. I2C and SPI masters
vcom -2002 -work work ../src/i2c_master.vhd
vcom -2002 -work work ../src/spi_master.vhd

# 3. Main UART register interface
vcom -2002 -work work ../src/uart_register_interface.vhd

vcom -2002 -work work ../src/uart_max10_top.vhd

# 4. Testbenches
echo "Compiling testbenches..."
vcom -2002 -work work ../testbench/uart_register_tb.vhd
vcom -2002 -work work ../testbench/uart_system_tb.vhd
vcom -2002 -work work ../testbench/spi_master_tb.vhd

vcom -2002 -work work ../testbench/spi_modes_tb.vhd
vcom -2002 -work work ../testbench/i2c_test_slave.vhd
vcom -2002 -work work ../testbench/i2c_master_tb.vhd
vcom -2002 -work work ../testbench/uart_max10_tb.vhd

vcom -2002 -work work ../testbench/sync_byte_fifo_tb.vhd
vcom -2002 -work work ../testbench/uart_fifo_tb.vhd

echo "Compilation complete!"
echo ""
echo "To run basic testbench:       do run_basic_test.do"
echo "To run comprehensive test:    do run_system_test.do"

vcom -2002 -work work ../testbench/uart_address_tb.vhd
