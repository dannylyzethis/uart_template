# UART Register Interface for RF Test Automation

A robust UART-based register interface for FPGA control in RF test equipment.

## Features
- 64-bit control and status registers
- CRC-8 error detection
- I2C and SPI controller interfaces
- UART synchronization with clock domain crossing
- Configurable SPI parameters (CPOL, CPHA, word length, clock divider)

## Architecture
- 6 control registers (write from host)
- 6 status registers (read by host)
- Register-based commands (no text parsing)
- Consistent addressing scheme

## Register Map
- Control: 0x00-0x05 (write operations)
- Status: 0x10-0x15 (read operations)

## Files
- `src/uart_register_interface.vhd` - Main design
- `src/clean_uart_core.vhd` - UART controller
- `testbench/uart_register_tb_simple.vhd` - Testbench
- `simulation/run_tests.do` - ModelSim script

## Usage
1. Compile all source files
2. Run testbench: `do simulation/run_tests.do`
3. Integrate with your RF test system

## Author
RF Test Automation Beast 🚀