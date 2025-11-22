# UART Register Interface - Future Enhancements Roadmap

## Overview

This document outlines potential future enhancements to the UART Register Interface system that were identified during codebase analysis but not yet implemented. These features are categorized by priority and complexity.

**Current Version:** 2.2.0 (TIER 1 & 2 Complete)
**Target Version:** 3.0.0 and beyond

---

## High Priority Enhancements (Version 2.3.0)

### 1. Multi-Byte I2C Transactions

**Problem:** Current implementation supports only single-byte I2C read/write operations. Many I2C devices require multi-byte bursts for efficient register access.

**Solution:**
- Extend I2C control register to specify byte count (1-8 bytes)
- Add data buffer registers for multi-byte payload
- Modify `i2c_master.vhd` state machine for burst operation
- Maintain backward compatibility with single-byte mode

**Proposed Register Design:**
```
Register 0x02 (I2C Control) - Extended format:
  [63]    I2C0 Start
  [62:56] I2C0 Address (7-bit)
  [55:52] I2C0 Byte count (0=1 byte for backward compat, 1-8 for multi-byte)
  [51]    I2C0 R/W (0=write, 1=read)
  [50]    I2C0 Repeated START mode (for write-then-read)
  [49:32] Reserved
  [31]    I2C1 Start
  [30:24] I2C1 Address (7-bit)
  [23:20] I2C1 Byte count
  [19]    I2C1 R/W
  [18]    I2C1 Repeated START mode
  [17:0]  Reserved

New Registers:
  0x22 (34): I2C0 Multi-byte Data Buffer (8 bytes packed in 64 bits)
  0x23 (35): I2C1 Multi-byte Data Buffer (8 bytes packed in 64 bits)
```

**Benefits:**
- Reduced UART overhead (1 command for 8 bytes vs 8 commands)
- Atomic multi-register operations
- Supports EEPROM page writes
- Required by many sensor devices

**Complexity:** Medium-High
**Estimated Effort:** 3-5 days
**Resource Impact:** +50 LUTs, +64 FFs (data buffers)

---

### 2. I2C Repeated START Support

**Problem:** Many I2C devices require Repeated START condition for write-then-read sequences (e.g., write register address, then read value without releasing bus).

**Solution:**
- Add Repeated START state to `i2c_master.vhd`
- Extend control register with Repeated START flag (see above)
- Support sequence: START -> ADDR+W -> DATA -> REPEATED_START -> ADDR+R -> DATA -> STOP

**Operation:**
1. User writes I2C control with Repeated START flag set
2. Master performs write phase (address + data)
3. Master issues Repeated START (SDA low while SCL high)
4. Master performs read phase
5. Master issues STOP condition

**Benefits:**
- Required by I2C specification for certain operations
- Enables atomic write-then-read
- Prevents other bus masters from interfering
- Essential for many I2C sensors and EEPROMs

**Complexity:** Medium
**Estimated Effort:** 2-3 days
**Resource Impact:** +20 LUTs, +10 FFs

---

### 3. Extended GPIO Edge Detection (Banks 2-3)

**Problem:** Current implementation monitors only 64 GPIO pins (banks 0-1). Full GPIO capacity is 256 pins.

**Solution:**
- Add registers 0x24-0x26 for banks 2-3 edge detection
- Reuse same architecture as banks 0-1
- Maintain separate status registers

**New Registers:**
```
0x24 (36): GPIO Edge Enable Banks 2-3
  [63:32] Bank 3 pin enable mask
  [31:0]  Bank 2 pin enable mask

0x25 (37): GPIO Edge Config Banks 2-3
  [63:0]  Edge type for pins 0-31 (banks 2-3)

0x26 (38): GPIO Edge Status Banks 2-3
  [63:32] Bank 3 edge detected flags
  [31:0]  Bank 2 edge detected flags
```

**Benefits:**
- Full GPIO monitoring capacity
- Consistent interface with banks 0-1

**Complexity:** Low
**Estimated Effort:** 1 day
**Resource Impact:** +80 LUTs, +128 FFs

---

## Medium Priority Enhancements (Version 2.4.0)

### 4. Multi-Word SPI Transactions

**Problem:** Current SPI implementation supports up to 32-bit words. Some SPI devices require longer transfers (48, 64, 128 bits).

