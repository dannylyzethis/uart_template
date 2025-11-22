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
# GPIO Interface
# ====================

# GPIO Output Banks (256 outputs total, 4 banks × 64 bits)
# Example: First 8 bits of each bank shown
# Uncomment and expand as needed for your application

# GPIO Output Bank 0 [63:0] - Example pins for bits 0-7
#set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports {gpio_out0[0]}]
#set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports {gpio_out0[1]}]
#set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS33} [get_ports {gpio_out0[2]}]
#set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports {gpio_out0[3]}]
#set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS33} [get_ports {gpio_out0[4]}]
#set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports {gpio_out0[5]}]
#set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports {gpio_out0[6]}]
#set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports {gpio_out0[7]}]
# ... add remaining bits [63:8] as needed

# GPIO Output Bank 1 [63:0] - Example pins for bits 0-7
#set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS33} [get_ports {gpio_out1[0]}]
#set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports {gpio_out1[1]}]
#set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports {gpio_out1[2]}]
#set_property -dict {PACKAGE_PIN C18 IOSTANDARD LVCMOS33} [get_ports {gpio_out1[3]}]
#set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS33} [get_ports {gpio_out1[4]}]
#set_property -dict {PACKAGE_PIN D16 IOSTANDARD LVCMOS33} [get_ports {gpio_out1[5]}]
#set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS33} [get_ports {gpio_out1[6]}]
#set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {gpio_out1[7]}]
# ... add remaining bits [63:8] as needed

# GPIO Output Bank 2 [63:0] - Example pins for bits 0-7
#set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS33} [get_ports {gpio_out2[0]}]
#set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS33} [get_ports {gpio_out2[1]}]
#set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33} [get_ports {gpio_out2[2]}]
#set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {gpio_out2[3]}]
#set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS33} [get_ports {gpio_out2[4]}]
#set_property -dict {PACKAGE_PIN F16 IOSTANDARD LVCMOS33} [get_ports {gpio_out2[5]}]
#set_property -dict {PACKAGE_PIN F17 IOSTANDARD LVCMOS33} [get_ports {gpio_out2[6]}]
#set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {gpio_out2[7]}]
# ... add remaining bits [63:8] as needed

# GPIO Output Bank 3 [63:0] - Example pins for bits 0-7
#set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports {gpio_out3[0]}]
#set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports {gpio_out3[1]}]
#set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS33} [get_ports {gpio_out3[2]}]
#set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS33} [get_ports {gpio_out3[3]}]
#set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports {gpio_out3[4]}]
#set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports {gpio_out3[5]}]
#set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {gpio_out3[6]}]
#set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS33} [get_ports {gpio_out3[7]}]
# ... add remaining bits [63:8] as needed

# GPIO Input Banks (256 inputs total, 4 banks × 64 bits)
# Example: First 8 bits of each bank shown
# Uncomment and expand as needed for your application

# GPIO Input Bank 0 [63:0] - Example pins for bits 0-7
#set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {gpio_in0[0]}]
#set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports {gpio_in0[1]}]
#set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports {gpio_in0[2]}]
#set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports {gpio_in0[3]}]
#set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {gpio_in0[4]}]
#set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports {gpio_in0[5]}]
#set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports {gpio_in0[6]}]
#set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {gpio_in0[7]}]
# ... add remaining bits [63:8] as needed

# GPIO Input Bank 1 [63:0] - Example pins for bits 0-7
#set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS33} [get_ports {gpio_in1[0]}]
#set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {gpio_in1[1]}]
#set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports {gpio_in1[2]}]
#set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports {gpio_in1[3]}]
#set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS33} [get_ports {gpio_in1[4]}]
#set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVCMOS33} [get_ports {gpio_in1[5]}]
#set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports {gpio_in1[6]}]
#set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports {gpio_in1[7]}]
# ... add remaining bits [63:8] as needed

# GPIO Input Bank 2 [63:0] - Example pins for bits 0-7
#set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports {gpio_in2[0]}]
#set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {gpio_in2[1]}]
#set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {gpio_in2[2]}]
#set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports {gpio_in2[3]}]
#set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {gpio_in2[4]}]
#set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports {gpio_in2[5]}]
#set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports {gpio_in2[6]}]
#set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {gpio_in2[7]}]
# ... add remaining bits [63:8] as needed

# GPIO Input Bank 3 [63:0] - Example pins for bits 0-7
#set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33} [get_ports {gpio_in3[0]}]
#set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {gpio_in3[1]}]
#set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {gpio_in3[2]}]
#set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {gpio_in3[3]}]
#set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {gpio_in3[4]}]
#set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {gpio_in3[5]}]
#set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports {gpio_in3[6]}]
#set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {gpio_in3[7]}]
# ... add remaining bits [63:8] as needed

# NOTE: GPIO pins are commented out by default
# Uncomment and modify pin assignments based on your board's available I/O
# Total GPIO capacity: 512 pins (256 outputs + 256 inputs)

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
