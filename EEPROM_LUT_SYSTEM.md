# EEPROM LUT Boot Loader System

**Version:** 1.0
**Date:** 2025-11-22
**Feature:** Automatic lookup table loading from I2C EEPROM on power-up

---

## Overview

The EEPROM Boot Loader system automatically loads up to 4 lookup tables (LUTs) from external I2C EEPROM on FPGA power-up. This enables:

- **Non-volatile calibration data** (ADC/DAC offsets, gain corrections)
- **Linearization/correction tables** (sensor compensation, curve fitting)
- **Temperature compensation coefficients** (thermal drift correction)
- **Waveform/pattern data** (arbitrary waveform generation, test patterns)

### Key Features

✅ **Automatic boot** - Loads on power-up (100ms delay for supply stabilization)
✅ **Manual reload** - Software trigger via UART command
✅ **4 specialized LUTs** - Each 256 entries × 32-bit (4KB total)
✅ **Dual-port RAM** - Simultaneous boot loader write + user read/write
✅ **Error detection** - Magic number validation, I2C NACK detection
✅ **Progress monitoring** - Real-time boot status via register interface
✅ **Per-LUT valid flags** - Know which LUTs loaded successfully

---

## Hardware Requirements

### I2C EEPROM
- **Recommended:** 24LC256 (32KB, I2C address 0x50)
- **Alternative:** 24LC128 (16KB), 24LC512 (64KB)
- **Interface:** I2C (100kHz or 400kHz)
- **Supply:** 2.5V - 5.5V

### Connections
```
FPGA I2C0 Master → EEPROM
  i2c0_scl → SCL (pin 6)
  i2c0_sda → SDA (pin 5)
  GND      → VSS (pin 4), A0, A1, A2 (pins 1-3)
  VCC      → VCC (pin 8), WP (pin 7)
```

**Pull-up resistors:** 4.7kΩ on SCL and SDA (required for I2C)

---

## EEPROM Memory Map

### 24LC256 (32KB) Layout

```
Address Range  | Size    | Description
---------------|---------|------------------------------------------
0x0000-0x000F  | 16 B    | Header (magic, version, size)
0x0010-0x002F  | 32 B    | LUT descriptors (4 × 8 bytes)
0x0030-0x042F  | 1024 B  | LUT0: Calibration data (256 × 32-bit)
0x0430-0x082F  | 1024 B  | LUT1: Correction table (256 × 32-bit)
0x0830-0x0C2F  | 1024 B  | LUT2: Temperature comp (256 × 32-bit)
0x0C30-0x102F  | 1024 B  | LUT3: Waveform data (256 × 32-bit)
0x1030-0x7FFF  | ~28 KB  | Reserved / user data
```

**Total LUT data:** 4096 bytes (4KB)
**Remaining space:** 28KB for expansion

---

## EEPROM Data Format

### Header (16 bytes @ 0x0000)

| Offset | Bytes | Field              | Value | Description |
|--------|-------|--------------------|-------|-------------|
| 0x00   | 4     | Magic Number       | "LFPG" | ASCII "LFPG" (0x4C465047) |
| 0x04   | 1     | Format Version     | 0x01  | Version 1 |
| 0x05   | 1     | Number of LUTs     | 1-4   | LUTs to load |
| 0x06   | 2     | Total Data Size    | bytes | Size of all LUT data |
| 0x08   | 4     | Header CRC32       | CRC   | CRC of header bytes 0-7 |
| 0x0C   | 4     | Reserved           | 0x00  | Future use |

**Example Header (4 LUTs):**
```
00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
4C 46 50 47 01 04 10 00 XX XX XX XX 00 00 00 00
^Magic "LFPG" ^V ^N ^Size    ^CRC32     ^Reserved
```

### LUT Descriptors (32 bytes @ 0x0010)

Each LUT has an 8-byte descriptor:

| Offset | Bytes | Field       | Description |
|--------|-------|-------------|-------------|
| +0     | 2     | Size        | Number of entries (0-256) |
| +2     | 1     | Entry Width | Bytes per entry (1, 2, or 4) |
| +3     | 1     | LUT Type    | 0=cal, 1=corr, 2=temp, 3=wave |
| +4     | 4     | LUT CRC32   | CRC32 of LUT data |

