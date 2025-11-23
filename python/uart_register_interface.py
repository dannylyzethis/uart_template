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
import threading
from typing import Optional, Tuple, Callable, Dict, List, Any
from enum import IntEnum
from dataclasses import dataclass, field
from collections import defaultdict


class RegisterAddress(IntEnum):
    """Control and Status Register Addresses"""
    # Control Registers (Write)
    CTRL_SYSTEM = 0x00
    CTRL_SWITCH = 0x01
    CTRL_I2C = 0x02
    CTRL_SPI_DATA = 0x03
    CTRL_SPI0_CONFIG = 0x04
    CTRL_SPI1_CONFIG = 0x05

    # Status Registers (Read)
    STATUS_SYSTEM = 0x10
    STATUS_CURRENT = 0x11
    STATUS_VOLTAGE = 0x12
    STATUS_SPI_DATA = 0x13
    STATUS_SWITCH = 0x14
    STATUS_COUNTERS = 0x15


class Command(IntEnum):
    """UART Command Types"""
    WRITE = 0x01
    READ = 0x02


class IOLineEvent(IntEnum):
    """IO Line Event Types"""
    # I2C Events
    I2C0_START = 0x20
    I2C0_STOP = 0x21
    I2C0_DATA_RECEIVED = 0x22
    I2C0_ACK_ERROR = 0x23
    I2C1_START = 0x24
    I2C1_STOP = 0x25
    I2C1_DATA_RECEIVED = 0x26
    I2C1_ACK_ERROR = 0x27

    # SPI Events
    SPI0_CS_ACTIVE = 0x30
    SPI0_CS_INACTIVE = 0x31
    SPI0_DATA_RECEIVED = 0x32
    SPI0_TRANSFER_COMPLETE = 0x33
    SPI1_CS_ACTIVE = 0x34
    SPI1_CS_INACTIVE = 0x35
    SPI1_DATA_RECEIVED = 0x36
    SPI1_TRANSFER_COMPLETE = 0x37

    # UART Events
    UART_CMD_VALID = 0x40
    UART_CMD_ERROR = 0x41
    UART_CRC_ERROR = 0x42
    UART_TIMEOUT = 0x43

    # System Events
    SYSTEM_STATUS_CHANGE = 0x50
    REGISTER_WRITE = 0x51
    REGISTER_READ = 0x52

    # Custom Events
    CUSTOM_THRESHOLD = 0x60
    CUSTOM_CONDITION = 0x61


@dataclass
class IOEvent:
    """Data class for IO line events"""
    event_type: IOLineEvent
    timestamp: float
    data: Dict[str, Any] = field(default_factory=dict)
    channel: Optional[int] = None
    register_addr: Optional[int] = None
    value: Optional[int] = None

    def __str__(self):
        parts = [f"Event: {self.event_type.name}"]
        if self.channel is not None:
            parts.append(f"Channel: {self.channel}")
        if self.register_addr is not None:
            parts.append(f"Reg: 0x{self.register_addr:02X}")
        if self.value is not None:
            parts.append(f"Value: 0x{self.value:X}")
        if self.data:
            parts.append(f"Data: {self.data}")
        return f"<{', '.join(parts)} @ {self.timestamp:.3f}s>"


