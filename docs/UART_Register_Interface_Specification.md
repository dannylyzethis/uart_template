# UART Register Interface Specification
## RF Test Automation System

**Document Version:** 1.0  
**Date:** August 17, 2025  
**Author:** RF Test Automation Engineering  

---

## Table of Contents
1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Protocol Specification](#protocol-specification)
4. [Register Map](#register-map)
5. [Interface Specifications](#interface-specifications)
6. [Error Handling](#error-handling)
7. [Timing Requirements](#timing-requirements)
8. [Integration Guide](#integration-guide)
9. [Testing and Validation](#testing-and-validation)
10. [Appendices](#appendices)

---

## 1. Overview

### 1.1 Purpose
The UART Register Interface provides a robust, high-speed communication channel between LabVIEW test automation systems and FPGA-based RF test equipment. The interface enables real-time control of coaxial switches, voltage regulators, current monitors, I2C devices, and SPI peripherals.

### 1.2 Key Features
- **64-bit register architecture** for efficient data transfer
- **CRC-8 error detection** for reliable communication
- **Register-based commands** (no text parsing overhead)
- **Dual clock domain synchronization** for robust UART operation
- **I2C and SPI controller integration** for peripheral management
- **Configurable SPI parameters** (CPOL, CPHA, word length, clock divider)
- **Consistent addressing scheme** across all control modules

### 1.3 Applications
- RF component characterization
- Production test automation
- Antenna measurement systems
- Signal integrity testing
- Multi-DUT test environments

---

## 2. System Architecture

### 2.1 Block Diagram
```
┌─────────────┐    UART     ┌─────────────────────┐    Control    ┌─────────────┐
│   LabVIEW   │◄──────────►│  UART Register      │◄─────────────►│   RF Test   │
│ Test System │  115200bps  │     Interface       │   Signals     │  Hardware   │
└─────────────┘             │                     │               └─────────────┘
                            │  ┌───────────────┐  │
                            │  │ Control Regs  │  │               ┌─────────────┐
                            │  │   0x00-0x09   │  │    I2C0/1     │   External  │
                            │  └───────────────┘  │◄─────────────►│ I2C Devices │
                            │  ┌───────────────┐  │               └─────────────┘
                            │  │ Status Regs   │  │
                            │  │   0x10-0x19   │  │               ┌─────────────┐
                            │  └───────────────┘  │    SPI0/1     │   External  │
                            │                     │◄─────────────►│ SPI Devices │
                            │                     │               └─────────────┘
                            │                     │               ┌─────────────┐
                            │                     │   GPIO 0-3    │   External  │
                            │                     │◄─────────────►│GPIO Devices │
                            └─────────────────────┘               └─────────────┘
```

### 2.2 Core Components
- **UART Controller:** 115200 baud, 8N1 configuration
- **Register Bank:** 10 control + 10 status registers (64-bit each)
- **CRC Engine:** CRC-8 polynomial (0x07) for error detection
- **I2C Masters:** Dual I2C controllers for sensor communication
- **SPI Masters:** Dual SPI controllers with configurable parameters
- **GPIO Interface:** 4 output banks + 4 input banks (256 bits each direction)
- **Clock Domain Crossing:** Three-FF synchronizer for UART RX

---

## 3. Protocol Specification

### 3.1 Command Packet Format
All commands follow a 12-byte packet structure:

| Byte | Field | Description |
|------|-------|-------------|
| 0 | DEV_ADDR | Device address (0x00-0xFE specific, 0xFF broadcast) |
| 1 | CMD | Command type (0x01=Write, 0x02=Read) |
| 2 | ADDR | Register address |
| 3-10 | DATA | 64-bit data (big-endian) |
| 11 | CRC | CRC-8 checksum of bytes 0-10 |

**Device Addressing:**
- Each FPGA can be configured with a unique device address (0x00-0xFE)
- Address 0xFF is broadcast - all devices respond
- Devices ignore packets not addressed to them
- Enables multiple FPGAs on single UART bus (multi-drop)

### 3.2 Response Packet Format
Read responses follow a 10-byte structure:

| Byte | Field | Description |
|------|-------|-------------|
| 0 | HDR | Response header (0x02) |
| 1-8 | DATA | 64-bit data (big-endian) |
| 9 | CRC | CRC-8 checksum of bytes 0-8 |

### 3.3 CRC-8 Calculation
**Polynomial:** 0x07 (x^8 + x^2 + x + 1)  
**Initial Value:** 0x00  
**Implementation:**
```vhdl
function crc8_update(crc_in: std_logic_vector(7 downto 0); 
                    data_in: std_logic_vector(7 downto 0)) 
                    return std_logic_vector is
    variable crc_out : std_logic_vector(7 downto 0);
    variable temp    : std_logic_vector(7 downto 0);
begin
    temp := crc_in xor data_in;
    crc_out := temp(6 downto 0) & '0';
    if temp(7) = '1' then
        crc_out := crc_out xor x"07";
    end if;
    return crc_out;
end function;
```

---

## 4. Register Map

### 4.1 Control Registers (Write Operations)

#### Register 0x00: System Control
| Bits | Field | Description |
|------|-------|-------------|
| 63:32 | Reserved | Future expansion |
| 31:16 | Reserved | Future expansion |
| 15:8 | Reserved | Future expansion |
| 7:0 | SYSCTRL | System control bits |

**SYSCTRL Bit Definitions:**
- Bit 0: System reset
- Bit 1: Global enable
- Bits 7:2: Reserved

#### Register 0x01: Switch Control
| Bits | Field | Description |
|------|-------|-------------|
| 63:48 | SW_BANK3 | Switch bank 3 positions |
| 47:32 | SW_BANK2 | Switch bank 2 positions |
| 31:16 | SW_BANK1 | Switch bank 1 positions |
| 15:0 | SW_BANK0 | Switch bank 0 positions |

#### Register 0x02: I2C Control & Data
| Bits | Field | Description |
|------|-------|-------------|
| 63 | I2C0_START | I2C0 transaction trigger |
| 62:56 | I2C0_ADDR | I2C0 device address (7-bit) |
| 55:48 | Reserved | Future expansion |
| 47:32 | Reserved | Future expansion |
| 31 | I2C1_START | I2C1 transaction trigger |
| 30:24 | I2C1_ADDR | I2C1 device address (7-bit) |
| 23:16 | Reserved | Future expansion |
| 15:8 | I2C0_DATA | I2C0 data byte |
| 7:0 | I2C1_DATA | I2C1 data byte |

#### Register 0x03: SPI Data
| Bits | Field | Description |
|------|-------|-------------|
| 63:32 | SPI0_DATA | SPI0 32-bit transmit data |
| 31:0 | SPI1_DATA | SPI1 32-bit transmit data |

#### Register 0x04: SPI0 Configuration
| Bits | Field | Description |
|------|-------|-------------|
| 63 | SPI0_EN | SPI0 enable/start transaction |
| 62 | CPOL | Clock polarity (0=idle low, 1=idle high) |
| 61 | CPHA | Clock phase (0=leading edge, 1=trailing edge) |
| 60:56 | WORD_LEN | Word length (5-32 bits, value+1) |
| 55:40 | CLK_DIV | Clock divider value |
| 39:36 | Reserved | Future expansion |
| 35:32 | CHIP_SEL | Chip select (4-bit one-hot) |
| 31:0 | Reserved | Future expansion |

#### Register 0x05: SPI1 Configuration
| Bits | Field | Description |
|------|-------|-------------|
| 63 | SPI1_EN | SPI1 enable/start transaction |
| 62 | CPOL | Clock polarity (0=idle low, 1=idle high) |
| 61 | CPHA | Clock phase (0=leading edge, 1=trailing edge) |
| 60:56 | WORD_LEN | Word length (5-32 bits, value+1) |
| 55:40 | CLK_DIV | Clock divider value |
| 39:36 | Reserved | Future expansion |
| 35:32 | CHIP_SEL | Chip select (4-bit one-hot) |
| 31:0 | Reserved | Future expansion |

#### Register 0x06: GPIO Output Bank 0
| Bits | Field | Description |
|------|-------|-------------|
| 63:0 | GPIO_OUT0 | 64-bit GPIO output bank 0 |

**Description:** General-purpose output register. Each bit drives a physical GPIO pin or can be used for custom logic control. Write operations generate a strobe signal for synchronization.

#### Register 0x07: GPIO Output Bank 1
| Bits | Field | Description |
|------|-------|-------------|
| 63:0 | GPIO_OUT1 | 64-bit GPIO output bank 1 |

**Description:** General-purpose output register for additional GPIO pins or control signals.

#### Register 0x08: GPIO Output Bank 2
| Bits | Field | Description |
|------|-------|-------------|
| 63:0 | GPIO_OUT2 | 64-bit GPIO output bank 2 |

**Description:** General-purpose output register for additional GPIO pins or control signals.

#### Register 0x09: GPIO Output Bank 3
| Bits | Field | Description |
|------|-------|-------------|
| 63:0 | GPIO_OUT3 | 64-bit GPIO output bank 3 |

**Description:** General-purpose output register for additional GPIO pins or control signals.

**Total GPIO Outputs:** 256 bits (4 banks × 64 bits)

### 4.2 Status Registers (Read Operations)

#### Register 0x10: System Status
| Bits | Field | Description |
|------|-------|-------------|
| 63:32 | TIMESTAMP | Seconds since reset |
| 31:24 | BUS_STATUS | I2C/SPI busy flags |
| 23:16 | ERROR_FLAGS | I2C/SPI error flags |
| 15:8 | TEMP | Temperature (°C) |
| 7:0 | SYS_STATUS | System status bits |

#### Register 0x11: Current Measurements
| Bits | Field | Description |
|------|-------|-------------|
| 63:48 | CURR_MON3 | Current monitor 3 (µA) |
| 47:32 | CURR_MON2 | Current monitor 2 (µA) |
| 31:16 | CURR_MON1 | Current monitor 1 (µA) |
| 15:0 | CURR_MON0 | Current monitor 0 (µA) |

#### Register 0x12: Voltage Measurements & I2C Data
| Bits | Field | Description |
|------|-------|-------------|
| 63:48 | VOLT_MON1 | Voltage monitor 1 (mV) |
| 47:32 | VOLT_MON0 | Voltage monitor 0 (mV) |
| 31:16 | I2C0_RX | I2C0 received data |
| 15:0 | I2C1_RX | I2C1 received data |

#### Register 0x13: SPI Received Data
| Bits | Field | Description |
|------|-------|-------------|
| 63:32 | SPI0_RX | SPI0 last received data |
| 31:0 | SPI1_RX | SPI1 last received data |

#### Register 0x14: Switch Position Readback
| Bits | Field | Description |
|------|-------|-------------|
| 63:48 | SW_RB3 | Switch bank 3 actual positions |
| 47:32 | SW_RB2 | Switch bank 2 actual positions |
| 31:16 | SW_RB1 | Switch bank 1 actual positions |
| 15:0 | SW_RB0 | Switch bank 0 actual positions |

#### Register 0x15: Counters & Performance
| Bits | Field | Description |
|------|-------|-------------|
| 63:48 | SPI_COUNTERS | SPI transaction counters |
| 47:32 | I2C_COUNTERS | I2C transaction counters |
| 31:16 | TEST_COUNTER | Test completion counter |
| 15:0 | ERROR_COUNTER | Error counter |

#### Register 0x16: GPIO Input Bank 0
| Bits | Field | Description |
|------|-------|-------------|
| 63:0 | GPIO_IN0 | 64-bit GPIO input bank 0 |

**Description:** General-purpose input register. Reads the current state of 64 GPIO input pins or status signals. Updated in real-time with external pin states.

#### Register 0x17: GPIO Input Bank 1
| Bits | Field | Description |
|------|-------|-------------|
| 63:0 | GPIO_IN1 | 64-bit GPIO input bank 1 |

**Description:** General-purpose input register for additional GPIO pins or status signals.

#### Register 0x18: GPIO Input Bank 2
| Bits | Field | Description |
|------|-------|-------------|
| 63:0 | GPIO_IN2 | 64-bit GPIO input bank 2 |

**Description:** General-purpose input register for additional GPIO pins or status signals.

#### Register 0x19: GPIO Input Bank 3
| Bits | Field | Description |
|------|-------|-------------|
| 63:0 | GPIO_IN3 | 64-bit GPIO input bank 3 |

**Description:** General-purpose input register for additional GPIO pins or status signals.

**Total GPIO Inputs:** 256 bits (4 banks × 64 bits)

---

## 5. Interface Specifications

### 5.1 UART Interface
- **Baud Rate:** 115,200 bps
- **Data Format:** 8 data bits, no parity, 1 stop bit (8N1)
- **Flow Control:** None
- **Voltage Levels:** 3.3V CMOS logic levels
- **Connector:** Standard DB9 or USB-to-serial adapter

### 5.2 I2C Interface
- **Speed:** Standard mode (100 kHz) or Fast mode (400 kHz)
- **Voltage Levels:** 3.3V with pull-up resistors
- **Address Format:** 7-bit addressing
- **Multi-master:** Not supported (FPGA is master only)

### 5.3 SPI Interface
- **Clock Frequency:** Configurable via clock divider (1 MHz to 50 MHz)
- **Data Width:** 5 to 32 bits (configurable)
- **Clock Modes:** All four SPI modes supported (CPOL/CPHA)
- **Chip Select:** 4 independent CS signals per SPI controller
- **Voltage Levels:** 3.3V CMOS logic levels

### 5.4 GPIO Interface
- **Output Banks:** 4 banks × 64 bits = 256 GPIO outputs
- **Input Banks:** 4 banks × 64 bits = 256 GPIO inputs
- **Voltage Levels:** 3.3V CMOS logic levels
- **Update Rate:** Real-time with register write/read operations
- **Strobe Signals:** Write and read strobe signals provided for synchronization
- **Applications:** Custom control signals, status monitoring, test point access
- **Pin Assignment:** User-defined based on FPGA constraints file

---

## 6. Error Handling

### 6.1 CRC Errors
- **Detection:** Automatic CRC validation on all received packets
- **Response:** CRC error flag set, packet discarded
- **Recovery:** Host retransmits command

### 6.2 Invalid Address Errors
- **Detection:** Address validation during command processing
- **Response:** Command error flag set, no register operation
- **Valid Ranges:** 0x00-0x09 (control), 0x10-0x19 (status)

### 6.3 Communication Timeouts
- **UART:** No built-in timeout (handled by host application)
- **I2C:** ACK error detection and reporting
- **SPI:** Transaction completion monitoring

---

## 7. Timing Requirements

### 7.1 UART Timing
- **Bit Period:** 8.68 µs (115,200 baud)
- **Command Processing:** < 10 µs after packet reception
- **Response Delay:** < 50 µs for read operations

### 7.2 I2C Timing
- **Start Pulse:** Single clock cycle
- **Transaction Time:** 100-500 µs (depending on data length)
- **ACK Timeout:** 1 ms maximum

### 7.3 SPI Timing
- **Start Pulse:** Single clock cycle
- **Transaction Time:** Dependent on clock frequency and word length
- **CS Setup/Hold:** 1 clock cycle minimum

---

## 8. Integration Guide

### 8.1 LabVIEW Integration
1. **Configure Serial Port:** 115200 baud, 8N1, no flow control
2. **Implement Packet Builder:** Create command packets with CRC
3. **Add Error Handling:** Check CRC and command error flags
4. **Create Register Wrappers:** High-level VIs for each register

### 8.2 Example LabVIEW Code Structure
```
RegisterInterface.lvlib
├── Write_Control_Register.vi
├── Read_Status_Register.vi
├── Calculate_CRC8.vi
├── Set_Switch_Positions.vi
├── Configure_SPI.vi
├── Send_I2C_Command.vi
└── Error_Handler.vi
```

### 8.3 Hardware Connections
- **UART:** Connect RX/TX to FPGA UART pins
- **Power:** Ensure proper 3.3V supply to FPGA
- **Ground:** Common ground between host and FPGA
- **Clock:** External crystal or oscillator for FPGA

---

## 9. Testing and Validation

### 9.1 Unit Tests
- **CRC Calculation:** Verify CRC-8 implementation
- **Register Operations:** Test all read/write operations
- **Error Detection:** Validate error handling mechanisms

### 9.2 Integration Tests
- **LabVIEW Communication:** Full packet exchange testing
- **I2C/SPI Operations:** Peripheral device communication
- **Stress Testing:** Continuous operation validation

### 9.3 Validation Checklist
- [ ] All registers accessible via UART commands
- [ ] CRC error detection functional
- [ ] I2C transactions complete successfully
- [ ] SPI configuration parameters applied correctly
- [ ] Error flags operate as specified
- [ ] Timing requirements met
- [ ] LabVIEW integration successful

---

## 10. Appendices

### Appendix A: Command Examples

#### Write Control Register 0 (Device Address 0x00)
```
Command: 0x00 0x01 0x00 0x12 0x34 0x56 0x78 0x9A 0xBC 0xDE 0xF0 0xXX
Breakdown:
  DEV_ADDR: 0x00 (device 0)
  CMD:      0x01 (write)
  ADDR:     0x00 (control register 0)
  DATA:     0x123456789ABCDEF0 (64-bit big-endian)
  CRC:      Calculated from all previous bytes
Description: Write 0x123456789ABCDEF0 to control register 0 on device 0
```

#### Read Status Register 0 (Broadcast to All Devices)
```
Command: 0xFF 0x02 0x10 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0xXX
Breakdown:
  DEV_ADDR: 0xFF (broadcast - all devices respond)
  CMD:      0x02 (read)
  ADDR:     0x10 (status register 0)
  DATA:     0x0000000000000000 (dummy data)
  CRC:      Calculated from all previous bytes

Response: 0x02 0x01 0x23 0x45 0x67 0x89 0xAB 0xCD 0xEF 0xXX
Breakdown:
  HDR:  0x02 (response header)
  DATA: 0x0123456789ABCDEF (64-bit status value)
  CRC:  Calculated from header + data
Description: Read status register 0 from all devices
```

#### Set GPIO Output Bank 0
```
Command: 0x00 0x01 0x06 0xDE 0xAD 0xBE 0xEF 0xCA 0xFE 0xBA 0xBE 0xXX
Breakdown:
  DEV_ADDR: 0x00 (device 0)
  CMD:      0x01 (write)
  ADDR:     0x06 (GPIO output bank 0)
  DATA:     0xDEADBEEFCAFEBABE (64-bit GPIO pattern)
  CRC:      Calculated from all previous bytes
Description: Set GPIO output bank 0 to pattern 0xDEADBEEFCAFEBABE
```

#### Read GPIO Input Bank 0
```
Command: 0x00 0x02 0x16 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0xXX
Breakdown:
  DEV_ADDR: 0x00 (device 0)
  CMD:      0x02 (read)
  ADDR:     0x16 (GPIO input bank 0)
  DATA:     0x0000000000000000 (dummy data)
  CRC:      Calculated from all previous bytes

Response: 0x02 0x12 0x34 0x56 0x78 0x9A 0xBC 0xDE 0xF0 0xXX
Breakdown:
  HDR:  0x02 (response header)
  DATA: 0x123456789ABCDEF0 (64-bit GPIO input state)
  CRC:  Calculated from header + data
Description: Read current state of GPIO input bank 0
```

### Appendix B: SPI Configuration Examples

#### SPI Mode 0 (CPOL=0, CPHA=0), 16-bit, 1MHz
```
Register 0x04 Value: 0x8F00640100000000
Breakdown:
- Bit 63: Enable = 1
- Bit 62: CPOL = 0
- Bit 61: CPHA = 0
- Bits 60:56: Word Length = 15 (16 bits)
- Bits 55:40: Clock Divider = 100 (100MHz/100 = 1MHz)
- Bits 35:32: Chip Select = 0001
```

### Appendix C: Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Aug 17, 2025 | Initial specification release |

---

**End of Document**

*For technical support or questions regarding this specification, contact the RF Test Automation Engineering team.*