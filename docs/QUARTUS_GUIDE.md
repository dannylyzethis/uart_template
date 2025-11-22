# Quartus Setup Guide for Intel/Altera FPGAs

Quick guide for synthesizing the UART Register Interface on Intel/Altera FPGAs using Quartus Prime.

---

## 📋 Prerequisites

- **Intel Quartus Prime** (Lite, Standard, or Pro)
  Tested with Quartus Prime 18.1+
- **ModelSim** (optional, for simulation)
- **Target FPGA Board** (Cyclone V, MAX 10, etc.)

---

## 🚀 Quick Start (3 Methods)

### Method 1: Automated Project Creation (Recommended)

```bash
cd scripts
quartus_sh -t create_quartus_project.tcl
```

This creates a complete Quartus project with:
- All source files added
- Constraints applied
- Compilation settings optimized

Then open the project:
```bash
quartus uart_register_interface.qpf
```

### Method 2: Manual Project Creation

1. **Launch Quartus Prime**
   ```
   File → New Project Wizard
   ```

2. **Project Settings**
   - Name: `uart_register_interface`
   - Top-level: `uart_register_interface`
   - Device: Select your FPGA (e.g., `5CSEMA5F31C6` for Cyclone V)

3. **Add Source Files**
   ```
   Project → Add/Remove Files in Project
   ```

   Add files in this order:
   - `src/uart_core.vhd`
   - `src/i2c_master.vhd`
   - `src/spi_master.vhd`
   - `src/uart_register_interface.vhd`

4. **Add Constraints**
   ```
   Assignments → Settings → Constraints
   ```

   Add files:
   - `constraints/uart_register_interface.qsf` (Pin assignments)
   - `constraints/uart_register_interface.sdc` (Timing constraints)

5. **Set VHDL Version**
   ```
   Assignments → Settings → Compiler Settings
   ```
   - VHDL Input Version: **VHDL 2008**

### Method 3: Command Line

```bash
# Create project
quartus_sh --tcl_eval project_new uart_register_interface

# Add files
quartus_sh --tcl_eval set_global_assignment -name VHDL_FILE src/uart_core.vhd
quartus_sh --tcl_eval set_global_assignment -name VHDL_FILE src/i2c_master.vhd
quartus_sh --tcl_eval set_global_assignment -name VHDL_FILE src/spi_master.vhd
quartus_sh --tcl_eval set_global_assignment -name VHDL_FILE src/uart_register_interface.vhd

# Compile
quartus_sh --flow compile uart_register_interface
```

---

## 🔧 Pin Assignment Configuration

### CRITICAL: Update for Your Board

The constraint file `constraints/uart_register_interface.qsf` contains example pin assignments for Cyclone V. **You MUST update these for your specific board.**

### Finding Pin Assignments

1. **Open Pin Planner**
   ```
   Assignments → Pin Planner
   ```

2. **Refer to Board Documentation**
   - DE10-Nano: See DE10-Nano User Manual
   - DE10-Standard: See DE10-Standard User Manual
   - DE1-SoC: See DE1-SoC User Manual
   - Custom Board: Check schematic

3. **Update .qsf File**

   Edit `constraints/uart_register_interface.qsf`:

   ```tcl
   # Example for your board:
   set_location_assignment PIN_YOUR_PIN -to clk
   set_location_assignment PIN_YOUR_PIN -to uart_rx
   set_location_assignment PIN_YOUR_PIN -to uart_tx
   # ... etc
   ```

### Common DE-Series Boards

#### DE10-Nano (Cyclone V SoC)
```tcl
# System Clock (50 MHz)
set_location_assignment PIN_V11 -to clk

# UART (Arduino Header)
set_location_assignment PIN_AH9 -to uart_rx
set_location_assignment PIN_AG11 -to uart_tx
```

#### DE10-Standard (Cyclone V)
```tcl
# System Clock (50 MHz)
set_location_assignment PIN_AF14 -to clk

# UART (GPIO)
set_location_assignment PIN_AG16 -to uart_rx
set_location_assignment PIN_AH16 -to uart_tx
```

---

## ⚙️ Generic Parameters

### Device Address Configuration

Set the device address via generic parameter:

```vhdl
-- In top-level instantiation:
uart_inst : uart_register_interface
    generic map (
        CLK_FREQ       => 100_000_000,  -- Your clock frequency
        BAUD_RATE      => 115200,
        DEVICE_ADDRESS => 0              -- Set device address (0-254)
    )
    port map (
        clk      => sys_clk,
        rst      => sys_rst,
        uart_rx  => uart_rx_pin,
        uart_tx  => uart_tx_pin,
        -- ... other ports
    );
```

### Clock Frequency

Update `CLK_FREQ` to match your board's system clock:

