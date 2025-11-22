# Quartus Project Creation Script
# Creates a new Quartus project for UART Register Interface
# Author: RF Test Automation Engineering
# Date: 2025-11-22
#
# Usage: quartus_sh -t create_quartus_project.tcl

# ====================
# Project Settings
# ====================

# Project name
set project_name "uart_register_interface"

# Top-level entity
set top_level "uart_register_interface"

# Device family and part (UPDATE FOR YOUR BOARD)
set family "Cyclone V"
set device "5CSEMA5F31C6"

# ====================
# Create Project
# ====================

# Load Quartus package
package require ::quartus::project

# Create new project
project_new $project_name -overwrite

# Set device
set_global_assignment -name FAMILY $family
set_global_assignment -name DEVICE $device
set_global_assignment -name TOP_LEVEL_ENTITY $top_level

# ====================
# Add Source Files
# ====================

puts "Adding VHDL source files..."

# VHDL source files (in compilation order)
set_global_assignment -name VHDL_FILE ../src/uart_core.vhd
set_global_assignment -name VHDL_FILE ../src/i2c_master.vhd
set_global_assignment -name VHDL_FILE ../src/spi_master.vhd
set_global_assignment -name VHDL_FILE ../src/uart_register_interface.vhd

# ====================
# Add Constraint Files
# ====================

puts "Adding constraint files..."

# QSF settings (pin assignments, etc.)
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE ../constraints/uart_register_interface.qsf

# SDC timing constraints
set_global_assignment -name SDC_FILE ../constraints/uart_register_interface.sdc

# ====================
# Compilation Settings
# ====================

puts "Configuring compilation settings..."

# VHDL version
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008

# Optimization
set_global_assignment -name OPTIMIZATION_MODE "HIGH PERFORMANCE EFFORT"
set_global_assignment -name OPTIMIZATION_TECHNIQUE SPEED

# Physical synthesis
set_global_assignment -name PHYSICAL_SYNTHESIS_COMBO_LOGIC ON
set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_DUPLICATION ON
set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_RETIMING ON

# TimeQuest settings
set_global_assignment -name TIMEQUEST_MULTICORNER_ANALYSIS ON
set_global_assignment -name TIMEQUEST_DO_CCPP_REMOVAL ON

# Fitter settings
set_global_assignment -name FITTER_EFFORT "STANDARD FIT"
set_global_assignment -name ROUTER_TIMING_OPTIMIZATION_LEVEL MAXIMUM

# ====================
# Partition Settings
# ====================

set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top

# ====================
# Message Settings
# ====================

# Suppress common warnings that are not issues
set_global_assignment -name MESSAGE_DISABLE 10335
set_global_assignment -name MESSAGE_DISABLE 15610

# ====================
# Programming Settings
# ====================

set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED"

# ====================
# Save and Close
# ====================

# Commit assignments
export_assignments

# Close project
project_close

puts ""
puts "=========================================="
puts "  Quartus Project Created Successfully!"
puts "=========================================="
puts ""
puts "Project: $project_name"
puts "Device:  $device"
puts "Top:     $top_level"
puts ""
puts "Next steps:"
puts "1. Open Quartus: quartus $project_name.qpf"
puts "2. Update pin assignments in constraints/uart_register_interface.qsf"
puts "3. Run: Processing > Start Compilation"
puts ""
puts "Or compile from command line:"
puts "  quartus_sh --flow compile $project_name"
puts ""
