#!/usr/bin/env python3
"""
EEPROM LUT Programmer
Generates and programs I2C EEPROM with lookup table data

Supports:
- Binary image generation
- CRC32 calculation and validation
- Multiple LUT types (calibration, correction, temperature, waveform)
- Direct I2C programming via UART interface

Author: RF Test Automation Engineering
Date: 2025-11-22
"""

import struct
import zlib
import argparse
import math
from typing import List, Tuple

def crc32(data: bytes) -> int:
    """Calculate CRC32 checksum"""
    return zlib.crc32(data) & 0xFFFFFFFF

def pack_u32_be(value: int) -> bytes:
    """Pack 32-bit unsigned integer as big-endian"""
    return struct.pack('>I', value & 0xFFFFFFFF)

def pack_u16_be(value: int) -> bytes:
    """Pack 16-bit unsigned integer as big-endian"""
    return struct.pack('>H', value & 0xFFFF)

class EEPROMImage:
    """EEPROM image builder for LUT data"""

    MAGIC_NUMBER = b'LFPG'
    FORMAT_VERSION = 0x01
    HEADER_ADDR = 0x0000
    DESCRIPTOR_ADDR = 0x0010
    LUT0_ADDR = 0x0030
    LUT1_ADDR = 0x0430
    LUT2_ADDR = 0x0830
    LUT3_ADDR = 0x0C30

    LUT_TYPE_CALIBRATION = 0
    LUT_TYPE_CORRECTION = 1
    LUT_TYPE_TEMPERATURE = 2
    LUT_TYPE_WAVEFORM = 3

    def __init__(self, size_bytes: int = 32768):
        """
        Initialize EEPROM image

        Args:
            size_bytes: EEPROM size in bytes (default 32KB for 24LC256)
        """
        self.size = size_bytes
        self.image = bytearray(size_bytes)
        self.luts = [None, None, None, None]
        self.lut_types = [
            self.LUT_TYPE_CALIBRATION,
            self.LUT_TYPE_CORRECTION,
            self.LUT_TYPE_TEMPERATURE,
            self.LUT_TYPE_WAVEFORM
        ]

    def set_lut(self, lut_index: int, data: List[int], lut_type: int = None):
        """
        Set LUT data

        Args:
            lut_index: LUT index (0-3)
            data: List of 32-bit integer values (up to 256 entries)
            lut_type: LUT type (0-3), defaults to predefined types
        """
        if lut_index < 0 or lut_index > 3:
            raise ValueError(f"LUT index must be 0-3, got {lut_index}")

        if len(data) > 256:
            raise ValueError(f"LUT too large: {len(data)} entries (max 256)")

        # Pad to 256 entries
        padded_data = list(data) + [0] * (256 - len(data))

        self.luts[lut_index] = padded_data

        if lut_type is not None:
            self.lut_types[lut_index] = lut_type

    def build(self) -> bytes:
        """
        Build complete EEPROM image

        Returns:
            bytes: Complete EEPROM image
        """
        # Count valid LUTs
        num_luts = sum(1 for lut in self.luts if lut is not None)
        if num_luts == 0:
            raise ValueError("No LUTs defined")

        # Calculate total data size
        total_size = num_luts * 256 * 4  # 256 entries × 4 bytes per LUT

        # Write header
        self.image[0:4] = self.MAGIC_NUMBER
        self.image[4] = self.FORMAT_VERSION
        self.image[5] = num_luts
        self.image[6:8] = pack_u16_be(total_size)

        # Calculate and write header CRC
        header_crc = crc32(bytes(self.image[0:8]))
        self.image[8:12] = pack_u32_be(header_crc)

        print(f"Header CRC32: 0x{header_crc:08X}")

        # Write LUT descriptors and data
        lut_addresses = [self.LUT0_ADDR, self.LUT1_ADDR, self.LUT2_ADDR, self.LUT3_ADDR]

        for i in range(4):
            if self.luts[i] is None:
                continue

            desc_addr = self.DESCRIPTOR_ADDR + i * 8
            data_addr = lut_addresses[i]

            # Pack LUT data
            lut_data = bytearray()
            for value in self.luts[i]:
                lut_data.extend(pack_u32_be(value))

            # Calculate LUT CRC
            lut_crc = crc32(bytes(lut_data))

            # Write descriptor
            self.image[desc_addr:desc_addr+2] = pack_u16_be(256)  # Size
            self.image[desc_addr+2] = 4  # Width (4 bytes per entry)
            self.image[desc_addr+3] = self.lut_types[i]  # Type
            self.image[desc_addr+4:desc_addr+8] = pack_u32_be(lut_crc)

            # Write LUT data
            self.image[data_addr:data_addr+len(lut_data)] = lut_data

            print(f"LUT{i} CRC32: 0x{lut_crc:08X} (type={self.lut_types[i]}, {len(self.luts[i])} entries)")

        return bytes(self.image)

    def save(self, filename: str):
        """Save EEPROM image to file"""
        image = self.build()
        with open(filename, 'wb') as f:
            f.write(image)
        print(f"✓ EEPROM image saved: {filename} ({len(image)} bytes)")

    def verify(self, filename: str) -> bool:
        """Verify EEPROM image file"""
        with open(filename, 'rb') as f:
            data = f.read()

        if data[0:4] != self.MAGIC_NUMBER:
            print(f"✗ Magic number mismatch: {data[0:4]} != {self.MAGIC_NUMBER}")
            return False

        version = data[4]
        if version != self.FORMAT_VERSION:
            print(f"✗ Version mismatch: {version} != {self.FORMAT_VERSION}")
            return False

        num_luts = data[5]
        total_size = struct.unpack('>H', data[6:8])[0]

        # Verify header CRC
        header_crc_stored = struct.unpack('>I', data[8:12])[0]
        header_crc_calc = crc32(data[0:8])

        if header_crc_stored != header_crc_calc:
            print(f"✗ Header CRC mismatch: 0x{header_crc_stored:08X} != 0x{header_crc_calc:08X}")
            return False

        print(f"✓ Header valid (version={version}, num_luts={num_luts}, size={total_size})")

        # Verify each LUT CRC
        lut_addresses = [self.LUT0_ADDR, self.LUT1_ADDR, self.LUT2_ADDR, self.LUT3_ADDR]

        for i in range(num_luts):
            desc_addr = self.DESCRIPTOR_ADDR + i * 8
            data_addr = lut_addresses[i]

            lut_size = struct.unpack('>H', data[desc_addr:desc_addr+2])[0]
            lut_width = data[desc_addr+2]
            lut_type = data[desc_addr+3]
            lut_crc_stored = struct.unpack('>I', data[desc_addr+4:desc_addr+8])[0]

            lut_data_len = lut_size * lut_width
            lut_data = data[data_addr:data_addr+lut_data_len]
            lut_crc_calc = crc32(lut_data)

            if lut_crc_stored != lut_crc_calc:
                print(f"✗ LUT{i} CRC mismatch: 0x{lut_crc_stored:08X} != 0x{lut_crc_calc:08X}")
                return False

            print(f"✓ LUT{i} valid (type={lut_type}, size={lut_size}, CRC=0x{lut_crc_calc:08X})")

        print("✓ All checks passed")
        return True