**Descriptor Array:**
```
0x0010-0x0017: LUT0 descriptor
0x0018-0x001F: LUT1 descriptor
0x0020-0x0027: LUT2 descriptor
0x0028-0x002F: LUT3 descriptor
```

**Example LUT0 Descriptor (256 entries × 4 bytes):**
```
01 00 04 00 XX XX XX XX
^Size ^W ^T ^CRC32
 256  4  Cal
```

### LUT Data Format

Each LUT contains 256 entries × 32-bit (1024 bytes):

```
Entry  | Address    | Format (32-bit, big-endian)
-------|------------|--------------------------------
0      | Base+0x00  | [MSB byte3 byte2 byte1 byte0 LSB]
1      | Base+0x04  | [MSB byte3 byte2 byte1 byte0 LSB]
...
255    | Base+0x3FC | [MSB byte3 byte2 byte1 byte0 LSB]
```

**Example:** Value 0x12345678 stored as:
```
Offset:  +0   +1   +2   +3
Bytes:   12   34   56   78
```

---

## LUT Types and Usage

### LUT0: Calibration Data (Type 0)
**Purpose:** ADC/DAC offset and gain corrections

**Entry Format (32-bit):**
```
[31:16] Gain (signed 16-bit, Q15 format)
[15:0]  Offset (signed 16-bit, raw counts)
```

**Example Use Case:**
```
Calibrated_Value = (ADC_Raw - LUT0[channel].offset) * LUT0[channel].gain
```

**Typical Values:**
- Offset: ±100 counts
- Gain: 1.0 ± 0.05 (0x7FFF = 1.0 in Q15)

---

### LUT1: Correction/Linearization (Type 1)
**Purpose:** Sensor linearization, polynomial correction

**Entry Format (32-bit):**
```
[31:0] Correction value (signed 32-bit, application-specific)
```

**Example Use Case:** Thermocouple linearization
```
Temperature = LUT1[ADC_Reading >> 4]  // Direct lookup
```

**Typical Values:**
- Temperature in 0.01°C units
- Range: -40.00°C to 125.00°C

---

### LUT2: Temperature Compensation (Type 2)
**Purpose:** Thermal drift compensation coefficients

**Entry Format (32-bit):**
```
[31:16] TC1 (ppm/°C, signed 16-bit)
[15:0]  TC2 (ppb/°C², signed 16-bit)
```

**Example Use Case:**
```
Compensated = Value * (1 + TC1*ΔT + TC2*ΔT²)
```

**Typical Values:**
- TC1: ±50 ppm/°C
- TC2: ±1 ppb/°C²

---

### LUT3: Waveform/Pattern Data (Type 3)
**Purpose:** Arbitrary waveform generation, test patterns

**Entry Format (32-bit):**
```
[31:0] Sample value (signed 32-bit, DAC counts)
```

**Example Use Case:** Sine wave generation
```
DAC_Output = LUT3[phase_accumulator >> 24]
```

**Typical Values:**
- Full-scale DAC range (e.g., 0 to 65535 for 16-bit DAC)
- 256-point waveform (1.4° resolution)

---

## Register Interface

### New Control/Status Registers

Added to `uart_register_interface.vhd`:

#### Register 0x30 (48): Boot Control/Status

| Bit(s) | Access | Name           | Description |
|--------|--------|----------------|-------------|
| [0]    | R/W    | BOOT_START     | Write 1 to trigger manual boot |
| [1]    | R      | BOOT_BUSY      | 1 = Boot in progress |
| [2]    | R      | BOOT_DONE      | 1 = Boot completed successfully |
| [3]    | R      | BOOT_ERROR     | 1 = Boot failed |
| [7:4]  | R      | LUT_VALID[3:0] | Per-LUT valid flags |
| [15:8] | R      | BOOT_PROGRESS  | Current boot step (0x00-0xFF) |
| [23:16]| R      | ERROR_CODE     | Error code (if BOOT_ERROR=1) |
| [63:24]| R      | Reserved       | 0x00 |

