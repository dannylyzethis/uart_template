# FPGA validation and MAX 10 bring-up

## Current result (2026-10-15)

The confirmed SPI and I2C defects have been corrected in the working tree.
ModelSim MCP exercises the protocol, peripheral controllers and the actual
50 MHz MAX 10 wrapper. The complete regression passed with exit code 0.
Quartus MCP completed full compilation for the existing
MAX 10 target. Physical board validation is still pending.

| Measurement | Current fit |
| --- | --- |
| Part | 10M08SAE144C8G |
| Top / clock | uart_max10_top / 50 MHz |
| Logic elements | 1,808 / 8,064 (22%) |
| Registers | 1,158 |
| Pins | 26 / 101 |
| RAM / multipliers / PLL | 1,024 data bits in 2 M9Ks / 0 / 0 |
| Worst internal setup / hold slack | +10.432 ns / +0.101 ns |
| Slow 85 C reported Fmax | 104.52 MHz |

These timing numbers cover constrained internal paths. TimeQuest still reports
seven unconstrained input ports and 21 unconstrained output ports. All 26 used
pins lack exact location assignments. The fitter also raises a single-supply
power review critical warning and a 3.3-V interface warning. Power is estimated
at 194.65 mW with low confidence (insufficient toggle data). Do not program the
SOF/POF until the board pin map, bank voltages and external timing are validated.
Read stage reports even when the shell's final summary says zero warnings.
Reports and generated images are in `quartus/output_files/` (ignored by Git).
QPF/QSF inputs were already tracked; ignore exceptions make that intent clear.

## Device addressing

`uart_max10_top.DEVICE_ADDRESS` defaults to `x"16"` and is passed into the
register interface. The command/reply first byte carries this device address
and is included in CRC-8. Foreign packets are consumed silently. This constant
requires no runtime flash/UFM writes. UART host software must be updated with
the FPGA image; legacy packets are incompatible. Python accepts
`device_address=0x16`, and both example scripts accept `--device-address 0x16`.
See the register specification for packet tables and computed CRC examples.

## FIFO implementation

The UART register interface now has independent 64-byte RX/TX FIFOs by
default, using two M9K blocks (one per queue). Separating the synchronous RAM
read register from forwarding logic lets Quartus infer embedded RAM. Relative
to the pre-FIFO fit the FIFO implementation added 129 logic elements and 79
registers; device addressing adds another 29 logic elements and 3 registers.

Queue status/capacity are at 0x17/0x18; sticky RX/TX overflow flags are bits
8/9 of 0x16. TX backpressure pauses response construction. RX overflow flushes
unprocessed input and discards bytes until 10 ms of continuous idle. The
watchdog now measures inter-byte gaps in incomplete commands, not TX stalls.
Python includes FIFO status/capacity helpers and error enums. Addressed
commands now use 12 bytes and replies use 11 bytes. See the register specification for precise field semantics.

## Fixes and interface changes

- SPI CPHA=0 now transmits the bit already selected by the preceding sample
  edge, instead of skipping it. The final trailing edge occurs while CS is
  asserted, followed by a full half-clock hold before CS releases.
- SPI uses a leading/trailing phase bit instead of a finite edge counter,
  eliminating the overflow on 32-bit CPHA=1 transfers.
- I2C captures the received byte once: phase 3 uses the shift register already
  updated in phase 2. Two-stage bus input synchronizers normalize pull-ups.
- I2C waits for observed SCL high and restarts its phase timer after stretching,
  preserving the high interval through address, ACK, data, NACK and STOP.
- MAX 10 control register 0x02 uses previously reserved bits 55 and 23 as
  I2C0_READ/I2C1_READ. Zero retains the existing write format; one requests a
  single-byte read. Start bits remain 63/31 and address fields remain 62:56 /
  30:24. Received bytes appear in status 0x12 at 23:16 / 7:0.
- Python `start_i2c_read(channel, device_addr)` sends that command. It does not
  wait for the peripheral: poll system busy flags and inspect sticky ACK errors
  before consuming `read_voltages()['i2c0_rx'/'i2c1_rx']`.

I2C supports one-byte transactions here, not repeated-start register reads or
multi-master arbitration. A slave holding SCL low indefinitely stalls the
transaction until released or reset; there is no bus-stretch timeout.

## Simulation

Validated with ModelSim ALTERA STARTER EDITION 10.5b at
`C:/intelFPGA/18.1/modelsim_ase/win32aloem/vsim.exe`.
The Quartus MCP also detects Questa 2021.2; it was not used for these runs.
Keep simulator libraries separate when switching versions.

From `simulation/` with ModelSim on PATH:

```text
vsim -c -do "do run_regression.do"
```

Or use `make sim-regression`. The runner recompiles all design/test units,
checks assertion errors and completion flags, and returns a nonzero exit on
failure. BreakOnAssertion is set after each vsim load, because ModelSim 10.5b
resets it during loading. Expected warning reports in the original UART tests
exercise error detection and are not assertion failures.

| Test | Coverage |
| --- | --- |
| uart_register_tb | 15 protocol scenarios, response bytes/CRC, framing, timeout, sticky errors/clear |
| uart_system_tb | Integrated UART/peripherals, pulled-up no-slave I2C NACK, SPI completion, protocol errors |
| spi_master_tb | Existing mode-1/8-bit MOSI and constant MISO test |
| spi_modes_tb matrix | 336 cases: all four modes, every width 5..32, dividers 0/1/7; MOSI, loopback RX, 2*N clock edges, CS hold, busy and completion pulses |
| i2c_master_tb matrix | 44 transactions: four read/write byte patterns plus address/data NACKs at 100/400 kHz, with/without 17 us stretches; STOP, valid/done pulses, high-phase duration |
| sync_byte_fifo_tb | Depths 1/3/16/64: empty/full, simultaneous push/pop, wrap, rejected operations, reset, and 2,000 pseudorandom cycles per depth |
| uart_fifo_tb | Serial packets with ordered bursts, 12 ms TX backpressure, queued writes, capacities/levels, RX overflow, idle recovery and W1C |
| uart_address_tb | Addresses 0x16/0xA5/0x00/0xFF; foreign packet filtering including embedded local address bytes, invalid foreign packets, local CRC errors, address CRC coverage, exact command/write strobes, foreign timeout recovery |
| uart_max10_tb | Actual 50 MHz top with DEVICE_ADDRESS=0xA5: both I2C channels read/write with stretching, SPI0 mode-0/8-bit and SPI1 mode-1/32-bit loopback readback, UART response CRC and clean error status |

Focused runners: `run_address_test.do`, `run_fifo_test.do`, `run_spi_matrix.do`, `run_i2c_test.do`, `run_max10_test.do`.
The retained `run_spi_diagnostic.do` and `run_spi_32bit_diagnostic.do` reproduce
the formerly failing cases and now must pass. Run the main compile first when
using these two focused diagnostics.

ModelSim MCP `modelsim_run_do_file` arguments (workspace `C:/Projects`):

```json
{
  "workingDirectory": "uart_template/simulation",
  "doFile": "uart_template/simulation/run_regression.do",
  "timeoutSeconds": 600
}
```

Paths such as doFile and source filenames are relative to the server workspace,
not workingDirectory. The scripts compile with VHDL-2002. Direct MCP compilation
with `-2008` also passed during the initial analysis.

Offline Python wire-format checks (serial dependency/hardware mocked):

```text
python -B -m unittest discover -s python -p "test_*.py" -v
```

The fourteen tests verify device address configuration, address-inclusive CRC,
wrong-device/legacy reply rejection, FIFO register packets, decoded levels/flags, overflow W1C,
missing/malformed responses, both I2C read channels, I2C write payloads, CRC residue and
rejection of invalid channel/address values. Real serial transport is not tested.

## Quartus

Validated with Quartus Prime Lite 21.1.0 Build 842. From `quartus/`:

```text
quartus_sh --flow compile uart_max10_top
```

Or use `make synth`. Quartus MCP `quartus_compile` arguments:

```json
{
  "project": "uart_max10_top",
  "workingDirectory": "uart_template/quartus",
  "timeoutSeconds": 300
}
```

The QSF lists the six synthesis units and the SDC. The SDC defines a 20 ns
clock and UART input exception but no external I/O delays. The Xilinx XDC is
not used in this flow. The part and 3.3-V LVTTL standard need confirmation
against the actual board.

## Beads and remaining board work

- `uart_template-fek`: addressed UART format, configurable top-level constant and host/RTL regression.
- `uart_template-8g9`: UART FIFOs, host status helpers, overflow recovery and validation.
- `uart_template-drf`: SPI fixes and regression matrix.
- `uart_template-4ty`: I2C read capture/stretching fixes, read-select mapping,
  slave model, host helper and end-to-end validation.
- `uart_template-d2q`: external timing still needs justified constraints.
- `uart_template-9r8`: board/part, pin assignments, bank voltages, power and I/O
  requirements remain open. The 50 MHz top-level test is now implemented.
  Reset/CDC hardware review remains: external reset currently drives synchronous
  resets directly; TimeQuest does not recognize the RTL synchronizer chains.

No hardware programming, Git commit, push or Dolt remote sync was performed.
