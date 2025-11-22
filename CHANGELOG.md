# Changelog

All notable changes to the UART Register Interface project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-22

### 🎉 Major Release - Complete System Overhaul

This release represents a complete rewrite and enhancement of the UART register interface, transforming it from a basic prototype into a production-ready system.

### Added
- **Full I2C Master Implementation**
  - Proper start/stop conditions
  - ACK/NACK handling
  - Clock stretching support
  - Configurable 100kHz/400kHz operation
  - Complete state machine with error handling

- **Full SPI Master Implementation**
  - All 4 SPI modes (CPOL/CPHA combinations)
  - Configurable word length (5-32 bits)
  - Programmable clock divider
  - 4 independent chip selects per controller
  - Full-duplex operation

- **Timeout and Error Recovery**
  - 10ms watchdog timeout for incomplete packets
  - Automatic state machine recovery
  - Timeout error flag output
  - Prevents system lockup

- **Comprehensive Python Host Library**
  - Complete API for all register operations
  - High-level I2C/SPI control methods
  - CRC-8 calculation and verification
  - Communication statistics tracking
  - Context manager support
  - Example scripts for testing

- **Enhanced Testbenches**
  - New comprehensive system testbench with I2C/SPI modules
  - Full test coverage (7+ test cases)
  - Automated pass/fail reporting
  - Integrated I2C and SPI behavioral models

- **Build System and Automation**
  - Makefile for easy compilation and testing
  - ModelSim compilation scripts
  - Automated test execution
  - Python dependency management

- **FPGA Constraints**
  - Complete XDC file for Xilinx FPGAs
  - Pin assignments with comments
  - Timing constraints for all interfaces
  - Bitstream configuration settings

- **Documentation**
  - Comprehensive README with quickstart
  - Detailed specification document
  - Python API documentation
  - Example code and usage guides
  - Troubleshooting section

### Fixed
- **CRITICAL: SPI Trigger Logic Bug**
  - Fixed incorrect SPI trigger conditions
  - SPI0 now triggers on ctrl_reg4 write (was ctrl_reg3)
  - SPI1 now triggers on ctrl_reg5 write (was using wrong bit)
  - Proper enable bit checking (bit 63 of config register)

- **Response Packet Format Mismatch**
  - Updated specification to match 10-byte implementation
  - Response now: HDR(1) + DATA(8) + CRC(1) = 10 bytes
  - Fixed documentation inconsistency

- **Clock Domain Crossing**
  - Added proper 2-FF synchronizer for UART RX
  - Prevents metastability issues
  - Ensures reliable asynchronous operation

### Changed
- **I2C/SPI Integration**
  - Removed stub implementations
  - Replaced with full master controllers
  - Separate VHDL modules for each peripheral
  - Instantiated in system testbench

- **Error Handling**
  - Enhanced CRC error detection
  - Added command error flags
  - Improved invalid address handling
  - Added timeout detection

- **Testbench Architecture**
  - Split into basic and comprehensive tests
  - Added real I2C/SPI module integration
  - Improved test reporting
  - Added statistics tracking

### Performance
- **FPGA Resource Usage** (Artix-7 example)
  - LUTs: ~450 (was ~200 - due to full I2C/SPI)
  - FFs: ~350 (was ~150)
  - Max frequency: >150MHz (unchanged)
  - No BRAM usage

- **Communication**
  - UART: 115200 baud (configurable)
  - I2C: Up to 400kHz
  - SPI: Up to 50MHz
  - Packet latency: <100µs

### Migration Guide from 1.x
1. Update `uart_register_interface.vhd` - new timeout_error port added
2. Add new files: `i2c_master.vhd`, `spi_master.vhd`
3. Update testbench to include timeout_error signal
4. Recompile with new Python library for host control
5. Update XDC constraints with new timing requirements

---

## [1.0.0] - 2025-08-17

### Initial Release

### Added
- Basic UART register interface
- 64-bit control and status registers
- CRC-8 error detection
- Simple UART core (8N1, 115200 baud)
- Basic register read/write commands
- Simple testbench
- Initial specification document

### Known Issues
- SPI trigger logic bug (fixed in 2.0.0)
- Response packet format mismatch (fixed in 2.0.0)
- I2C/SPI stubs only (implemented in 2.0.0)
- No timeout protection (added in 2.0.0)
- Limited error handling

---

## Release Notes

### Version Numbering
- **MAJOR** version: Incompatible API changes
- **MINOR** version: Backwards-compatible functionality additions
- **PATCH** version: Backwards-compatible bug fixes

### Upgrade Path
- 1.x → 2.0: Major breaking changes, follow migration guide
- Future 2.x versions will maintain backwards compatibility

### Support
- Version 2.x: Actively maintained
- Version 1.x: No longer supported (critical bugs only)

---

## Upcoming Features (Roadmap)

### Planned for 2.1.0
- [ ] LabVIEW VI library
- [ ] Multi-byte I2C transaction support
- [ ] DMA support for high-speed data transfer
- [ ] Hardware flow control option

### Planned for 2.2.0
- [ ] AXI-Lite interface option
- [ ] Interrupt generation support
- [ ] Enhanced debugging features
- [ ] Performance profiling tools

### Under Consideration
- [ ] USB interface support
- [ ] Ethernet interface option
- [ ] QSPI support
- [ ] Built-in protocol analyzer

---

**Note:** This changelog follows the principles of [Keep a Changelog](https://keepachangelog.com/).
For detailed commit history, see the git log.
