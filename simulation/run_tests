
# Save as "run_test.do"
vsim work.uart_register_tb
add wave -divider "Test Control"
add wave /uart_register_tb/test_phase
add wave /uart_register_tb/clk
add wave /uart_register_tb/rst
add wave -divider "Registers"
add wave -hex /uart_register_tb/ctrl_reg0
add wave -hex /uart_register_tb/ctrl_reg1
add wave -hex /uart_register_tb/ctrl_reg2
add wave /uart_register_tb/ctrl_write_strobe
add wave -divider "I2C/SPI"
add wave /uart_register_tb/i2c0_start
add wave /uart_register_tb/spi0_start
add wave -divider "Errors"
add wave /uart_register_tb/cmd_error
add wave /uart_register_tb/crc_error
run 500 us
wave zoom full