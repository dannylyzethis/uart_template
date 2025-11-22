#!/usr/bin/env python3
"""
UART Register Interface - Python Host Library
For communication with FPGA-based RF test equipment

Author: RF Test Automation Engineering
Date: 2025-11-22
License: MIT
"""

import serial
import struct
import time
from typing import Optional, Tuple
from enum import IntEnum


class RegisterAddress(IntEnum):
    """Control and Status Register Addresses"""
    # Control Registers (Write)
    CTRL_SYSTEM = 0x00
    CTRL_SWITCH = 0x01
    CTRL_I2C = 0x02
    CTRL_SPI_DATA = 0x03
    CTRL_SPI0_CONFIG = 0x04
    CTRL_SPI1_CONFIG = 0x05
    CTRL_GPIO0 = 0x06
    CTRL_GPIO1 = 0x07
    CTRL_GPIO2 = 0x08
    CTRL_GPIO3 = 0x09

    # Status Registers (Read)
    STATUS_SYSTEM = 0x10
    STATUS_CURRENT = 0x11
    STATUS_VOLTAGE = 0x12
    STATUS_SPI_DATA = 0x13
    STATUS_SWITCH = 0x14
    STATUS_COUNTERS = 0x15
    STATUS_GPIO0 = 0x16
    STATUS_GPIO1 = 0x17
    STATUS_GPIO2 = 0x18
    STATUS_GPIO3 = 0x19


class Command(IntEnum):
    """UART Command Types"""
    WRITE = 0x01
    READ = 0x02


