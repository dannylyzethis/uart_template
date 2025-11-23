#!/usr/bin/env python3
"""
IO Line Events Example for UART Register Interface

This script demonstrates how to use the event system to monitor
IO line changes and set up custom event handlers.

Features demonstrated:
- Event handler registration
- Custom condition monitoring
- Event history tracking
- Real-time IO line monitoring
"""

import sys
import os
import time

# Add parent directory to path to import uart_register_interface
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from uart_register_interface import (
    UARTRegisterInterface,
    RegisterAddress,
    IOLineEvent,
    IOEvent
)


# ============ Event Handler Examples ============

def on_i2c0_data_received(event: IOEvent):
    """Handler for I2C0 data received events"""
    print(f"[I2C0] Data received: 0x{event.value:04X} at {event.timestamp:.2f}s")


def on_i2c1_data_received(event: IOEvent):
    """Handler for I2C1 data received events"""
    print(f"[I2C1] Data received: 0x{event.value:04X} at {event.timestamp:.2f}s")


def on_system_status_change(event: IOEvent):
    """Handler for system status changes"""
    print(f"[SYSTEM] Status changed at {event.timestamp:.2f}s")
    print(f"  Temperature: {event.data.get('temperature', 0)}°C")
    print(f"  Error flags: 0x{event.data.get('error_flags', 0):02X}")


def on_register_write(event: IOEvent):
    """Handler for register write operations"""
    print(f"[WRITE] Register 0x{event.register_addr:02X} = 0x{event.value:016X}")


def on_register_read(event: IOEvent):
    """Handler for register read operations"""
    print(f"[READ] Register 0x{event.register_addr:02X} = 0x{event.value:016X}")


def on_custom_threshold(event: IOEvent):
    """Handler for custom threshold events"""
    print(f"[THRESHOLD] {event.data.get('condition', 'Unknown')} triggered!")
    print(f"  Current data: {event.data.get('currents', {})}")


# ============ Main Example ============

def run_io_events_example(port='/dev/ttyUSB0'):
    """Run IO line events demonstration"""

    print("=" * 70)
    print("  UART Register Interface - IO Line Events Example")
    print("=" * 70)
    print()

    # Create interface with event monitoring enabled
    # event_poll_interval controls how often IO lines are checked (in seconds)
    uart = UARTRegisterInterface(
        port=port,
        enable_events=True,
        event_poll_interval=0.2  # Check every 200ms
    )

    try:
        with uart:
            print("Connected to UART interface with event monitoring enabled")
            print()

            # ============ Register Event Handlers ============
            print("Registering event handlers...")

            # Register handlers for I2C events
            uart.register_event_handler(
                IOLineEvent.I2C0_DATA_RECEIVED,
                on_i2c0_data_received
            )
            uart.register_event_handler(
                IOLineEvent.I2C1_DATA_RECEIVED,
                on_i2c1_data_received
            )

            # Register handler for system status changes
            uart.register_event_handler(
                IOLineEvent.SYSTEM_STATUS_CHANGE,
                on_system_status_change
            )

            # Register handlers for register operations
            uart.register_event_handler(
                IOLineEvent.REGISTER_WRITE,
                on_register_write
            )
            uart.register_event_handler(
                IOLineEvent.REGISTER_READ,
                on_register_read
            )

            # Register handler for custom thresholds
            uart.register_event_handler(
                IOLineEvent.CUSTOM_THRESHOLD,
                on_custom_threshold
            )

            print()

            # ============ Register Custom Conditions ============
            print("Registering custom conditions...")

            # Trigger event when current monitor 0 exceeds 1000
            uart.register_custom_condition(
                "high_current_mon0",
                lambda data: data.get('mon0', 0) > 1000,
                IOLineEvent.CUSTOM_THRESHOLD
            )

            # Trigger event when any current monitor exceeds 2000
            uart.register_custom_condition(
                "very_high_current",
                lambda data: any(data.get(f'mon{i}', 0) > 2000 for i in range(4)),
                IOLineEvent.CUSTOM_THRESHOLD
            )

            # Trigger event when all currents are below 100 (idle state)
            uart.register_custom_condition(
                "idle_state",
                lambda data: all(data.get(f'mon{i}', 0) < 100 for i in range(4)),
                IOLineEvent.CUSTOM_CONDITION
            )

            print()
            print("=" * 70)
            print("  Monitoring IO Lines - Events will be displayed as they occur")
            print("  Press Ctrl+C to stop")
            print("=" * 70)
            print()

            # ============ Perform Some Operations ============

            # Write to some registers to generate events
            print("Performing register operations to generate events...")
            time.sleep(1)

            uart.write_register(RegisterAddress.CTRL_SYSTEM, 0x0000000000000001)
            time.sleep(0.5)

            uart.set_switches(bank0=0xABCD, bank1=0x1234, bank2=0x5678, bank3=0x9ABC)
            time.sleep(0.5)

            # Configure I2C to trigger some activity
            uart.write_i2c(channel=0, device_addr=0x50, data=0xAA)
            time.sleep(0.5)

            uart.write_i2c(channel=1, device_addr=0x51, data=0xBB)
            time.sleep(0.5)

            # Read status registers
            uart.read_system_status()
            time.sleep(0.5)

            uart.read_currents()
            time.sleep(0.5)

            uart.read_voltages()
            time.sleep(0.5)

            print()
            print("=" * 70)
            print("  Continuous monitoring active...")
            print("=" * 70)
            print()

            # Continue monitoring for a while
            for i in range(30):
                time.sleep(1)

                # Perform periodic reads to check for changes
                if i % 3 == 0:
                    status = uart.read_system_status()
                if i % 5 == 0:
                    currents = uart.read_currents()
                if i % 7 == 0:
                    voltages = uart.read_voltages()

            print()
            print("=" * 70)
            print("  Event History Summary")
            print("=" * 70)

            # Get event history
            all_events = uart.get_event_history()
            print(f"\nTotal events captured: {len(all_events)}")

            # Show event breakdown by type
            event_counts = {}
            for event in all_events:
                event_type_name = event.event_type.name
                event_counts[event_type_name] = event_counts.get(event_type_name, 0) + 1

            print("\nEvent breakdown:")
            for event_type, count in sorted(event_counts.items()):
                print(f"  {event_type:30s}: {count:3d} events")

            # Show recent I2C events
            i2c_events = [
                e for e in all_events
                if e.event_type in [IOLineEvent.I2C0_DATA_RECEIVED, IOLineEvent.I2C1_DATA_RECEIVED]
            ]
            if i2c_events:
                print(f"\nRecent I2C events (last 5):")
                for event in i2c_events[-5:]:
                    print(f"  {event}")

            # Show recent custom condition triggers
            custom_events = [
                e for e in all_events
                if e.event_type in [IOLineEvent.CUSTOM_THRESHOLD, IOLineEvent.CUSTOM_CONDITION]
            ]
            if custom_events:
                print(f"\nCustom condition events (last 5):")
                for event in custom_events[-5:]:
                    print(f"  {event}")

            print()
            print("=" * 70)
            print("  Communication Statistics")
            print("=" * 70)
            stats = uart.get_statistics()
            print(f"  Commands sent:      {stats['commands_sent']}")
            print(f"  Responses received: {stats['responses_received']}")
            print(f"  CRC errors:         {stats['crc_errors']}")
            print(f"  Timeouts:           {stats['timeouts']}")

            success_rate = 0
            if stats['commands_sent'] > 0:
                success_rate = (stats['responses_received'] / stats['commands_sent']) * 100
            print(f"  Success rate:       {success_rate:.1f}%")

            print()
            print("Demonstration completed successfully!")

    except KeyboardInterrupt:
        print("\n\nMonitoring interrupted by user")
        print("\nFinal event count:", len(uart.get_event_history()))

    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()


