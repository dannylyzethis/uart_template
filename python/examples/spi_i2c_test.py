#!/usr/bin/env python3
"""
SPI and I2C Test Example

Demonstrates SPI and I2C peripheral control via UART interface.
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from uart_register_interface import UARTRegisterInterface
import time


def test_i2c(uart):
    """Test I2C communication"""
    print("\n" + "="*60)
    print("  I2C Communication Test")
    print("="*60)

    # Write to I2C device on channel 0
    print("\n1. Writing to I2C0 (addr=0x50, data=0xAA)...")
    uart.write_i2c(channel=0, device_addr=0x50, data=0xAA)
    time.sleep(0.5)  # Wait for transaction to complete
    print("  ✓ I2C0 write completed")

    # Write to I2C device on channel 1
    print("\n2. Writing to I2C1 (addr=0x51, data=0x55)...")
    uart.write_i2c(channel=1, device_addr=0x51, data=0x55)
    time.sleep(0.5)
    print("  ✓ I2C1 write completed")

    # Read back I2C received data from status register
    print("\n3. Reading I2C received data...")
    voltages = uart.read_voltages()
    if voltages:
        print(f"  I2C0 RX: 0x{voltages.get('i2c0_rx', 0):04X}")
        print(f"  I2C1 RX: 0x{voltages.get('i2c1_rx', 0):04X}")


def test_spi(uart):
    """Test SPI communication"""
    print("\n" + "="*60)
    print("  SPI Communication Test")
    print("="*60)

    # Configure SPI0: Mode 0 (CPOL=0, CPHA=0), 16-bit, 1MHz
    print("\n1. Configuring SPI0...")
    print("   Mode: 0 (CPOL=0, CPHA=0)")
    print("   Word Length: 16 bits")
    print("   Clock Divider: 100 (1MHz at 100MHz system clock)")
    print("   Chip Select: CS0")

    uart.configure_spi(
        channel=0,
        cpol=False,
        cpha=False,
        word_len=16,
        clk_div=100,
        chip_select=0
    )
    time.sleep(0.1)
    print("  ✓ SPI0 configured")

    # Write data to SPI0
    print("\n2. Writing data to SPI0...")
    test_data = 0xDEADBEEF
    print(f"   Data: 0x{test_data:08X}")
    uart.write_spi(channel=0, data=test_data)
    time.sleep(0.5)  # Wait for transaction
    print("  ✓ SPI0 write completed")

    # Configure SPI1: Mode 3 (CPOL=1, CPHA=1), 32-bit, 2MHz
    print("\n3. Configuring SPI1...")
    print("   Mode: 3 (CPOL=1, CPHA=1)")
    print("   Word Length: 32 bits")
    print("   Clock Divider: 50 (2MHz at 100MHz system clock)")
    print("   Chip Select: CS1")

    uart.configure_spi(
        channel=1,
        cpol=True,
        cpha=True,
        word_len=32,
        clk_div=50,
        chip_select=1
    )
    time.sleep(0.1)
    print("  ✓ SPI1 configured")

    # Write data to SPI1
    print("\n4. Writing data to SPI1...")
    test_data = 0xCAFEBABE
    print(f"   Data: 0x{test_data:08X}")
    uart.write_spi(channel=1, data=test_data)
    time.sleep(0.5)
    print("  ✓ SPI1 write completed")

    # Read back SPI received data
    print("\n5. Reading SPI received data...")
    value = uart.read_register(0x13)  # SPI data status register
    if value is not None:
        spi0_rx = (value >> 32) & 0xFFFFFFFF
        spi1_rx = value & 0xFFFFFFFF
        print(f"   SPI0 RX: 0x{spi0_rx:08X}")
        print(f"   SPI1 RX: 0x{spi1_rx:08X}")


def main():
    """Main test function"""
    import argparse

    parser = argparse.ArgumentParser(description='SPI/I2C Test via UART Interface')
    parser.add_argument('--port', type=str, default='/dev/ttyUSB0',
                       help='Serial port (default: /dev/ttyUSB0)')
    parser.add_argument('--test', type=str, choices=['i2c', 'spi', 'both'], default='both',
                       help='Test to run (default: both)')

    args = parser.parse_args()

    print("="*60)
    print("  SPI/I2C Communication Test")
    print("="*60)
    print(f"  Port: {args.port}")
    print(f"  Test: {args.test}")

    try:
        with UARTRegisterInterface(port=args.port) as uart:

            # Enable system
            print("\nEnabling system...")
            uart.set_system_control(reset=False, enable=True)
            time.sleep(0.1)

            # Run selected tests
            if args.test in ['i2c', 'both']:
                test_i2c(uart)

            if args.test in ['spi', 'both']:
                test_spi(uart)

            # Display statistics
            print("\n" + "="*60)
            print("  Communication Statistics")
            print("="*60)
            stats = uart.get_statistics()
            print(f"  Commands sent:      {stats['commands_sent']}")
            print(f"  Responses received: {stats['responses_received']}")
            print(f"  CRC errors:         {stats['crc_errors']}")
            print(f"  Timeouts:           {stats['timeouts']}")

            print("\n✓ All tests completed!")

    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