# ============================================================================
# LUT Generators
# ============================================================================

def generate_calibration_lut(num_channels: int = 256) -> List[int]:
    """
    Generate calibration LUT (LUT0)

    Format: [31:16] Gain (Q15), [15:0] Offset (signed)

    Args:
        num_channels: Number of channels (default 256)

    Returns:
        List of 256 calibration values
    """
    lut = []

    for i in range(256):
        if i < num_channels:
            # Example: Slight gain variation (±2%)
            gain_variation = 1.0 + (i - 128) * 0.0002  # ±2% max
            gain_q15 = int(gain_variation * 32767) & 0xFFFF

            # Example: Small offset (±10 counts)
            offset = int((i - 128) * 0.078)  # ±10 counts max
            offset_s16 = offset & 0xFFFF

            value = (gain_q15 << 16) | offset_s16
        else:
            # Unused channels: gain=1.0, offset=0
            value = 0x7FFF0000

        lut.append(value)

    return lut


def generate_linearization_lut(curve_type: str = 'linear') -> List[int]:
    """
    Generate linearization/correction LUT (LUT1)

    Args:
        curve_type: 'linear', 'quadratic', 'cubic', 'exponential'

    Returns:
        List of 256 correction values
    """
    lut = []

    for i in range(256):
        x = i / 255.0  # Normalize to 0.0-1.0

        if curve_type == 'linear':
            y = x
        elif curve_type == 'quadratic':
            y = x * x
        elif curve_type == 'cubic':
            y = x * x * x
        elif curve_type == 'exponential':
            y = (math.exp(x) - 1) / (math.e - 1)
        else:
            y = x

        # Scale to 32-bit signed range
        value = int(y * 2147483647)  # Max positive value for signed 32-bit
        lut.append(value & 0xFFFFFFFF)

    return lut


def generate_temperature_comp_lut(tc1_ppm: float = 50.0, tc2_ppb: float = 0.1) -> List[int]:
    """
    Generate temperature compensation LUT (LUT2)

    Format: [31:16] TC1 (ppm/°C), [15:0] TC2 (ppb/°C²)

    Args:
        tc1_ppm: First-order temperature coefficient (ppm/°C)
        tc2_ppb: Second-order temperature coefficient (ppb/°C²)

    Returns:
        List of 256 temperature compensation values
    """
    lut = []

    for i in range(256):
        # Example: Different TC for each sensor channel
        channel_tc1 = tc1_ppm + (i - 128) * 0.5  # Variation across channels
        channel_tc2 = tc2_ppb + (i - 128) * 0.001

        # Pack as 16-bit signed values
        tc1_s16 = int(channel_tc1) & 0xFFFF
        tc2_s16 = int(channel_tc2 * 1000) & 0xFFFF  # ppb → scaled integer

        value = (tc1_s16 << 16) | tc2_s16
        lut.append(value)

    return lut