class UARTRegisterInterface:
    """
    UART Register Interface for FPGA Control

    Provides high-level methods to interact with FPGA control/status registers
    via UART with CRC-8 error detection.
    """

    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 1.0, device_address: int = 0):
        """
        Initialize UART interface

        Args:
            port: Serial port name (e.g., 'COM3' on Windows, '/dev/ttyUSB0' on Linux)
            baudrate: UART baud rate (default 115200)
            timeout: Read timeout in seconds (default 1.0)
            device_address: FPGA device address (0-254, or 255 for broadcast)
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.device_address = device_address & 0xFF
        self.serial = None
        self._stats = {
            'commands_sent': 0,
            'responses_received': 0,
            'crc_errors': 0,
            'timeouts': 0,
        }

    def open(self):
        """Open the serial port"""
        try:
            self.serial = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=self.timeout
            )
            self.serial.reset_input_buffer()
            self.serial.reset_output_buffer()
            print(f"Opened {self.port} at {self.baudrate} baud")
        except serial.SerialException as e:
            raise ConnectionError(f"Failed to open {self.port}: {e}")

    def close(self):
        """Close the serial port"""
        if self.serial and self.serial.is_open:
            self.serial.close()
            print(f"Closed {self.port}")

    def __enter__(self):
        """Context manager entry"""
        self.open()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()

    @staticmethod
    def _crc8_update(crc: int, data: int) -> int:
        """
        CRC-8 calculation using polynomial 0x07

        Args:
            crc: Current CRC value
            data: Data byte to add

        Returns:
            Updated CRC value
        """
        temp = crc ^ data
        crc = (temp << 1) & 0xFF
        if temp & 0x80:
            crc ^= 0x07
        return crc

    @staticmethod
    def _calculate_crc(data: bytes) -> int:
        """
        Calculate CRC-8 for a byte sequence

        Args:
            data: Byte sequence

        Returns:
            CRC-8 value
        """
        crc = 0x00
        for byte in data:
            crc = UARTRegisterInterface._crc8_update(crc, byte)
        return crc

    def write_register(self, address: int, value: int) -> bool:
        """
        Write to a control register

        Args:
            address: Register address (0x00-0x05)
            value: 64-bit value to write

        Returns:
            True if successful, False otherwise

        Raises:
            ValueError: If address is invalid
            ConnectionError: If serial port is not open
        """
        if not (0x00 <= address <= 0x05):
            raise ValueError(f"Invalid control register address: 0x{address:02X}")

        if not self.serial or not self.serial.is_open:
            raise ConnectionError("Serial port not open")

        # Build command packet: [DEV_ADDR][CMD][ADDR][DATA0-7][CRC]
        packet = bytearray()
        packet.append(self.device_address)  # Device address first
        packet.append(Command.WRITE)
        packet.append(address)

        # Add 64-bit data (big-endian)
        data_bytes = struct.pack('>Q', value & 0xFFFFFFFFFFFFFFFF)
        packet.extend(data_bytes)

        # Calculate and append CRC
        crc = self._calculate_crc(packet)
        packet.append(crc)

        # Send packet
        self.serial.write(packet)
        self._stats['commands_sent'] += 1

        return True

    def read_register(self, address: int) -> Optional[int]:
        """
        Read from a status register

        Args:
            address: Register address (0x10-0x15)

        Returns:
            64-bit register value, or None on error

        Raises:
            ValueError: If address is invalid
            ConnectionError: If serial port is not open
        """
        if not (0x10 <= address <= 0x15):
            raise ValueError(f"Invalid status register address: 0x{address:02X}")

        if not self.serial or not self.serial.is_open:
            raise ConnectionError("Serial port not open")

        # Build read command packet: [DEV_ADDR][CMD][ADDR][DATA0-7][CRC]
        packet = bytearray()
        packet.append(self.device_address)  # Device address first
        packet.append(Command.READ)
        packet.append(address)
        packet.extend([0] * 8)  # Dummy data

        # Calculate and append CRC
        crc = self._calculate_crc(packet)
        packet.append(crc)

        # Send packet
        self.serial.reset_input_buffer()
        self.serial.write(packet)
        self._stats['commands_sent'] += 1

        # Wait for response: [HDR][DATA0-7][CRC] = 10 bytes
        response = self.serial.read(10)

        if len(response) != 10:
            self._stats['timeouts'] += 1
            print(f"Warning: Incomplete response (got {len(response)} bytes)")
            return None

        # Verify response header
        if response[0] != 0x02:
            print(f"Warning: Invalid response header: 0x{response[0]:02X}")
            return None

        # Verify CRC
        calc_crc = self._calculate_crc(response[0:9])
        recv_crc = response[9]

        if calc_crc != recv_crc:
            self._stats['crc_errors'] += 1
            print(f"Warning: CRC error (calc=0x{calc_crc:02X}, recv=0x{recv_crc:02X})")
            return None

        # Extract 64-bit data (big-endian)
        data = struct.unpack('>Q', response[1:9])[0]
        self._stats['responses_received'] += 1

        return data

    # ============ High-Level Control Methods ============

    def set_system_control(self, reset: bool = False, enable: bool = True):
        """Set system control bits"""
        value = 0
        if reset:
            value |= 0x01
        if enable:
            value |= 0x02
        self.write_register(RegisterAddress.CTRL_SYSTEM, value)

    def set_switches(self, bank0: int = 0, bank1: int = 0, bank2: int = 0, bank3: int = 0):
        """
        Set switch positions for all banks

        Args:
            bank0-3: 16-bit switch positions for each bank
        """
        value = ((bank3 & 0xFFFF) << 48) | ((bank2 & 0xFFFF) << 32) | \
                ((bank1 & 0xFFFF) << 16) | (bank0 & 0xFFFF)
        self.write_register(RegisterAddress.CTRL_SWITCH, value)

    def write_i2c(self, channel: int, device_addr: int, data: int):
        """
        Write to I2C device

        Args:
            channel: I2C channel (0 or 1)
            device_addr: 7-bit I2C device address
            data: 8-bit data to write
        """
        if channel == 0:
            value = (1 << 63) | ((device_addr & 0x7F) << 56) | ((data & 0xFF) << 8)
        else:
            value = (1 << 31) | ((device_addr & 0x7F) << 24) | (data & 0xFF)

        self.write_register(RegisterAddress.CTRL_I2C, value)

    def configure_spi(self, channel: int, cpol: bool, cpha: bool,
                     word_len: int, clk_div: int, chip_select: int):
        """
        Configure SPI controller

        Args:
            channel: SPI channel (0 or 1)
            cpol: Clock polarity (False=idle low, True=idle high)
            cpha: Clock phase (False=leading edge, True=trailing edge)
            word_len: Word length in bits (5-32)
            clk_div: Clock divider value
            chip_select: Chip select (0-3)
        """
        if not (5 <= word_len <= 32):
            raise ValueError("Word length must be 5-32 bits")

        value = (1 << 63) | \
                ((1 if cpol else 0) << 62) | \
                ((1 if cpha else 0) << 61) | \
                (((word_len - 1) & 0x1F) << 56) | \
                ((clk_div & 0xFFFF) << 40) | \
                ((1 << chip_select) << 32)

        reg = RegisterAddress.CTRL_SPI0_CONFIG if channel == 0 else RegisterAddress.CTRL_SPI1_CONFIG
        self.write_register(reg, value)

    def write_spi(self, channel: int, data: int):
        """
        Write data to SPI

        Args:
            channel: SPI channel (0 or 1)
            data: 32-bit data to transmit
        """
        current = self.read_register(RegisterAddress.CTRL_SPI_DATA) or 0

        if channel == 0:
            value = ((data & 0xFFFFFFFF) << 32) | (current & 0xFFFFFFFF)
        else:
            value = (current & 0xFFFFFFFF00000000) | (data & 0xFFFFFFFF)

        self.write_register(RegisterAddress.CTRL_SPI_DATA, value)

    def set_gpio_output(self, bank: int, value: int):
        """
        Set GPIO output register value

        Args:
            bank: GPIO bank (0-3)
            value: 64-bit value to write to GPIO outputs
        """
        if not (0 <= bank <= 3):
            raise ValueError(f"Invalid GPIO bank: {bank} (must be 0-3)")

        reg = RegisterAddress.CTRL_GPIO0 + bank
        self.write_register(reg, value & 0xFFFFFFFFFFFFFFFF)

    def set_gpio_bit(self, bank: int, bit: int, value: bool):
        """
        Set a single GPIO output bit

        Args:
            bank: GPIO bank (0-3)
            bit: Bit position (0-63)
            value: True for high, False for low
        """
        if not (0 <= bank <= 3):
            raise ValueError(f"Invalid GPIO bank: {bank} (must be 0-3)")
        if not (0 <= bit <= 63):
            raise ValueError(f"Invalid bit position: {bit} (must be 0-63)")

        reg = RegisterAddress.CTRL_GPIO0 + bank
        current = self.read_register(reg) or 0

        if value:
            new_value = current | (1 << bit)
        else:
            new_value = current & ~(1 << bit)

        self.write_register(reg, new_value)

    # ============ High-Level Status Methods ============

    def read_system_status(self) -> dict:
        """Read system status register"""
        value = self.read_register(RegisterAddress.STATUS_SYSTEM)
        if value is None:
            return {}

        return {
            'timestamp': (value >> 32) & 0xFFFFFFFF,
            'bus_status': (value >> 24) & 0xFF,
            'error_flags': (value >> 16) & 0xFF,
            'temperature': (value >> 8) & 0xFF,
            'status_bits': value & 0xFF,
        }

    def read_currents(self) -> dict:
        """Read current measurements"""
        value = self.read_register(RegisterAddress.STATUS_CURRENT)
        if value is None:
            return {}

        return {
            'mon0': value & 0xFFFF,
            'mon1': (value >> 16) & 0xFFFF,
            'mon2': (value >> 32) & 0xFFFF,
            'mon3': (value >> 48) & 0xFFFF,
        }

    def read_voltages(self) -> dict:
        """Read voltage measurements"""
        value = self.read_register(RegisterAddress.STATUS_VOLTAGE)
        if value is None:
            return {}

        return {
            'volt0': (value >> 32) & 0xFFFF,
            'volt1': (value >> 48) & 0xFFFF,
            'i2c0_rx': (value >> 16) & 0xFFFF,
            'i2c1_rx': value & 0xFFFF,
        }

    def get_gpio_input(self, bank: int) -> Optional[int]:
        """
        Read GPIO input register value

        Args:
            bank: GPIO bank (0-3)

        Returns:
            64-bit value from GPIO inputs, or None on error
        """
        if not (0 <= bank <= 3):
            raise ValueError(f"Invalid GPIO bank: {bank} (must be 0-3)")

        reg = RegisterAddress.STATUS_GPIO0 + bank
        return self.read_register(reg)

    def get_gpio_bit(self, bank: int, bit: int) -> Optional[bool]:
        """
        Read a single GPIO input bit

        Args:
            bank: GPIO bank (0-3)
            bit: Bit position (0-63)

        Returns:
            True if bit is high, False if low, None on error
        """
        if not (0 <= bank <= 3):
            raise ValueError(f"Invalid GPIO bank: {bank} (must be 0-3)")
        if not (0 <= bit <= 63):
            raise ValueError(f"Invalid bit position: {bit} (must be 0-63)")

        value = self.get_gpio_input(bank)
        if value is None:
            return None

        return bool((value >> bit) & 1)

    def get_statistics(self) -> dict:
        """Get communication statistics"""
        return self._stats.copy()

    def reset_statistics(self):
        """Reset communication statistics"""
        for key in self._stats:
            self._stats[key] = 0


# ============ Example Usage ============

def main():
    """Example usage of the UART Register Interface"""

    # Create interface (update port for your system)
    uart = UARTRegisterInterface(port='/dev/ttyUSB0', baudrate=115200)

    try:
        # Use context manager for automatic open/close
        with uart:
            print("\n=== UART Register Interface Test ===\n")

            # 1. System control
            print("1. Setting system control...")
            uart.set_system_control(reset=False, enable=True)
            time.sleep(0.1)

            # 2. Read system status
            print("2. Reading system status...")
            status = uart.read_system_status()
            print(f"   Status: {status}")

            # 3. Configure and use SPI
            print("3. Configuring SPI0...")
            uart.configure_spi(
                channel=0,
                cpol=False,
                cpha=False,
                word_len=16,
                clk_div=100,
                chip_select=0
            )

            print("4. Writing SPI data...")
            uart.write_spi(channel=0, data=0xDEADBEEF)
            time.sleep(0.1)

            # 4. Read measurements
            print("5. Reading current measurements...")
            currents = uart.read_currents()
            print(f"   Currents: {currents}")

            print("6. Reading voltage measurements...")
            voltages = uart.read_voltages()
            print(f"   Voltages: {voltages}")

            # 6. GPIO operations
            print("\n7. Setting GPIO outputs...")
            uart.set_gpio_output(bank=0, value=0xDEADBEEFCAFEBABE)
            print("   GPIO bank 0 set to 0xDEADBEEFCAFEBABE")

            print("8. Setting individual GPIO bits...")
            uart.set_gpio_bit(bank=1, bit=5, value=True)
            uart.set_gpio_bit(bank=1, bit=10, value=False)
            print("   GPIO bank 1, bit 5 = HIGH, bit 10 = LOW")

            print("9. Reading GPIO inputs...")
            gpio_in0 = uart.get_gpio_input(bank=0)
            print(f"   GPIO input bank 0: 0x{gpio_in0:016X}" if gpio_in0 is not None else "   GPIO read failed")

            print("10. Reading individual GPIO input bit...")
            bit_value = uart.get_gpio_bit(bank=0, bit=7)
            print(f"   GPIO bank 0, bit 7 = {'HIGH' if bit_value else 'LOW'}" if bit_value is not None else "   Bit read failed")

            # 7. Display statistics
            print("\n=== Communication Statistics ===")
            stats = uart.get_statistics()
            for key, value in stats.items():
                print(f"   {key}: {value}")

    except Exception as e:
        print(f"Error: {e}")


if __name__ == '__main__':
    main()
