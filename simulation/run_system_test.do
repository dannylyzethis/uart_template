# Run Comprehensive System Testbench
# Full system test with I2C and SPI master modules

# Ensure files are compiled
if {![file exists work]} {
    do compile_all.do
}

# Start simulation
vsim work.uart_system_tb

# Configure wave window
add wave -divider "Test Control"
add wave -color yellow /uart_system_tb/test_phase
add wave -decimal /uart_system_tb/test_pass_count
add wave -decimal /uart_system_tb/test_fail_count
add wave /uart_system_tb/clk
add wave /uart_system_tb/rst

add wave -divider "UART Interface"
add wave /uart_system_tb/uart_rx
add wave /uart_system_tb/uart_tx

add wave -divider "Control Registers"
add wave -hex /uart_system_tb/ctrl_reg0
add wave -hex /uart_system_tb/ctrl_reg1
add wave -hex /uart_system_tb/ctrl_reg2
add wave -hex /uart_system_tb/ctrl_reg3
add wave -hex /uart_system_tb/ctrl_reg4
add wave -hex /uart_system_tb/ctrl_reg5

add wave -divider "Status Registers"
add wave -hex /uart_system_tb/status_reg0
add wave -hex /uart_system_tb/status_reg1
add wave -hex /uart_system_tb/status_reg2
add wave -hex /uart_system_tb/status_reg3

add wave -divider "I2C0 Signals"
add wave /uart_system_tb/i2c0_sda
add wave /uart_system_tb/i2c0_scl
add wave /uart_system_tb/i2c0_start
add wave /uart_system_tb/i2c0_busy
add wave /uart_system_tb/i2c0_done
add wave -hex /uart_system_tb/i2c0_data_in
add wave -hex /uart_system_tb/i2c0_data_out
add wave /uart_system_tb/i2c0_ack_error

add wave -divider "SPI0 Signals"
add wave /uart_system_tb/spi0_sclk
add wave /uart_system_tb/spi0_mosi
add wave /uart_system_tb/spi0_miso
add wave -binary /uart_system_tb/spi0_cs
add wave /uart_system_tb/spi0_start
add wave /uart_system_tb/spi0_busy
add wave /uart_system_tb/spi0_done
add wave -hex /uart_system_tb/spi0_data_in
add wave -hex /uart_system_tb/spi0_data_out

add wave -divider "Error Flags"
add wave -color red /uart_system_tb/cmd_error
add wave -color red /uart_system_tb/crc_error
add wave -color red /uart_system_tb/timeout_error
add wave -color green /uart_system_tb/cmd_valid

# Run simulation (longer time for comprehensive test)
run 20 ms

# Zoom to full view
wave zoom full

echo ""
echo "=========================================="
echo "  System testbench simulation complete"
echo "=========================================="
echo ""
echo "Check transcript for detailed test results"
echo "Test summary should show PASSED tests"