**Error Codes:**
- 0x00: No error
- 0x01: Magic number mismatch (EEPROM not programmed)
- 0x02: Version mismatch
- 0x03: I2C NACK (EEPROM not responding)
- 0x04: CRC failure
- 0x05: Timeout

**Boot Progress Values:**
- 0x00: Idle
- 0x01: Waiting for I2C stable
- 0x02: Magic number validated
- 0x03: Header read complete
- 0x10: Loading LUT0 (0x10-0x1F = progress 0-100%)
- 0x20: Loading LUT1
- 0x30: Loading LUT2
- 0x40: Loading LUT3
- 0xFF: Boot complete

---

#### Registers 0x31-0x34 (49-52): LUT Access

Each LUT has a dedicated register for access:

**Register 0x31: LUT0 Access (Calibration)**
**Register 0x32: LUT1 Access (Correction)**
**Register 0x33: LUT2 Access (Temperature)**
**Register 0x34: LUT3 Access (Waveform)**

##### Read Access

```
Write command: 0x02 [addr] [index]
  addr = 0x31-0x34 (LUT select)
  [63:56] = Reserved
  [55:48] = Reserved
  [47:40] = Reserved
  [39:32] = Reserved
  [31:24] = Reserved
  [23:16] = Reserved
  [15:8]  = Reserved
  [7:0]   = LUT index (0-255)

Response:
  [63:32] = Reserved
  [31:0]  = LUT[index] data (32-bit value)
```

##### Write Access

```
Write command: 0x01 [addr] [data]
  addr = 0x31-0x34 (LUT select)
  [63:56] = Reserved (auto-ignored)
  [55:48] = Reserved
  [47:40] = Reserved
  [39:32] = Reserved
  [31:0]  = 32-bit data to write

Note: LUT index auto-increments on write
```

---

## Programming the EEPROM

### Option 1: External Programmer (Recommended for Production)

Use a standard I2C EEPROM programmer:
1. Create binary file with correct format (see Python script below)
2. Program EEPROM with programmer
3. Install EEPROM in circuit

**Advantages:**
- Faster programming (no UART overhead)
- Reliable (dedicated hardware)
- No FPGA required

---

### Option 2: In-System Programming via UART

Program EEPROM through FPGA UART interface:

**Step 1: Write LUT data via UART**
```python
# Write LUT0 entry 0 = 0x12345678
uart_write_register(0x31, index=0, data=0x12345678)

# Write LUT0 entry 1 = 0xAABBCCDD
uart_write_register(0x31, index=1, data=0xAABBCCDD)

# ... repeat for all 256 entries
```

**Step 2: Use I2C master to write to EEPROM**
```python
# Write header (magic number "LFPG")
i2c_write(0x50, 0x0000, [0x4C, 0x46, 0x50, 0x47])

# Write version and num_luts
i2c_write(0x50, 0x0004, [0x01, 0x04])

# Write LUT0 descriptor
i2c_write(0x50, 0x0010, [0x01, 0x00, 0x04, 0x00, ...])

# Write LUT0 data (copy from LUT0 RAM)
for addr in range(256):
    data = uart_read_lut0(addr)  # Read from LUT RAM
    i2c_write_word(0x50, 0x0030 + addr*4, data)
```

**Advantages:**
- No external programmer needed
- Can update in-field
- Automated via Python script

**Disadvantages:**
- Slower (UART + I2C overhead)
- Requires working FPGA

---

## Python Programming Utility

### Generate EEPROM Binary