**Solution:**
- Add burst mode similar to I2C multi-byte
- Support word count field in SPI config register
- Add data buffer registers for extended payloads

**Proposed Extension:**
```
Register 0x04/0x05 (SPI Config) - Extended:
  [63]    SPI Enable/Start
  [62:61] CPOL/CPHA
  [60:56] Word length (5-32 bits per word)
  [55:40] Clock divider
  [39:36] Word count (1-8 words)
  [35:32] Chip select
  [31:0]  Reserved

New Registers:
  0x27 (39): SPI0 Extended Data Buffer (64 bits)
  0x28 (40): SPI1 Extended Data Buffer (64 bits)
```

**Benefits:**
- Support for complex SPI peripherals
- Reduced UART overhead for long transfers
- Atomic multi-word operations

**Complexity:** Medium
**Estimated Effort:** 2-3 days
**Resource Impact:** +40 LUTs, +64 FFs

---

### 5. Extended Transaction History

**Problem:** Current 16-entry history may be insufficient for complex debugging scenarios.

**Solution:**
- Increase buffer depth to 32 or 64 entries
- Add configuration register for history depth
- Add filter options (e.g., only log errors)

**Extended Features:**
```
Register 0x0F (History Control) - Extended:
  [23:16] Entry count (read-only)
  [15:8]  Buffer depth config (16/32/64)
  [7:1]   Filter options:
          Bit 1: Log only errors
          Bit 2: Log only writes
          Bit 3: Log only reads
  [0]     Clear buffer
```

**Benefits:**
- Longer debug window
- Reduced noise (filter unwanted transactions)
- Configurable memory usage

**Complexity:** Low-Medium
**Estimated Effort:** 1-2 days
**Resource Impact:** +2048 FFs (for 64-entry buffer)

---

### 6. Performance Metrics Reset

**Problem:** Current performance metrics cannot be reset without hardware reset.

**Solution:**
- Add software reset command
- Add per-metric enable flags
- Add windowed statistics (last N transactions)

**Extended Register:**
```
Register 0x21 (Performance Metrics) - Extended control via 0x29:
  New Register 0x29 (41): Performance Control
    [15:8] Window size (0=all time, 1-255=last N transactions)
    [7:4]  Reserved
    [3:1]  Enable flags (min/max/avg)
    [0]    Reset statistics
```

**Benefits:**
- Targeted performance profiling
- Windowed analysis
- Clean metrics between test runs

**Complexity:** Low
**Estimated Effort:** 1 day
**Resource Impact:** +10 LUTs, +20 FFs

---

## Advanced Features (Version 3.0.0)

### 7. DMA/Streaming Mode

**Problem:** Current packet-based protocol has overhead for high-speed data streaming.

**Solution:**
- Add streaming mode with reduced protocol overhead
- Implement hardware flow control
- Support burst transfers with minimal framing

**Design:**
- New command (0x03) for streaming mode
- Continuous data flow with periodic checksums
- Automatic buffer management

**Benefits:**
- High-speed data acquisition
- Lower CPU overhead
- Suitable for ADC/DAC streaming

**Complexity:** High
**Estimated Effort:** 1-2 weeks
**Resource Impact:** +200 LUTs, +256 FFs, possible BRAM usage

---

### 8. QSPI Support

**Problem:** No Quad-SPI support for high-speed flash/RAM devices.

**Solution:**
- Extend SPI master with QSPI modes
- Add 4-bit data path
- Support QSPI commands (fast read, quad I/O)

**Benefits:**
- 4x throughput for compatible devices
- Support modern flash memories
- Faster configuration loads

**Complexity:** Medium-High
**Estimated Effort:** 1 week
**Resource Impact:** +100 LUTs, +50 FFs

---

### 9. Hardware Protocol Analyzer

**Problem:** Debugging I2C/SPI issues requires external analyzer.

**Solution:**
- Capture I2C/SPI bus activity in dedicated buffer
- Timestamp each transition
- Trigger on error conditions

**Features:**
- 256-entry capture buffer
- Configurable triggers
- Real-time analysis

**Benefits:**
- Built-in debugging
- No external equipment needed
- Captures glitches and timing issues

**Complexity:** High
**Estimated Effort:** 2 weeks
**Resource Impact:** +500 LUTs, +4K FFs (for deep buffer)

---

### 10. PWM Output Channels

