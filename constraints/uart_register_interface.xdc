# Xilinx Design Constraints (XDC) for UART Register Interface
# Update pin assignments for your specific FPGA board
# Author: RF Test Automation Engineering
# Date: 2025-11-22

# ====================
# Clock Constraints
# ====================

# System clock - 100 MHz (adjust for your board)
create_clock -period 10.000 -name sys_clk [get_ports clk]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]

# ====================
# UART Signals
# ====================

# UART RX (input from host PC)
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports uart_rx]
set_property PULLUP true [get_ports uart_rx]

# UART TX (output to host PC)
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports uart_tx]

# ====================
# I2C0 Interface
# ====================

set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports i2c0_sda]
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS33} [get_ports i2c0_scl]
set_property PULLUP true [get_ports i2c0_sda]
set_property PULLUP true [get_ports i2c0_scl]

# ====================
# I2C1 Interface
# ====================

set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS33} [get_ports i2c1_sda]
set_property -dict {PACKAGE_PIN B13 IOSTANDARD LVCMOS33} [get_ports i2c1_scl]
set_property PULLUP true [get_ports i2c1_sda]
set_property PULLUP true [get_ports i2c1_scl]

# ====================
# SPI0 Interface
# ====================

set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports spi0_sclk]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports spi0_mosi]
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports spi0_miso]
set_property PULLUP true [get_ports spi0_miso]

# SPI0 Chip Selects
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {spi0_cs[0]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {spi0_cs[1]}]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports {spi0_cs[2]}]
set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS33} [get_ports {spi0_cs[3]}]

# ====================
# SPI1 Interface
# ====================

set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} [get_ports spi1_sclk]
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports spi1_mosi]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports spi1_miso]
set_property PULLUP true [get_ports spi1_miso]

# SPI1 Chip Selects
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {spi1_cs[0]}]
set_property -dict {PACKAGE_PIN N13 IOSTANDARD LVCMOS33} [get_ports {spi1_cs[1]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {spi1_cs[2]}]
set_property -dict {PACKAGE_PIN P13 IOSTANDARD LVCMOS33} [get_ports {spi1_cs[3]}]

# ====================
# Reset Signal
# ====================

set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports rst]

# ====================
# Timing Constraints
# ====================

# UART RX is asynchronous - set as false path from input
set_false_path -from [get_ports uart_rx]

# I2C and SPI are controlled by internal logic - constrain appropriately
# I2C max frequency 400kHz (2.5us period)
set_max_delay -from [get_clocks sys_clk] -to [get_ports {i2c0_sda i2c0_scl}] 2500.0
set_max_delay -from [get_clocks sys_clk] -to [get_ports {i2c1_sda i2c1_scl}] 2500.0

# SPI max frequency depends on clock divider setting
# Conservative constraint for up to 50MHz SPI clock
set_max_delay -from [get_clocks sys_clk] -to [get_ports {spi0_sclk spi0_mosi spi0_cs[*]}] 20.0
set_max_delay -from [get_clocks sys_clk] -to [get_ports {spi1_sclk spi1_mosi spi1_cs[*]}] 20.0

set_max_delay -from [get_ports {spi0_miso spi1_miso}] -to [get_clocks sys_clk] 20.0

# ====================
# Configuration
# ====================

# Bitstream settings
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

# ====================
# Notes
# ====================

# IMPORTANT: Update PACKAGE_PIN assignments for your specific FPGA board
#
# This XDC file provides example constraints for:
# - Artix-7 / Spartan-7 FPGAs
# - LVCMOS33 I/O standard
# - 100 MHz system clock
#
# Refer to your board's schematic for correct pin assignments