```python
#!/usr/bin/env python3
import struct
import zlib

def crc32(data):
    """Calculate CRC32"""
    return zlib.crc32(bytes(data)) & 0xFFFFFFFF

def pack_lut_entry(value):
    """Pack 32-bit value as big-endian"""
    return struct.pack('>I', value & 0xFFFFFFFF)

def create_eeprom_image(lut0, lut1, lut2, lut3, filename='eeprom.bin'):
    """
    Create EEPROM binary image

    Args:
        lut0-3: Lists of 256 × 32-bit integers
        filename: Output file name
    """
    image = bytearray(32768)  # 32KB (24LC256)

    # Header
    image[0:4] = b'LFPG'  # Magic number
    image[4] = 0x01  # Version
    image[5] = 0x04  # Number of LUTs
    image[6:8] = struct.pack('>H', 4096)  # Total size (4KB)

    # Calculate header CRC (bytes 0-7)
    header_crc = crc32(image[0:8])
    image[8:12] = struct.pack('>I', header_crc)

    # LUT descriptors
    descriptors = [
        (256, 4, 0),  # LUT0: 256 entries, 4 bytes, type 0 (cal)
        (256, 4, 1),  # LUT1: 256 entries, 4 bytes, type 1 (corr)
        (256, 4, 2),  # LUT2: 256 entries, 4 bytes, type 2 (temp)
        (256, 4, 3),  # LUT3: 256 entries, 4 bytes, type 3 (wave)
    ]

    luts = [lut0, lut1, lut2, lut3]
    lut_addresses = [0x0030, 0x0430, 0x0830, 0x0C30]

    for i, (size, width, lut_type) in enumerate(descriptors):
        desc_addr = 0x0010 + i * 8

        # Pack LUT data
        lut_data = bytearray()
        for value in luts[i]:
            lut_data.extend(pack_lut_entry(value))

        # Calculate LUT CRC
        lut_crc = crc32(lut_data)

        # Write descriptor
        image[desc_addr:desc_addr+2] = struct.pack('>H', size)
        image[desc_addr+2] = width
        image[desc_addr+3] = lut_type
        image[desc_addr+4:desc_addr+8] = struct.pack('>I', lut_crc)

        # Write LUT data
        image[lut_addresses[i]:lut_addresses[i]+len(lut_data)] = lut_data

    # Write to file
    with open(filename, 'wb') as f:
        f.write(image)

    print(f"EEPROM image created: {filename} ({len(image)} bytes)")
    print(f"Header CRC32: 0x{header_crc:08X}")
    for i in range(4):
        lut_data = bytearray()
        for value in luts[i]:
            lut_data.extend(pack_lut_entry(value))
        lut_crc = crc32(lut_data)
        print(f"LUT{i} CRC32: 0x{lut_crc:08X}")

# Example: Generate calibration LUTs
if __name__ == '__main__':
    # LUT0: Calibration (offset=0, gain=1.0)
    lut0 = []
    for i in range(256):
        offset = 0  # No offset
        gain = 0x7FFF  # 1.0 in Q15 format
        lut0.append((gain << 16) | (offset & 0xFFFF))

    # LUT1: Linearization (simple identity)
    lut1 = [i * 65535 // 255 for i in range(256)]

    # LUT2: Temperature compensation (no compensation)
    lut2 = [0] * 256

    # LUT3: Sine wave (256 points)
    import math
    lut3 = []
    for i in range(256):
        angle = 2 * math.pi * i / 256
        value = int(32767 * math.sin(angle)) & 0xFFFFFFFF
        lut3.append(value)

    create_eeprom_image(lut0, lut1, lut2, lut3)
```

### Program EEPROM via I2C Programmer

```bash
# Using standard EEPROM programmer
minipro -p 24C256 -w eeprom.bin

# Or using Bus Pirate
pirate_loader --dev /dev/ttyUSB0 --hex eeprom.bin
```

---

## Boot Sequence Timing

### Power-On Boot
```
Event                  | Time      | Description
-----------------------|-----------|---------------------------
FPGA configured        | T+0ms     | Bitstream loaded
Reset released         | T+1ms     | System reset deasserted
Stabilization delay    | T+1-100ms | Wait for supplies stable
I2C idle check         | T+100ms   | Wait for I2C bus idle
Read magic number      | T+101ms   | 4 bytes @ 100kHz I2C
Validate header        | T+102ms   | Check magic, version
Load LUT0 (1024 bytes) | T+102-193ms | ~90ms @ 100kHz
Load LUT1 (1024 bytes) | T+193-284ms |
Load LUT2 (1024 bytes) | T+284-375ms |
Load LUT3 (1024 bytes) | T+375-466ms |
Boot complete          | T+466ms   | All LUTs valid
```