# ============ Advanced Example: Custom Event Handler Class ============

class CustomEventMonitor:
    """
    Example class that demonstrates more complex event handling
    """

    def __init__(self, uart: UARTRegisterInterface):
        self.uart = uart
        self.i2c_transaction_count = 0
        self.error_count = 0
        self.register_modifications = []

        # Register handlers
        self.uart.register_event_handler(IOLineEvent.I2C0_DATA_RECEIVED, self.on_i2c_transaction)
        self.uart.register_event_handler(IOLineEvent.I2C1_DATA_RECEIVED, self.on_i2c_transaction)
        self.uart.register_event_handler(IOLineEvent.UART_CRC_ERROR, self.on_error)
        self.uart.register_event_handler(IOLineEvent.UART_TIMEOUT, self.on_error)
        self.uart.register_event_handler(IOLineEvent.REGISTER_WRITE, self.on_register_write)

    def on_i2c_transaction(self, event: IOEvent):
        """Track I2C transactions"""
        self.i2c_transaction_count += 1
        print(f"[Monitor] I2C transaction #{self.i2c_transaction_count} on channel {event.channel}")

    def on_error(self, event: IOEvent):
        """Track errors"""
        self.error_count += 1
        print(f"[Monitor] Error detected: {event.event_type.name} (total: {self.error_count})")

    def on_register_write(self, event: IOEvent):
        """Track register modifications"""
        self.register_modifications.append({
            'timestamp': event.timestamp,
            'register': event.register_addr,
            'value': event.value
        })

    def print_summary(self):
        """Print monitoring summary"""
        print("\n" + "=" * 70)
        print("  Custom Monitor Summary")
        print("=" * 70)
        print(f"  I2C transactions: {self.i2c_transaction_count}")
        print(f"  Errors detected:  {self.error_count}")
        print(f"  Registers modified: {len(self.register_modifications)}")
        if self.register_modifications:
            print("\n  Recent register writes:")
            for mod in self.register_modifications[-5:]:
                print(f"    0x{mod['register']:02X} = 0x{mod['value']:016X} @ {mod['timestamp']:.2f}s")


def run_advanced_example(port='/dev/ttyUSB0'):
    """Run advanced event monitoring example"""

    print("=" * 70)
    print("  Advanced Event Monitoring Example")
    print("=" * 70)

    with UARTRegisterInterface(port=port, enable_events=True) as uart:
        # Create custom monitor
        monitor = CustomEventMonitor(uart)

        print("\nPerforming operations...")

        # Perform various operations
        for i in range(5):
            uart.write_register(RegisterAddress.CTRL_SYSTEM, i)
            uart.write_i2c(channel=0, device_addr=0x50, data=i)
            time.sleep(0.2)

        # Print summary
        monitor.print_summary()


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='UART IO Line Events Example')
    parser.add_argument('--port', type=str, default='/dev/ttyUSB0',
                       help='Serial port (default: /dev/ttyUSB0)')
    parser.add_argument('--advanced', action='store_true',
                       help='Run advanced example instead of basic')

    args = parser.parse_args()

    try:
        if args.advanced:
            run_advanced_example(port=args.port)
        else:
            run_io_events_example(port=args.port)

    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
