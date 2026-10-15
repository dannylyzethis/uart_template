create_clock -name clk_50 -period 20.000 [get_ports {clk_50}]
derive_clock_uncertainty

# Exempt asynchronous pad arrivals only at the first synchronizer stage.
# Inter-stage settling paths remain timed at clk_50.
set_false_path -from [get_ports {uart_rx}] -to [get_registers {*|uart_rx_sync[0]}]
set_false_path -from [get_ports {i2c0_sda i2c1_sda}] -to [get_registers {*|sda_sync[0]}]
set_false_path -from [get_ports {i2c0_scl i2c1_scl}] -to [get_registers {*|scl_sync[0]}]

# External reset drives only the conditioner async assertion pins. Its release
# propagates synchronously through the chain; do not cut reset_sync Q paths.
set_false_path -from [get_ports {reset_n}] -to [get_registers {*|reset_sync[*]}]