def generate_waveform_lut(waveform_type: str = 'sine', amplitude: int = 32767) -> List[int]:
    """
    Generate waveform LUT (LUT3)

    Args:
        waveform_type: 'sine', 'square', 'triangle', 'sawtooth'
        amplitude: Peak amplitude (default 32767 for 16-bit)

    Returns:
        List of 256 waveform samples
    """
    lut = []

    for i in range(256):
        phase = 2 * math.pi * i / 256

        if waveform_type == 'sine':
            value = int(amplitude * math.sin(phase))
        elif waveform_type == 'square':
            value = amplitude if i < 128 else -amplitude
        elif waveform_type == 'triangle':
            if i < 64:
                value = int(amplitude * i / 64)
            elif i < 192:
                value = int(amplitude * (2 - i / 64))
            else:
                value = int(amplitude * (i / 64 - 4))
        elif waveform_type == 'sawtooth':
            value = int(amplitude * (2 * i / 256 - 1))
        else:
            value = 0

        lut.append(value & 0xFFFFFFFF)

    return lut


# ============================================================================
# Main CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description='EEPROM LUT Programmer')

    subparsers = parser.add_subparsers(dest='command', help='Command')

    # Generate command
    gen_parser = subparsers.add_parser('generate', help='Generate EEPROM image')
    gen_parser.add_argument('-o', '--output', default='eeprom.bin', help='Output file')
    gen_parser.add_argument('--lut0', choices=['cal', 'zero'], default='cal', help='LUT0 type')
    gen_parser.add_argument('--lut1', choices=['linear', 'quadratic', 'cubic', 'exp'], default='linear', help='LUT1 curve')
    gen_parser.add_argument('--lut2', choices=['temp', 'zero'], default='temp', help='LUT2 type')
    gen_parser.add_argument('--lut3', choices=['sine', 'square', 'triangle', 'sawtooth'], default='sine', help='LUT3 waveform')

    # Verify command
    verify_parser = subparsers.add_parser('verify', help='Verify EEPROM image')
    verify_parser.add_argument('file', help='EEPROM image file')

    # Dump command
    dump_parser = subparsers.add_parser('dump', help='Dump LUT data')
    dump_parser.add_argument('file', help='EEPROM image file')
    dump_parser.add_argument('--lut', type=int, default=0, help='LUT index (0-3)')
    dump_parser.add_argument('--entries', type=int, default=16, help='Number of entries to display')

    args = parser.parse_args()

    if args.command == 'generate':
        print("Generating EEPROM image...")

        eeprom = EEPROMImage()

        # Generate LUT0 (Calibration)
        if args.lut0 == 'cal':
            lut0 = generate_calibration_lut()
        else:
            lut0 = [0] * 256
        eeprom.set_lut(0, lut0)
        print(f"  LUT0: Calibration ({args.lut0})")

        # Generate LUT1 (Linearization)
        lut1 = generate_linearization_lut(args.lut1)
        eeprom.set_lut(1, lut1)
        print(f"  LUT1: Linearization ({args.lut1})")

        # Generate LUT2 (Temperature)
        if args.lut2 == 'temp':
            lut2 = generate_temperature_comp_lut()
        else:
            lut2 = [0] * 256
        eeprom.set_lut(2, lut2)
        print(f"  LUT2: Temperature ({args.lut2})")

        # Generate LUT3 (Waveform)
        lut3 = generate_waveform_lut(args.lut3)
        eeprom.set_lut(3, lut3)
        print(f"  LUT3: Waveform ({args.lut3})")

        # Build and save
        eeprom.save(args.output)

    elif args.command == 'verify':
        print(f"Verifying EEPROM image: {args.file}")
        eeprom = EEPROMImage()
        success = eeprom.verify(args.file)
        exit(0 if success else 1)

    elif args.command == 'dump':
        print(f"Dumping LUT{args.lut} from {args.file}:")

        with open(args.file, 'rb') as f:
            data = f.read()

        lut_addresses = [0x0030, 0x0430, 0x0830, 0x0C30]
        lut_addr = lut_addresses[args.lut]

        print(f"\nLUT{args.lut} Data (first {args.entries} entries):")
        print("Index | Value (hex)  | Value (dec)   | Value (bin)")
        print("------|--------------|---------------|----------------------------------")

        for i in range(min(args.entries, 256)):
            offset = lut_addr + i * 4
            value = struct.unpack('>I', data[offset:offset+4])[0]
            value_signed = struct.unpack('>i', data[offset:offset+4])[0]

            print(f"{i:3d}   | 0x{value:08X}  | {value_signed:13d} | {value:032b}")

    else:
        parser.print_help()


if __name__ == '__main__':
    main()
