# Synopsys Design Constraints (SDC) for UART Register Interface
# Timing constraints for Intel/Altera Quartus
# Author: RF Test Automation Engineering
# Date: 2025-11-22

# ====================
# Clock Definitions
# ====================

# System clock - 100 MHz (10 ns period)
create_clock -name sys_clk -period 10.000 [get_ports {clk}]

# Derive PLL clocks if you use PLLs
derive_pll_clocks
derive_clock_uncertainty

# ====================
# Input Delays
# ====================

# UART RX is asynchronous - set as false path
set_false_path -from [get_ports {uart_rx}] -to *

# SPI MISO inputs - assume max 50MHz SPI clock (20ns period)
# Setup time relative to system clock
set_input_delay -clock sys_clk -max 2.0 [get_ports {spi0_miso}]
set_input_delay -clock sys_clk -min 0.5 [get_ports {spi0_miso}]
set_input_delay -clock sys_clk -max 2.0 [get_ports {spi1_miso}]
set_input_delay -clock sys_clk -min 0.5 [get_ports {spi1_miso}]

# I2C is bidirectional and slow (400kHz max = 2500ns period)
# Set false path for simplicity
set_false_path -from [get_ports {i2c0_sda i2c0_scl}] -to *
set_false_path -from * -to [get_ports {i2c0_sda i2c0_scl}]
set_false_path -from [get_ports {i2c1_sda i2c1_scl}] -to *
set_false_path -from * -to [get_ports {i2c1_sda i2c1_scl}]

# Reset is asynchronous
set_false_path -from [get_ports {rst}] -to *

# ====================
# Output Delays
# ====================

# UART TX - asynchronous serial, no tight timing requirement
set_output_delay -clock sys_clk -max 5.0 [get_ports {uart_tx}]
set_output_delay -clock sys_clk -min 0.0 [get_ports {uart_tx}]

# SPI outputs - assume board trace delays ~2ns
set_output_delay -clock sys_clk -max 2.0 [get_ports {spi0_sclk spi0_mosi spi0_cs[*]}]
set_output_delay -clock sys_clk -min 0.5 [get_ports {spi0_sclk spi0_mosi spi0_cs[*]}]
set_output_delay -clock sys_clk -max 2.0 [get_ports {spi1_sclk spi1_mosi spi1_cs[*]}]
set_output_delay -clock sys_clk -min 0.5 [get_ports {spi1_sclk spi1_mosi spi1_cs[*]}]

# ====================
# Multicycle Paths
# ====================

# UART core runs at 115200 baud = ~8.68us per bit
# Allow multiple cycles for UART bit timing
set_multicycle_path -from [get_registers {*uart_core*}] -to [get_registers {*uart_core*}] -setup 2
set_multicycle_path -from [get_registers {*uart_core*}] -to [get_registers {*uart_core*}] -hold 1

# I2C master runs at 100kHz-400kHz, much slower than system clock
set_multicycle_path -from [get_registers {*i2c_master*}] -to [get_registers {*i2c_master*}] -setup 4
set_multicycle_path -from [get_registers {*i2c_master*}] -to [get_registers {*i2c_master*}] -hold 2

# ====================
# Timing Exceptions
# ====================

# Clock domain crossing for UART RX synchronizer
# The uart_rx_sync chain is specifically designed for CDC
set_false_path -from [get_ports {uart_rx}] -to [get_registers {*uart_rx_sync[0]*}]

# ====================
# Timing Goals
# ====================

# Set timing to meet 100 MHz operation
set_max_delay -from [get_clocks sys_clk] -to [get_clocks sys_clk] 10.0

# Relaxed timing for slow peripherals
set_max_delay -to [get_ports {i2c0_sda i2c0_scl i2c1_sda i2c1_scl}] 100.0

# ====================
# Additional Constraints
# ====================

# Cut timing paths between unrelated register domains if needed
# (Add specific paths based on your design requirements)

# Report timing summary after compilation
# set_global_assignment -name TIMEQUEST_REPORT_SCRIPT uart_timing_report.tcl

# ====================
# Notes
# ====================

# These constraints ensure:
# 1. System clock runs at 100 MHz
# 2. Asynchronous inputs (UART, I2C) are handled correctly
# 3. Multicycle paths for slow peripherals
# 4. Proper setup/hold times for SPI communication
#
# Adjust constraints based on your:
# - Actual system clock frequency
# - Board trace delays
# - Peripheral timing requirements
