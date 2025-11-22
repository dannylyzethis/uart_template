# Run Basic UART Register Testbench
# Simple register read/write test without I2C/SPI modules

# Ensure files are compiled
if {![file exists work]} {
    do compile_all.do
}

# Start simulation
vsim work.uart_register_tb

# Configure wave window
add wave -divider "Test Control"
add wave -color yellow /uart_register_tb/test_phase
add wave /uart_register_tb/clk
add wave /uart_register_tb/rst

add wave -divider "UART Signals"
add wave /uart_register_tb/uart_rx
add wave /uart_register_tb/uart_tx

add wave -divider "Control Registers"
add wave -hex /uart_register_tb/ctrl_reg0
add wave -hex /uart_register_tb/ctrl_reg1
add wave -hex /uart_register_tb/ctrl_reg2
add wave -hex /uart_register_tb/ctrl_reg3
add wave -hex /uart_register_tb/ctrl_reg4
add wave -hex /uart_register_tb/ctrl_reg5
add wave /uart_register_tb/ctrl_write_strobe

add wave -divider "Status Registers"
add wave -hex /uart_register_tb/status_reg0
add wave -hex /uart_register_tb/status_reg1
add wave /uart_register_tb/status_reg2
add wave /uart_register_tb/status_read_strobe

add wave -divider "I2C/SPI Control"
add wave /uart_register_tb/i2c0_start
add wave /uart_register_tb/i2c1_start
add wave /uart_register_tb/spi0_start
add wave /uart_register_tb/spi1_start

add wave -divider "Error Flags"
add wave -color red /uart_register_tb/cmd_error
add wave -color red /uart_register_tb/crc_error
add wave /uart_register_tb/cmd_valid

# Run simulation
run 500 us

# Zoom to full view
wave zoom full

echo ""
echo "=========================================="
echo "  Basic testbench simulation complete"
echo "=========================================="
echo ""
echo "Check transcript for test results"
echo "All tests should PASS"