**Problem:** No PWM generation capability.

**Solution:**
- Add 4-8 independent PWM channels
- Configurable frequency and duty cycle
- Phase alignment options

**Register Design:**
```
New Registers 0x2A-0x2D (42-45): PWM Channel Configuration
  Each register controls 2 channels:
  [63:48] Channel N+1 duty cycle (16-bit)
  [47:32] Channel N+1 period
  [31:16] Channel N duty cycle
  [15:0]  Channel N period
```

**Benefits:**
- Motor control
- LED dimming
- Analog signal generation

**Complexity:** Medium
**Estimated Effort:** 3-5 days
**Resource Impact:** +150 LUTs, +200 FFs

---

## Implementation Priority Matrix

| Feature | Priority | Complexity | Impact | Version |
|---------|----------|------------|--------|---------|
| Multi-byte I2C | HIGH | Medium-High | HIGH | 2.3.0 |
| I2C Repeated START | HIGH | Medium | HIGH | 2.3.0 |
| Extended GPIO Edge (Banks 2-3) | HIGH | Low | Medium | 2.3.0 |
| Multi-word SPI | MEDIUM | Medium | Medium | 2.4.0 |
| Extended History | MEDIUM | Low-Medium | Low | 2.4.0 |
| Performance Reset | MEDIUM | Low | Low | 2.4.0 |
| DMA/Streaming | LOW | High | HIGH | 3.0.0 |
| QSPI Support | LOW | Medium-High | Medium | 3.0.0 |
| Protocol Analyzer | LOW | High | Medium | 3.0.0 |
| PWM Channels | LOW | Medium | Medium | 3.0.0 |

---

## Unused Register Address Space

### Control Registers
- **0x10-0x1F:** Not usable (conflicts with status registers)
- **Available for future use:** Limited in control register space

### Status Registers
- **0x22-0xFF:** Available (222 registers)
- Plenty of space for new features

### Recommendations
- Use status register space for read-only features
- Consider packing multiple configurations into single control register
- Reserve 0x22-0x2F for near-term enhancements
- Reserve 0x30-0x3F for advanced features (DMA, analyzer, etc.)
- Keep 0x40+ for future expansion

---

## Backward Compatibility Strategy

**Requirements:**
1. All new features must use previously unused registers
2. Existing register behavior must not change
3. Default values must maintain current behavior
4. Protocol commands must remain compatible

**Testing:**
1. Regression test suite for all TIER 1 & 2 features
2. Legacy software must work unchanged
3. New software detects capabilities via version register

**Migration Path:**
1. Document all register changes
2. Provide software library updates
3. Maintain old and new API in parallel for 2 versions
4. Clear deprecation warnings

---

## Resource Budget Planning

### Current Usage (v2.2.0)
- LUTs: ~750
- Flip-Flops: ~1750
- BRAM: 0

### Artix-7 100T Capacity
- LUTs: 63,400 (1.2% used)
- Flip-Flops: 126,800 (1.4% used)
- BRAM: 135 (0% used)

### Headroom Available
- Plenty of room for all planned features
- Can implement all TIER 3 features without resource constraints
- Consider using BRAM for very deep buffers (protocol analyzer, extended history)

---

## Next Steps

1. **Community Feedback:** Gather input on feature priorities
2. **Proof of Concept:** Prototype multi-byte I2C on development branch
3. **Specification:** Write detailed specs for v2.3.0 features
4. **Test Plan:** Define comprehensive test coverage for new features
5. **Schedule:** Allocate development time based on priorities

---

**Document Version:** 1.0
**Date:** 2025-11-22
**Author:** RF Test Automation Engineering

---

## Appendix: Analysis Methodology

This roadmap was created through:
1. Systematic codebase analysis
2. Identification of current limitations
3. Review of TODO comments in source code
4. Examination of unused register address space
5. Consideration of common use cases
6. Resource availability assessment

**Key Findings:**
- **Protocol Gaps:** I2C multi-byte and Repeated START are most critical
- **Unused Resources:** Significant headroom for enhancement
- **Register Space:** Ample address space for future features
- **Backward Compatibility:** All enhancements can be non-breaking

**Recommendation:**
Focus on v2.3.0 high-priority features first (multi-byte I2C, Repeated START, extended GPIO). These provide maximum benefit with acceptable complexity and maintain the system's professional-grade quality.