```vhdl
generic map (
    CLK_FREQ => 50_000_000,   -- 50 MHz (DE10-Nano, DE10-Standard)
    -- OR
    CLK_FREQ => 100_000_000,  -- 100 MHz (custom boards)
)
```

---

## 📊 Compilation

### GUI Compilation

1. **Analysis & Synthesis**
   ```
   Processing → Start → Start Analysis & Synthesis
   ```

2. **Fitter**
   ```
   Processing → Start → Start Fitter
   ```

3. **Timing Analysis**
   ```
   Processing → Start → Start Timing Analyzer
   ```

4. **Assembler**
   ```
   Processing → Start → Start Assembler
   ```

Or compile all at once:
```
Processing → Start Compilation
```

### Command Line Compilation

```bash
quartus_sh --flow compile uart_register_interface
```

---

## ⏱️ Timing Analysis

### Check Timing Report

1. **Open TimeQuest**
   ```
   Tools → TimeQuest Timing Analyzer
   ```

2. **Generate Reports**
   ```
   Reports → Create All Timing Reports
   ```

3. **Verify**
   - **Setup slack:** Should be positive
   - **Hold slack:** Should be positive
   - **Clock frequency:** Should meet 100 MHz (or your target)

### Common Timing Issues

**Problem:** Negative setup slack

**Solutions:**
1. Reduce clock frequency in SDC:
   ```tcl
   create_clock -period 20.000 -name sys_clk [get_ports {clk}]  # 50 MHz
   ```

2. Enable physical synthesis:
   ```tcl
   set_global_assignment -name PHYSICAL_SYNTHESIS_COMBO_LOGIC ON
   set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_RETIMING ON
   ```

---

## 📦 Programming the FPGA

### USB Blaster Configuration

1. **Connect USB Blaster** to your FPGA board

2. **Open Programmer**
   ```
   Tools → Programmer
   ```

3. **Add .sof File**
   ```
   Add File → output_files/uart_register_interface.sof
   ```

4. **Start Programming**
   ```
   Start
   ```

### Command Line Programming

```bash
quartus_pgm -c USB-Blaster -m JTAG -o "p;output_files/uart_register_interface.sof"
```

---

## 🐛 Troubleshooting

### Error: "Can't elaborate top-level user hierarchy"

**Cause:** VHDL file not found or syntax error

**Solution:**
1. Verify all files are added to project
2. Check for syntax errors: `Processing → Start → Start Analysis & Synthesis`

### Error: "No nodes available for location assignment"

**Cause:** Invalid pin assignment

**Solution:**
1. Check pin name in board documentation
2. Verify device is correct (e.g., 5CSEMA5F31C6 vs 5CSEMA5F31C8)
3. Use Pin Planner to find valid pins

### Error: "Timing requirements not met"

**Cause:** Design too slow for clock frequency

**Solution:**
1. Reduce clock frequency in SDC file
2. Enable optimization settings in QSF
3. Add pipeline stages if needed

### Warning: "Ignored VHDL-2008 construct"

**Cause:** VHDL version not set to 2008

**Solution:**
```
Assignments → Settings → Compiler Settings
VHDL Input Version: VHDL 2008
```

---

## 📚 Additional Resources

- [Intel Quartus Prime User Guide](https://www.intel.com/content/www/us/en/programmable/documentation/lit-index.html)
- [TimeQuest Timing Analyzer](https://www.intel.com/content/www/us/en/programmable/quartushelp/current/index.htm#tafs/tafs/tqs_tqs_introduction.htm)
- [Quartus TCL Reference](https://www.intel.com/content/www/us/en/programmable/quartushelp/current/index.htm#tafs/tafs/tcl_pkg_quartus_project_ver_1.0.htm)

---

## ✅ Verification Checklist

Before testing on hardware:

- [ ] All source files compiled without errors
- [ ] Pin assignments match your board
- [ ] Timing requirements met (positive slack)
- [ ] Device address configured correctly
- [ ] Clock frequency matches your board
- [ ] UART pins connected to USB-UART adapter
- [ ] .sof file generated successfully

---

## 🎯 Quick Reference

| Task | Command/Location |
|------|-----------------|
| Create project | `quartus_sh -t create_quartus_project.tcl` |
| Open GUI | `quartus uart_register_interface.qpf` |
| Compile | `quartus_sh --flow compile uart_register_interface` |
| Program | `quartus_pgm -c USB-Blaster -m JTAG -o "p;output_files/*.sof"` |
| Pin assignments | `constraints/uart_register_interface.qsf` |
| Timing constraints | `constraints/uart_register_interface.sdc` |

---

**Ready to synthesize?** Follow Method 1 above for the fastest setup!

**Questions?** See main [README.md](../README.md) or open an issue.
