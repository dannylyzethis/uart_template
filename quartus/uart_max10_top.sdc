create_clock -name clk_50 -period 20.000 [get_ports {clk_50}]
derive_clock_uncertainty

# UART RX is asynchronous to the 50 MHz board clock and is synchronized in RTL.
set_false_path -from [get_ports {uart_rx}] -to [get_registers {*uart_rx_sync*}]
