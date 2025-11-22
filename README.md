# UART Register Interface for RF Test Automation

A complete, production-ready UART-based register interface for FPGA control in RF test equipment. Features robust error detection, I2C/SPI peripheral support, and comprehensive Python host libraries.

[![FPGA](https://img.shields.io/badge/FPGA-Xilinx%20%7C%20Intel-blue)]()
[![VHDL](https://img.shields.io/badge/VHDL-2002-green)]()
[![Python](https://img.shields.io/badge/Python-3.7%2B-blue)]()
[![License](https://img.shields.io/badge/License-MIT-yellow)]()

---

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Quick Start](#-quick-start)
- [Documentation](#-documentation)
- [Project Structure](#-project-structure)
- [Hardware Requirements](#-hardware-requirements)
- [Software Requirements](#-software-requirements)
- [Usage Examples](#-usage-examples)
- [Testing](#-testing)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

### Core Features
- **64-bit Register Architecture** - Efficient data transfer with 6 control and 6 status registers
- **CRC-8 Error Detection** - Robust communication with automatic error checking
- **Register-Based Commands** - No text parsing overhead for maximum performance
- **Timeout Protection** - Automatic recovery from incomplete UART packets
- **Clock Domain Crossing** - Proper synchronization for asynchronous UART operation

### Peripheral Support
- **Dual I2C Masters** - Independent 100kHz/400kHz I2C controllers
- **Dual SPI Masters** - Configurable CPOL/CPHA, 5-32 bit word length, up to 50MHz
- **4 Chip Selects per SPI** - Support for multiple SPI devices
- **Real-time Status Monitoring** - Current, voltage, and performance counters

### Software Integration
- **Python Host Library** - Complete API for PC-based control
- **Example Scripts** - Ready-to-use test and integration examples
- **LabVIEW Compatible** - Protocol designed for LabVIEW integration

---

## 🏗️ Architecture

```
┌─────────────┐    UART     ┌──────────────────────┐    Control    ┌─────────────┐
│   Host PC   │◄──────────►│  UART Register       │◄─────────────►│   RF Test   │
│  (Python/   │  115200bps  │  Interface (FPGA)    │   Signals     │  Hardware   │
│   LabVIEW)  │             │                      │               └─────────────┘
└─────────────┘             │  ┌────────────────┐  │
                            │  │ Control Regs   │  │               ┌─────────────┐
                            │  │   0x00-0x05    │  │    I2C0/1     │  External   │
                            │  └────────────────┘  │◄─────────────►│  I2C        │
                            │  ┌────────────────┐  │               │  Devices    │
                            │  │ Status Regs    │  │               └─────────────┘
                            │  │   0x10-0x15    │  │
                            │  └────────────────┘  │               ┌─────────────┐
                            │                      │    SPI0/1     │  External   │
                            │  ┌────────────────┐  │◄─────────────►│  SPI        │
                            │  │ I2C/SPI        │  │               │  Devices    │
                            │  │ Controllers    │  │               └─────────────┘
                            └──────────────────────┘
```

### Register Map

#### Control Registers (Write Operations)
| Address | Name | Description |
|---------|------|-------------|
| 0x00 | CTRL_SYSTEM | System control and reset |
| 0x01 | CTRL_SWITCH | Switch bank control (4x16-bit) |
| 0x02 | CTRL_I2C | I2C transaction control |
| 0x03 | CTRL_SPI_DATA | SPI transmit data (2x32-bit) |
| 0x04 | CTRL_SPI0_CONFIG | SPI0 configuration |
| 0x05 | CTRL_SPI1_CONFIG | SPI1 configuration |

#### Status Registers (Read Operations)
| Address | Name | Description |
|---------|------|-------------|
| 0x10 | STATUS_SYSTEM | System status and flags |
| 0x11 | STATUS_CURRENT | Current measurements (4 channels) |
| 0x12 | STATUS_VOLTAGE | Voltage measurements + I2C RX data |
| 0x13 | STATUS_SPI_DATA | SPI received data (2x32-bit) |
| 0x14 | STATUS_SWITCH | Switch position readback |
| 0x15 | STATUS_COUNTERS | Performance counters |

---

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/uart_template.git
cd uart_template
```

### 2. Simulation (ModelSim/QuestaSim)
```bash
# Compile all sources
make compile

# Run comprehensive system test
make sim-system

# Or launch GUI for interactive debugging
make sim-gui
```

### 3. Python Setup
```bash
# Install dependencies
make install-python

# Run basic test (update port for your system)
python3 python/examples/basic_test.py --port /dev/ttyUSB0
```

### 4. FPGA Synthesis (Vivado)
```tcl
# In Vivado TCL console:
# 1. Add all source files from src/
# 2. Set uart_register_interface as top module
# 3. Add constraint file: constraints/uart_register_interface.xdc
# 4. Update pin assignments for your board
# 5. Run synthesis and implementation
```

---

## 📚 Documentation

- **[Complete Specification](docs/UART_Register_Interface_Specification.md)** - Detailed protocol and register documentation
- **[Python API Reference](python/uart_register_interface.py)** - Host library documentation
- **[Examples](python/examples/)** - Usage examples and test scripts

---

## 📁 Project Structure

```
uart_template/
├── src/                          # VHDL source files
│   ├── uart_register_interface.vhd  # Main register interface
│   ├── uart_core.vhd                # UART controller (8N1)
│   ├── i2c_master.vhd               # I2C master controller
│   └── spi_master.vhd               # SPI master controller
│
├── testbench/                    # VHDL testbenches
│   ├── uart_register_tb.vhd        # Basic register test
│   └── uart_system_tb.vhd          # Comprehensive system test
│
├── simulation/                   # ModelSim scripts
│   ├── compile_all.do              # Compilation script
│   ├── run_basic_test.do           # Basic test script
│   └── run_system_test.do          # System test script
│
├── constraints/                  # FPGA constraint files
│   └── uart_register_interface.xdc # Xilinx constraints (example)
│
├── python/                       # Python host library
│   ├── uart_register_interface.py  # Main library
│   ├── requirements.txt            # Dependencies
│   └── examples/                   # Example scripts
│       ├── basic_test.py          # Basic read/write test
│       └── spi_i2c_test.py        # SPI/I2C examples
│
├── docs/                         # Documentation
│   └── UART_Register_Interface_Specification.md
│
├── Makefile                      # Build automation
└── README.md                     # This file
```

---

## 🔧 Hardware Requirements

### FPGA
- **Xilinx:** Artix-7, Spartan-7, or higher
- **Intel:** Cyclone V, MAX 10, or higher
- **Minimum Resources:** 500 LUTs, 300 FFs, 0 BRAMs
- **Clock:** 100 MHz (configurable)

### I/O Requirements
- 2 UART pins (RX, TX) - 3.3V CMOS
- 4 I2C pins (2x SDA, 2x SCL) - Open-drain with pull-ups
- 12 SPI pins (2x SCLK, MOSI, MISO, 4x CS each)

### Host PC
- Serial port (USB-to-UART adapter)
- Python 3.7+ with pyserial
- Optional: LabVIEW 2018+

---

## 💻 Software Requirements

### Simulation
- ModelSim/QuestaSim 10.6+ or Vivado Simulator
- Make (optional, for automation)

### Synthesis
- Xilinx Vivado 2019.1+ **OR**
- Intel Quartus Prime 18.1+

### Host Software
- Python 3.7+
- pyserial library (`pip install pyserial`)

---

## 📝 Usage Examples

### Python - Basic Register Access
```python
from uart_register_interface import UARTRegisterInterface

with UARTRegisterInterface(port='/dev/ttyUSB0') as uart:
    # Write to control register
    uart.write_register(0x00, 0x123456789ABCDEF0)

    # Read from status register
    value = uart.read_register(0x10)
    print(f"Status: 0x{value:016X}")
```

### Python - SPI Configuration
```python
with UARTRegisterInterface(port='/dev/ttyUSB0') as uart:
    # Configure SPI: Mode 0, 16-bit, 1MHz
    uart.configure_spi(
        channel=0,
        cpol=False,
        cpha=False,
        word_len=16,
        clk_div=100,
        chip_select=0
    )

    # Write data
    uart.write_spi(channel=0, data=0xDEADBEEF)
```

### Python - I2C Transaction
```python
with UARTRegisterInterface(port='/dev/ttyUSB0') as uart:
    # Write to I2C device at address 0x50
    uart.write_i2c(channel=0, device_addr=0x50, data=0xAA)

    # Read received data
    voltages = uart.read_voltages()
    i2c_rx = voltages['i2c0_rx']
```

---

## 🧪 Testing

### VHDL Simulation Tests
```bash
# Run all tests
make sim-system

# Expected output:
# - 7+ tests PASSED
# - 0 tests FAILED
# - No CRC errors
# - Timeout detection working
```

### Python Hardware Tests
```bash
# Basic connectivity test
python3 python/examples/basic_test.py --port /dev/ttyUSB0

# SPI/I2C peripheral test
python3 python/examples/spi_i2c_test.py --port COM3
```

### Test Coverage
- ✅ Control register write operations
- ✅ Status register read operations
- ✅ CRC error detection
- ✅ Invalid address handling
- ✅ Timeout detection
- ✅ I2C transaction triggering
- ✅ SPI configuration and data transfer
- ✅ All 4 SPI modes (CPOL/CPHA combinations)

---

## 🔍 Troubleshooting

### Simulation Issues

**Problem:** Compilation errors in ModelSim
```bash
# Solution: Ensure VHDL-2002 compliance
vcom -2002 -work work ../src/uart_register_interface.vhd
```

**Problem:** Testbench timeout errors
```bash
# Solution: Increase simulation time
run 1000 ms  # Instead of default time
```

### Python Communication Issues

**Problem:** `ConnectionError: Failed to open port`
```python
# Solutions:
# 1. Check port name (Linux: /dev/ttyUSB*, Windows: COM*)
# 2. Check permissions: sudo chmod 666 /dev/ttyUSB0
# 3. Check if port is already open
```

**Problem:** CRC errors in Python
```python
# Solutions:
# 1. Verify baud rate matches (115200)
# 2. Check UART wiring (straight, not null-modem)
# 3. Ensure FPGA clock is stable
```

### FPGA Synthesis Issues

**Problem:** Timing violations
```tcl
# Solution: Reduce clock frequency or add timing constraints
create_clock -period 20.000 -name sys_clk [get_ports clk]  # 50MHz instead of 100MHz
```

**Problem:** Pin assignment errors
```tcl
# Solution: Update XDC file with correct package pins for your board
set_property PACKAGE_PIN YOUR_PIN [get_ports uart_rx]
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow VHDL-2002 standard for maximum compatibility
- Add testbench coverage for new features
- Update documentation for API changes
- Run `make sim-system` before submitting PR

---

## 📄 License

This project is licensed under the MIT License - see below for details:

```
MIT License

Copyright (c) 2025 RF Test Automation Engineering

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📧 Contact & Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/uart_template/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/uart_template/discussions)
- **Email:** rf-test-automation@example.com

---

## 🙏 Acknowledgments

- RF Test Automation Engineering Team
- FPGA community for VHDL best practices
- Open-source hardware community

---

## 📊 Project Status

| Feature | Status |
|---------|--------|
| UART Core | ✅ Complete |
| Register Interface | ✅ Complete |
| I2C Master | ✅ Complete |
| SPI Master | ✅ Complete |
| Timeout/Error Recovery | ✅ Complete |
| Python Library | ✅ Complete |
| Documentation | ✅ Complete |
| Testbenches | ✅ Complete |
| LabVIEW Integration | 🚧 In Progress |

---

**Version:** 2.0.0
**Last Updated:** 2025-11-22
**Maintained by:** RF Test Automation Engineering
