# Quick Start Guide

Get up and running with the UART Register Interface in 10 minutes!

## 🎯 Goal

By the end of this guide, you will:
- ✅ Simulate the design in ModelSim
- ✅ Understand the basic register operations
- ✅ Run Python examples on real hardware (optional)

---

## 📋 Prerequisites

### Required
- ModelSim/QuestaSim (for simulation)
- Python 3.7+ (for host control)
- Git

### Optional
- FPGA board with UART (for hardware testing)
- Xilinx Vivado or Intel Quartus (for synthesis)

---

## 🚀 Step 1: Clone and Setup (2 minutes)

```bash
# Clone the repository
git clone https://github.com/yourusername/uart_template.git
cd uart_template

# Install Python dependencies
pip install -r python/requirements.txt
```

---

## 🔬 Step 2: Run Simulation (3 minutes)

### Option A: Using Makefile (Recommended)

```bash
# Compile all sources and run comprehensive test
make sim-system
```

### Option B: Manual ModelSim

```bash
cd simulation

# Launch ModelSim
vsim

# In ModelSim console:
do compile_all.do
do run_system_test.do
```

### Expected Output

You should see in the transcript:
```
========================================
  UART Register Interface System Test
========================================

Test 1: Writing to all control registers
  ✓ Write successful

Test 2: Reading all status registers
  ...

========================================
  Test Summary:
  Passed: 7
  Failed: 0
========================================
```

---

## 📊 Step 3: Explore the Waveform (2 minutes)

In ModelSim, observe these key signals:

### Test Progress
- `test_phase` - Current test name
- `test_pass_count` - Number of passed tests

### UART Communication
- `uart_rx` - UART receive (command from host)
- `uart_tx` - UART transmit (response to host)

### Register Updates
- `ctrl_reg0`-`ctrl_reg5` - Control register values
- `status_reg0`-`status_reg5` - Status register values

### Peripherals
- `i2c0_start`, `i2c0_busy` - I2C transaction status
- `spi0_start`, `spi0_busy` - SPI transaction status

### Error Flags
- `crc_error` - CRC validation failure
- `cmd_error` - Invalid command
- `timeout_error` - Incomplete packet timeout

---

## 🐍 Step 4: Python Examples (3 minutes)

### Update Port Settings

Edit `python/examples/basic_test.py`:
```python
# Linux
port = '/dev/ttyUSB0'

# Windows
port = 'COM3'

# macOS
port = '/dev/cu.usbserial-*'
```

### Check Permissions (Linux only)

```bash
# Add yourself to dialout group
sudo usermod -a -G dialout $USER

# Or temporarily change permissions
sudo chmod 666 /dev/ttyUSB0
```

### Run Basic Test

```bash
python3 python/examples/basic_test.py --port /dev/ttyUSB0
```

### Expected Output

```
==============================================================
  UART Register Interface - Basic Test
==============================================================

Test 1: Write Control Register 0
  Writing: 0x123456789ABCDEF0
  ✓ Write successful

Test 2: Set Switch Positions
  ✓ Switches configured

Test 3: Read All Status Registers
  Reg 0x10: 0x0000000100000001
  Reg 0x11: 0x1111222233334444
  ...

==============================================================
  Communication Statistics
==============================================================
  Commands sent:      12
  Responses received: 6
  CRC errors:         0
  Timeouts:           0
  Success rate:       100.0%

✓ Test completed successfully!
```

---

## 🎓 Understanding the Basics

### Command Packet Format

Every command is 11 bytes:
```
[CMD][ADDR][DATA0-7][CRC]
 1    1      8       1
```

Example - Write 0x123456789ABCDEF0 to register 0x00:
```python
cmd = 0x01                    # Write command
addr = 0x00                   # Register 0
data = 0x123456789ABCDEF0     # 64-bit value
crc = calculate_crc(...)      # CRC-8

# Python library handles this automatically!
uart.write_register(0x00, 0x123456789ABCDEF0)
```