**Total boot time: ~470ms** (at 100kHz I2C)

**With 400kHz I2C: ~160ms**

---

## Error Handling

### Boot Errors

| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 0x01 | Magic mismatch | EEPROM not programmed - program with valid data |
| 0x02 | Version mismatch | Incompatible format - reprogram with v1 format |
| 0x03 | I2C NACK | EEPROM not responding - check connections, pull-ups |
| 0x04 | CRC failure | Data corruption - reprogram EEPROM |
| 0x05 | Timeout | I2C hung - power cycle, check for bus contention |

### Handling Missing EEPROM

If EEPROM is not installed or not programmed:
- Boot will fail with error 0x01 or 0x03
- All `lutN_valid` flags remain 0
- LUT contents undefined (zeros on power-up)
- System continues operating (boot loader doesn't halt)

**Application firmware should check LUT valid flags before using LUT data!**

```vhdl
-- Example: Check before using LUT0
if lut0_valid = '1' then
    calibrated_value := raw_value + lut0_data;
else
    calibrated_value := raw_value;  -- Use uncalibrated
end if;
```

---

## Integration Example

### Top-Level Connections

```vhdl
-- Instantiate boot loader
boot_loader_inst: entity work.eeprom_boot_loader
    generic map (
        CLK_FREQ => 100_000_000,
        EEPROM_ADDR => "1010000"  -- 0x50
    )
    port map (
        clk => clk,
        rst => rst,

        -- I2C master (connect to existing i2c0)
        i2c_start => boot_i2c_start,
        i2c_addr => boot_i2c_addr,
        i2c_rw => boot_i2c_rw,
        i2c_data_out => boot_i2c_data_out,
        i2c_data_in => i2c0_data_in,
        i2c_data_valid => i2c0_data_valid,
        i2c_busy => i2c0_busy,
        i2c_ack_error => i2c0_ack_error,
        i2c_done => i2c0_done,

        -- LUT access from application
        lut0_addr => lut0_addr,
        lut0_data => lut0_data,
        lut0_we => lut0_we,
        lut0_din => lut0_din,
        -- ... lut1-3 similar

        -- Control/status (from registers)
        boot_start => boot_start_reg,
        boot_busy => boot_busy_status,
        boot_done => boot_done_status,
        boot_error => boot_error_status,
        boot_error_code => boot_error_code_status,

        lut0_valid => lut0_valid_flag,
        -- ... lut1-3 valid flags
        boot_progress => boot_progress_value
    );
```

### I2C Arbiter (if sharing I2C0 with UART commands)

```vhdl
-- Arbiter: Boot loader has priority during boot
i2c0_start <= boot_i2c_start when boot_busy_status = '1' else uart_i2c_start;
i2c0_addr <= boot_i2c_addr when boot_busy_status = '1' else uart_i2c_addr;
i2c0_rw <= boot_i2c_rw when boot_busy_status = '1' else uart_i2c_rw;
i2c0_data_out <= boot_i2c_data_out when boot_busy_status = '1' else uart_i2c_data_out;
```

---

## Testing and Validation

### 1. EEPROM Programming Test
```python
# Create test pattern
lut0_test = [0xDEADBEEF, 0xCAFEBABE, ...] # 256 entries

# Program EEPROM
create_eeprom_image(lut0_test, lut1_test, lut2_test, lut3_test)

# Write to EEPROM via programmer
# (or via UART/I2C in-system)
```

### 2. Boot Sequence Test
```python
# Power cycle FPGA
fpga_reset()
time.sleep(0.5)  # Wait for boot

# Read boot status
status = uart_read_register(0x30)
boot_done = (status >> 2) & 1
boot_error = (status >> 3) & 1
lut_valid = (status >> 4) & 0xF

print(f"Boot done: {boot_done}")
print(f"Boot error: {boot_error}")
print(f"LUT valid: 0x{lut_valid:X}")

# Should see:
# Boot done: 1
# Boot error: 0
# LUT valid: 0xF (all 4 LUTs valid)
```

### 3. LUT Read Test
```python
# Read LUT0 entry 0
data = uart_read_lut(0x31, index=0)
assert data == 0xDEADBEEF, "LUT0[0] mismatch!"

# Read LUT0 entry 1
data = uart_read_lut(0x31, index=1)
assert data == 0xCAFEBABE, "LUT0[1] mismatch!"

print("✓ LUT readback test passed")
```

### 4. Manual Reload Test
```python
# Trigger manual reload
uart_write_register(0x30, data=(1 << 0))  # Set BOOT_START

# Wait for completion
while True:
    status = uart_read_register(0x30)
    if (status >> 1) & 1 == 0:  # BOOT_BUSY cleared
        break
    time.sleep(0.01)

print("✓ Manual reload completed")
```

---

## Troubleshooting

### Issue: Boot fails with error 0x03 (I2C NACK)

**Possible Causes:**
- EEPROM not installed
- Wrong I2C address (check A0, A1, A2 pins)
- Missing pull-up resistors on SCL/SDA
- I2C bus short or contention

**Debug Steps:**
1. Check EEPROM connections with multimeter
2. Verify pull-ups present (measure ~3.3V on SCL/SDA at idle)
3. Try I2C scan: `i2c_scan()` should detect 0x50
4. Reduce I2C frequency to 100kHz (more reliable)

---

### Issue: Boot succeeds but LUT data is wrong

**Possible Causes:**
- EEPROM programmed with wrong data
- Byte order mismatch (endianness)
- CRC disabled (data corruption undetected)

**Debug Steps:**
1. Read EEPROM directly and verify magic number
2. Check CRC values match between generator and loader
3. Verify byte order (big-endian: MSB first)
4. Compare readback with golden data

---

### Issue: Boot hangs (never completes)

**Possible Causes:**
- I2C bus locked up (SDA stuck low)
- Clock stretching issue
- Wrong I2C master configuration

**Debug Steps:**
1. Monitor boot_progress register (should increment)
2. Check I2C signals with logic analyzer
3. Power cycle to reset I2C bus
4. Verify I2C master works with simple read test

---

## Performance Optimization

### Faster Boot with 400kHz I2C

```vhdl
-- Change I2C clock frequency in uart_register_interface.vhd
i2c0_inst: entity work.i2c_master
    generic map (
        CLK_FREQ => 100_000_000,
        I2C_FREQ => 400_000  -- 400kHz (was 100kHz)
    )
```

**Boot time improvement:**
- 100kHz: ~470ms
- 400kHz: ~160ms (**3× faster**)

### Partial LUT Loading

If only certain LUTs are needed:

```vhdl
-- Modify boot controller to skip unused LUTs
-- (check num_luts_buf and descriptors)
if num_luts_buf >= 1 then
    -- Load LUT0
elsif num_luts_buf >= 2 then
    -- Load LUT1
-- etc.
```

### Concurrent Loading (Advanced)

For maximum speed, load multiple bytes in parallel:
- Requires multi-master I2C or buffering
- Complexity: High
- Benefit: 4× faster (all LUTs in parallel)

---

## Summary

✅ **Automatic LUT loading from I2C EEPROM**
✅ **4 specialized LUTs (calibration, correction, temp, waveform)**
✅ **Each LUT: 256 entries × 32-bit = 1KB**
✅ **Total EEPROM usage: 4KB data + 48B header/descriptors**
✅ **Boot time: 160ms @ 400kHz I2C**
✅ **Error detection and reporting**
✅ **Manual reload capability**

**Next Steps:**
1. Integrate boot loader into `uart_register_interface.vhd`
2. Add registers 0x30-0x34 for control/status and LUT access
3. Program EEPROM with initial calibration data
4. Test auto-boot and LUT readback
5. Validate with application firmware

---

**Document Version:** 1.0
**Author:** RF Test Automation Engineering
**Date:** 2025-11-22
