# UART Register Interface for RF Test Automation

A robust UART-based register interface for FPGA control in RF test equipment.

## Features
- 64-bit control and status registers
- CRC-8 error detection
- I2C and SPI controller interfaces
- UART synchronization with clock domain crossing
- Configurable SPI parameters (CPOL, CPHA, word length, clock divider)

## Architecture
- 6 application control/status registers plus sticky error status and clear registers
- Register-based commands (no text parsing)
- Consistent addressing scheme

## Register Map
- Control: 0x00-0x06 (write operations; 0x06 clears sticky errors)
- Status: 0x10-0x18 (0x16 sticky errors, 0x17 FIFO status, 0x18 FIFO capacities)

## Files
- `src/uart_register_interface.vhd` - Main design
- `src/reset_synchronizer.vhd` - External reset capture and synchronized release
- `src/uart_core.vhd` - UART controller
- `src/sync_byte_fifo.vhd` - Configurable synchronous byte FIFO (M9K storage)
- `testbench/uart_register_tb.vhd` - Testbench
- `simulation/run_regression.do` - ModelSim script

## Usage
1. Compile all source files
2. From `simulation/`, run `vsim -c -do "do run_regression.do"`
3. Integrate with your RF test system

## Author
RF Test Automation Beast 🚀

## MAX 10 validation

See [FPGA validation](docs/FPGA_VALIDATION.md) for ModelSim MCP and Quartus MCP commands, measured fit/timing results, and verified SPI/I2C fixes. The current Quartus target is 10M08SAE144C8G at 50 MHz; board pin assignments and external timing are still required before programming.

### UART buffering

RX and TX each have a configurable 64-byte FIFO by default, with concurrent
receive/transmit, TX backpressure, queue status, and sticky overflow flags.
RX overflow flushes queued input and requires 10 ms of continuous line idle
to resynchronize. Packets now include a leading device address in the CRC. See the
[register specification](docs/UART_Register_Interface_Specification.md) for
queue fields and recovery, and [validation results](docs/FPGA_VALIDATION.md)
for ModelSim coverage and the provisional MAX 10 fit.

### Device addressing

Commands: `[DEVICE][CMD][REGISTER][DATA x 8][CRC]` (12 bytes).
Replies: `[DEVICE][0x02][DATA x 8][CRC]` (11 bytes).
The top-level `DEVICE_ADDRESS` generic defaults to `x"16"`; it is a logic
constant, with no runtime flash writes. Other device addresses are ignored
while preserving packet boundaries. Python uses
`UARTRegisterInterface(port="COM3", device_address=0x16)`.
This wire-format change requires updating legacy hosts with the FPGA image.

### Reset and CDC checks

The top level captures active-low reset and releases internal reset after two
50 MHz clock edges. UART RX and I2C inputs have preserved synchronizer chains;
Quartus recognizes all six chains including reset. After fitting, run
`make check-cdc` to verify exception endpoints and timed inter-stage paths.
Controller resets remain synchronous; board pins and SPI external timing still
need board-specific validation before programming.