class UARTRegisterInterface:
    """
    UART Register Interface for FPGA Control

    Provides high-level methods to interact with FPGA control/status registers
    via UART with CRC-8 error detection.
    """

    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 1.0,
                 enable_events: bool = False, event_poll_interval: float = 0.1):
        """
        Initialize UART interface

        Args:
            port: Serial port name (e.g., 'COM3' on Windows, '/dev/ttyUSB0' on Linux)
            baudrate: UART baud rate (default 115200)
            timeout: Read timeout in seconds (default 1.0)
            enable_events: Enable automatic event monitoring (default False)
            event_poll_interval: Polling interval for event monitoring in seconds (default 0.1)
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.serial = None
        self._stats = {
            'commands_sent': 0,
            'responses_received': 0,
            'crc_errors': 0,
            'timeouts': 0,
        }

        # Event system
        self._enable_events = enable_events
        self._event_poll_interval = event_poll_interval
        self._event_handlers: Dict[IOLineEvent, List[Callable[[IOEvent], None]]] = defaultdict(list)
        self._custom_conditions: List[Tuple[str, Callable[[Any], bool], IOLineEvent]] = []
        self._event_monitor_thread: Optional[threading.Thread] = None
        self._event_monitor_running = False
        self._event_history: List[IOEvent] = []
        self._max_history_size = 1000
        self._event_lock = threading.Lock()

        # Previous state for change detection
        self._prev_state = {
            'i2c0_busy': False,
            'i2c1_busy': False,
            'spi0_busy': False,
            'spi1_busy': False,
            'system_status': None,
            'currents': None,
            'voltages': None,
        }

        # Start time for event timestamps
        self._start_time = time.time()

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

            # Start event monitoring if enabled
            if self._enable_events:
                self.start_event_monitoring()

        except serial.SerialException as e:
            raise ConnectionError(f"Failed to open {self.port}: {e}")

    def close(self):
        """Close the serial port"""
        # Stop event monitoring
        if self._event_monitor_running:
            self.stop_event_monitoring()

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

        # Build command packet: [CMD][ADDR][DATA0-7][CRC]
        packet = bytearray()
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

        # Emit event if monitoring is enabled
        if self._enable_events:
            event = IOEvent(
                event_type=IOLineEvent.REGISTER_WRITE,
                timestamp=time.time() - self._start_time,
                register_addr=address,
                value=value,
                data={'register': f'0x{address:02X}', 'value': f'0x{value:016X}'}
            )
            self._emit_event(event)

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

        # Build read command packet
        packet = bytearray()
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

        # Emit event if monitoring is enabled
        if self._enable_events:
            event = IOEvent(
                event_type=IOLineEvent.REGISTER_READ,
                timestamp=time.time() - self._start_time,
                register_addr=address,
                value=data,
                data={'register': f'0x{address:02X}', 'value': f'0x{data:016X}'}
            )
            self._emit_event(event)

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

    def get_statistics(self) -> dict:
        """Get communication statistics"""
        return self._stats.copy()

    def reset_statistics(self):
        """Reset communication statistics"""
        for key in self._stats:
            self._stats[key] = 0

    # ============ Event System Methods ============

    def register_event_handler(self, event_type: IOLineEvent, handler: Callable[[IOEvent], None]):
        """
        Register a callback function for a specific event type

        Args:
            event_type: Type of event to listen for
            handler: Callback function that takes an IOEvent parameter

        Example:
            def on_i2c_data(event):
                print(f"I2C data received: {event}")

            uart.register_event_handler(IOLineEvent.I2C0_DATA_RECEIVED, on_i2c_data)
        """
        with self._event_lock:
            self._event_handlers[event_type].append(handler)
            print(f"Registered handler for {event_type.name}")

    def unregister_event_handler(self, event_type: IOLineEvent, handler: Callable[[IOEvent], None]):
        """
        Unregister a callback function for a specific event type

        Args:
            event_type: Type of event
            handler: Callback function to remove
        """
        with self._event_lock:
            if handler in self._event_handlers[event_type]:
                self._event_handlers[event_type].remove(handler)
                print(f"Unregistered handler for {event_type.name}")

    def register_custom_condition(self, name: str, condition: Callable[[Any], bool],
                                  event_type: IOLineEvent = IOLineEvent.CUSTOM_CONDITION):
        """
        Register a custom condition that triggers an event

        Args:
            name: Name of the custom condition
            condition: Function that returns True when condition is met
            event_type: Event type to trigger (default: CUSTOM_CONDITION)

        Example:
            # Trigger event when current exceeds 1000
            uart.register_custom_condition(
                "high_current",
                lambda data: data.get('mon0', 0) > 1000,
                IOLineEvent.CUSTOM_THRESHOLD
            )
        """
        with self._event_lock:
            self._custom_conditions.append((name, condition, event_type))
            print(f"Registered custom condition: {name}")

    def _emit_event(self, event: IOEvent):
        """
        Emit an event to all registered handlers

        Args:
            event: The event to emit
        """
        with self._event_lock:
            # Add to history
            self._event_history.append(event)
            if len(self._event_history) > self._max_history_size:
                self._event_history.pop(0)

            # Call registered handlers
            handlers = self._event_handlers.get(event.event_type, [])
            for handler in handlers:
                try:
                    handler(event)
                except Exception as e:
                    print(f"Error in event handler: {e}")

    def _check_io_changes(self):
        """
        Check for changes in IO lines and emit appropriate events
        This runs periodically in the event monitoring thread
        """
        try:
            # Read system status
            status = self.read_system_status()
            if status and status != self._prev_state['system_status']:
                event = IOEvent(
                    event_type=IOLineEvent.SYSTEM_STATUS_CHANGE,
                    timestamp=time.time() - self._start_time,
                    data=status
                )
                self._emit_event(event)
                self._prev_state['system_status'] = status

            # Read current measurements
            currents = self.read_currents()
            if currents:
                # Check custom conditions on current data
                for name, condition, event_type in self._custom_conditions:
                    try:
                        if condition(currents):
                            event = IOEvent(
                                event_type=event_type,
                                timestamp=time.time() - self._start_time,
                                data={'condition': name, 'currents': currents}
                            )
                            self._emit_event(event)
                    except Exception as e:
                        print(f"Error in custom condition '{name}': {e}")

                self._prev_state['currents'] = currents

            # Read voltage measurements (includes I2C data)
            voltages = self.read_voltages()
            if voltages and voltages != self._prev_state['voltages']:
                # Check for I2C data changes
                if self._prev_state['voltages']:
                    if voltages.get('i2c0_rx') != self._prev_state['voltages'].get('i2c0_rx'):
                        event = IOEvent(
                            event_type=IOLineEvent.I2C0_DATA_RECEIVED,
                            timestamp=time.time() - self._start_time,
                            channel=0,
                            value=voltages['i2c0_rx'],
                            data={'i2c_data': voltages['i2c0_rx']}
                        )
                        self._emit_event(event)

                    if voltages.get('i2c1_rx') != self._prev_state['voltages'].get('i2c1_rx'):
                        event = IOEvent(
                            event_type=IOLineEvent.I2C1_DATA_RECEIVED,
                            timestamp=time.time() - self._start_time,
                            channel=1,
                            value=voltages['i2c1_rx'],
                            data={'i2c_data': voltages['i2c1_rx']}
                        )
                        self._emit_event(event)

                self._prev_state['voltages'] = voltages

        except Exception as e:
            print(f"Error checking IO changes: {e}")

    def _event_monitor_loop(self):
        """
        Event monitoring loop that runs in a separate thread
        """
        print("Event monitoring started")
        while self._event_monitor_running:
            self._check_io_changes()
            time.sleep(self._event_poll_interval)
        print("Event monitoring stopped")

    def start_event_monitoring(self):
        """Start the event monitoring thread"""
        if not self._event_monitor_running:
            self._event_monitor_running = True
            self._event_monitor_thread = threading.Thread(
                target=self._event_monitor_loop,
                daemon=True
            )
            self._event_monitor_thread.start()
            print("Event monitoring enabled")

    def stop_event_monitoring(self):
        """Stop the event monitoring thread"""
        if self._event_monitor_running:
            self._event_monitor_running = False
            if self._event_monitor_thread:
                self._event_monitor_thread.join(timeout=2.0)
            print("Event monitoring disabled")

    def get_event_history(self, event_type: Optional[IOLineEvent] = None,
                         limit: Optional[int] = None) -> List[IOEvent]:
        """
        Get event history

        Args:
            event_type: Filter by specific event type (None = all events)
            limit: Maximum number of events to return (None = all)

        Returns:
            List of IOEvent objects
        """
        with self._event_lock:
            events = self._event_history.copy()

        if event_type is not None:
            events = [e for e in events if e.event_type == event_type]

        if limit is not None:
            events = events[-limit:]

        return events

    def clear_event_history(self):
        """Clear the event history"""
        with self._event_lock:
            self._event_history.clear()
            print("Event history cleared")


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

            # 5. Display statistics
            print("\n=== Communication Statistics ===")
            stats = uart.get_statistics()
            for key, value in stats.items():
                print(f"   {key}: {value}")

    except Exception as e:
        print(f"Error: {e}")


if __name__ == '__main__':
    main()
