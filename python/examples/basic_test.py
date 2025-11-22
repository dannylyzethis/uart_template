#!/usr/bin/env python3
"""
Basic Test Example for UART Register Interface

This script demonstrates basic register read/write operations.
"""

import sys
import os

# Add parent directory to path to import uart_register_interface
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from uart_register_interface import UARTRegisterInterface, RegisterAddress
import time


def run_basic_test(port='/dev/ttyUSB0'):
    """Run basic register read/write test"""

    print("="*60)
    print("  UART Register Interface - Basic Test")
    print("="*60)

    with UARTRegisterInterface(port=port) as uart:

        # Test 1: Write and verify control register
        print("\nTest 1: Write Control Register 0")
        test_value = 0x123456789ABCDEF0
        print(f"  Writing: 0x{test_value:016X}")
        uart.write_register(RegisterAddress.CTRL_SYSTEM, test_value)
        time.sleep(0.1)
        print("  ✓ Write successful")

        # Test 2: Write switch control
        print("\nTest 2: Set Switch Positions")
        uart.set_switches(bank0=0x0001, bank1=0x0002, bank2=0x0004, bank3=0x0008)
        time.sleep(0.1)
        print("  ✓ Switches configured")

        # Test 3: Read all status registers
        print("\nTest 3: Read All Status Registers")
        for addr in range(0x10, 0x16):
            value = uart.read_register(addr)
            if value is not None:
                print(f"  Reg 0x{addr:02X}: 0x{value:016X}")
            else:
                print(f"  Reg 0x{addr:02X}: [Read Error]")
            time.sleep(0.05)

        # Test 4: System status detailed read
        print("\nTest 4: System Status Details")
        status = uart.read_system_status()
        if status:
            print(f"  Timestamp:    {status.get('timestamp', 0)} seconds")
            print(f"  Bus Status:   0x{status.get('bus_status', 0):02X}")
            print(f"  Error Flags:  0x{status.get('error_flags', 0):02X}")
            print(f"  Temperature:  {status.get('temperature', 0)}°C")
            print(f"  Status Bits:  0x{status.get('status_bits', 0):02X}")

        # Test 5: Current measurements
        print("\nTest 5: Current Measurements")
        currents = uart.read_currents()
        if currents:
            for i in range(4):
                current_ua = currents.get(f'mon{i}', 0)
                print(f"  Monitor {i}: {current_ua} µA")

        # Test 6: Voltage measurements
        print("\nTest 6: Voltage Measurements")
        voltages = uart.read_voltages()
        if voltages:
            print(f"  Voltage 0: {voltages.get('volt0', 0)} mV")
            print(f"  Voltage 1: {voltages.get('volt1', 0)} mV")

        # Display statistics
        print("\n" + "="*60)
        print("  Communication Statistics")
        print("="*60)
        stats = uart.get_statistics()
        print(f"  Commands sent:      {stats['commands_sent']}")
        print(f"  Responses received: {stats['responses_received']}")
        print(f"  CRC errors:         {stats['crc_errors']}")
        print(f"  Timeouts:           {stats['timeouts']}")

        success_rate = 0
        if stats['commands_sent'] > 0:
            success_rate = (stats['responses_received'] / stats['commands_sent']) * 100
        print(f"  Success rate:       {success_rate:.1f}%")

        print("\n✓ Test completed successfully!")


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='UART Register Interface Basic Test')
    parser.add_argument('--port', type=str, default='/dev/ttyUSB0',
                       help='Serial port (default: /dev/ttyUSB0)')

    args = parser.parse_args()

    try:
        run_basic_test(port=args.port)
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)