### Response Packet Format

Read responses are 10 bytes:
```
[HDR][DATA0-7][CRC]
 1     8       1
```

Example - Read from register 0x10:
```python
# Send read command
value = uart.read_register(0x10)
print(f"Value: 0x{value:016X}")
```

---

## 🔧 Common Operations

### Write Control Register

```python
from uart_register_interface import UARTRegisterInterface

with UARTRegisterInterface(port='/dev/ttyUSB0') as uart:
    # Write to system control
    uart.write_register(0x00, 0x0000000000000003)
```

### Read Status Register

```python
with UARTRegisterInterface(port='/dev/ttyUSB0') as uart:
    # Read system status
    value = uart.read_register(0x10)

    # Or use helper method
    status = uart.read_system_status()
    print(status)
```

### Configure SPI

```python
with UARTRegisterInterface(port='/dev/ttyUSB0') as uart:
    uart.configure_spi(
        channel=0,
        cpol=False,      # Clock idle low
        cpha=False,      # Sample on leading edge
        word_len=16,     # 16-bit transfers
        clk_div=100,     # 1MHz at 100MHz system clock
        chip_select=0    # Use CS0
    )

    # Send data
    uart.write_spi(channel=0, data=0xDEADBEEF)
```

### I2C Transaction

```python
with UARTRegisterInterface(port='/dev/ttyUSB0') as uart:
    # Write to I2C device at address 0x50
    uart.write_i2c(channel=0, device_addr=0x50, data=0xAA)

    # Wait for transaction
    time.sleep(0.1)

    # Read received data
    voltages = uart.read_voltages()
    print(f"I2C RX: 0x{voltages['i2c0_rx']:04X}")
```

---

## 📚 Next Steps

Now that you're up and running:

1. **Read the Full Specification**
   - [UART_Register_Interface_Specification.md](UART_Register_Interface_Specification.md)
   - Detailed register descriptions
   - Protocol details

2. **Explore Examples**
   - `python/examples/basic_test.py` - Basic operations
   - `python/examples/spi_i2c_test.py` - Peripheral control

3. **Synthesize for Your FPGA**
   - Update `constraints/uart_register_interface.xdc` with your pin assignments
   - Load into Vivado or Quartus
   - Generate bitstream

4. **Integrate into Your System**
   - Connect status inputs to your sensors
   - Use control outputs to drive your hardware
   - Build application-specific wrappers

---

## ❓ Troubleshooting

### Simulation doesn't run

**Problem:** `Error: Cannot open work library`

**Solution:**
```bash
cd simulation
vlib work
vcom -2002 -work work ../src/*.vhd
```

### Python can't find serial port

**Problem:** `serial.serialutil.SerialException: could not open port`

**Solutions:**
1. Check port exists: `ls /dev/ttyUSB*` (Linux) or Device Manager (Windows)
2. Check permissions: `sudo chmod 666 /dev/ttyUSB0`
3. Verify not already open: Close other serial terminal programs

### CRC errors in communication

**Problem:** Frequent CRC errors

**Solutions:**
1. Check baud rate matches (115200)
2. Verify UART wiring (TX→RX, RX→TX)
3. Ensure stable FPGA clock
4. Try shorter cable

---

## 💡 Tips

1. **Start with simulation** before hardware to understand the protocol
2. **Use the Python library** - don't write raw UART commands
3. **Check statistics** - `uart.get_statistics()` shows communication health
4. **Enable logging** in Python for debugging:
   ```python
   import logging
   logging.basicConfig(level=logging.DEBUG)
   ```

---

## 🎉 Success!

You've successfully:
- ✅ Compiled and simulated the design
- ✅ Understood the register interface protocol
- ✅ Ran Python examples
- ✅ Learned basic operations

**Ready for more?** Check out the [Full Documentation](../README.md)!

---

**Questions?** Open an issue on [GitHub](https://github.com/yourusername/uart_template/issues)

**Happy coding!** 🚀
