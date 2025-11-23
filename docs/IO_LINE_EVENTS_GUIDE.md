# IO Line Events Guide

## Overview

The UART Register Interface now includes a powerful event system that allows you to monitor IO line changes in real-time and set up custom event handlers. This enables reactive programming patterns and automated responses to hardware state changes.

## Features

- **Real-time IO Monitoring**: Automatically detect changes on I2C, SPI, and system status lines
- **Event Callbacks**: Register custom handler functions for specific event types
- **Custom Conditions**: Define custom conditions that trigger events (e.g., threshold monitoring)
- **Event History**: Automatic tracking of all events with timestamps
- **Thread-safe**: Event system runs in a separate thread for non-blocking operation
- **Customizable Polling**: Adjust monitoring frequency based on your needs

## Quick Start

### Basic Event Monitoring

```python
from uart_register_interface import UARTRegisterInterface, IOLineEvent

# Create interface with events enabled
with UARTRegisterInterface(port='/dev/ttyUSB0', enable_events=True) as uart:
    # Define event handler
    def on_i2c_data(event):
        print(f"I2C data received: 0x{event.value:04X}")

    # Register handler
    uart.register_event_handler(IOLineEvent.I2C0_DATA_RECEIVED, on_i2c_data)

    # Event handler will be called automatically when I2C data is received
    # Continue with normal operations...
```

### Manual Event Monitoring Control

```python
# Create interface without auto-starting events
uart = UARTRegisterInterface(port='/dev/ttyUSB0', enable_events=False)
uart.open()

# Register handlers
uart.register_event_handler(IOLineEvent.SYSTEM_STATUS_CHANGE, my_handler)

# Start monitoring when ready
uart.start_event_monitoring()

# ... do work ...

# Stop monitoring
uart.stop_event_monitoring()
uart.close()
```

## Available Event Types

### I2C Events

| Event Type | Description |
|------------|-------------|
| `I2C0_START` | I2C channel 0 transaction started |
| `I2C0_STOP` | I2C channel 0 transaction completed |
| `I2C0_DATA_RECEIVED` | Data received on I2C channel 0 |
| `I2C0_ACK_ERROR` | ACK error on I2C channel 0 |
| `I2C1_START` | I2C channel 1 transaction started |
| `I2C1_STOP` | I2C channel 1 transaction completed |
| `I2C1_DATA_RECEIVED` | Data received on I2C channel 1 |
| `I2C1_ACK_ERROR` | ACK error on I2C channel 1 |

### SPI Events

| Event Type | Description |
|------------|-------------|
| `SPI0_CS_ACTIVE` | SPI channel 0 chip select activated |
| `SPI0_CS_INACTIVE` | SPI channel 0 chip select deactivated |
| `SPI0_DATA_RECEIVED` | Data received on SPI channel 0 |
| `SPI0_TRANSFER_COMPLETE` | SPI channel 0 transfer completed |
| `SPI1_CS_ACTIVE` | SPI channel 1 chip select activated |
| `SPI1_CS_INACTIVE` | SPI channel 1 chip select deactivated |
| `SPI1_DATA_RECEIVED` | Data received on SPI channel 1 |
| `SPI1_TRANSFER_COMPLETE` | SPI channel 1 transfer completed |

### UART Events

| Event Type | Description |
|------------|-------------|
| `UART_CMD_VALID` | Valid UART command received |
| `UART_CMD_ERROR` | UART command error detected |
| `UART_CRC_ERROR` | CRC error on UART communication |
| `UART_TIMEOUT` | UART timeout occurred |

### System Events

| Event Type | Description |
|------------|-------------|
| `SYSTEM_STATUS_CHANGE` | System status register changed |
| `REGISTER_WRITE` | Register write operation performed |
| `REGISTER_READ` | Register read operation performed |

### Custom Events

| Event Type | Description |
|------------|-------------|
| `CUSTOM_THRESHOLD` | Custom threshold condition met |
| `CUSTOM_CONDITION` | Custom condition triggered |

## Event Data Structure

Each event is represented by an `IOEvent` object with the following attributes:

```python
@dataclass
class IOEvent:
    event_type: IOLineEvent    # Type of event
    timestamp: float            # Time since interface opened (seconds)
    data: Dict[str, Any]        # Event-specific data
    channel: Optional[int]      # Channel number (for I2C/SPI events)
    register_addr: Optional[int] # Register address (for register events)
    value: Optional[int]        # Event value
```

## Event Handlers

### Registering Event Handlers

```python
def my_event_handler(event: IOEvent):
    print(f"Event: {event.event_type.name}")
    print(f"Time: {event.timestamp:.3f}s")
    print(f"Data: {event.data}")

uart.register_event_handler(IOLineEvent.SYSTEM_STATUS_CHANGE, my_event_handler)
```

### Unregistering Event Handlers

```python
uart.unregister_event_handler(IOLineEvent.SYSTEM_STATUS_CHANGE, my_event_handler)
```

### Multiple Handlers for Same Event

You can register multiple handlers for the same event type:

```python
uart.register_event_handler(IOLineEvent.I2C0_DATA_RECEIVED, handler1)
uart.register_event_handler(IOLineEvent.I2C0_DATA_RECEIVED, handler2)
uart.register_event_handler(IOLineEvent.I2C0_DATA_RECEIVED, handler3)

# All three handlers will be called when event occurs
```

## Custom Conditions

Custom conditions allow you to define your own monitoring logic and trigger events when specific conditions are met.

### Threshold Monitoring

```python
# Trigger event when current exceeds threshold
uart.register_custom_condition(
    "high_current",
    lambda data: data.get('mon0', 0) > 1000,
    IOLineEvent.CUSTOM_THRESHOLD
)

# Register handler for threshold events
def on_threshold(event):
    print(f"Threshold '{event.data['condition']}' triggered!")
    print(f"Current values: {event.data['currents']}")

uart.register_event_handler(IOLineEvent.CUSTOM_THRESHOLD, on_threshold)
```

### Complex Conditions

```python
# Trigger when any current monitor exceeds 2000
uart.register_custom_condition(
    "very_high_current",
    lambda data: any(data.get(f'mon{i}', 0) > 2000 for i in range(4)),
    IOLineEvent.CUSTOM_THRESHOLD
)

# Trigger when system is in idle state
uart.register_custom_condition(
    "idle_state",
    lambda data: all(data.get(f'mon{i}', 0) < 100 for i in range(4)),
    IOLineEvent.CUSTOM_CONDITION
)

# Trigger when specific combination occurs
def complex_condition(data):
    return (data.get('mon0', 0) > 500 and
            data.get('mon1', 0) < 200 and
            data.get('mon2', 0) > data.get('mon3', 0))

uart.register_custom_condition("complex", complex_condition)
```

## Event History

The event system automatically maintains a history of all events (default: last 1000 events).

### Getting Event History

```python
# Get all events
all_events = uart.get_event_history()

# Get events of specific type
i2c_events = uart.get_event_history(event_type=IOLineEvent.I2C0_DATA_RECEIVED)

# Get last N events
recent_events = uart.get_event_history(limit=10)

# Get last 5 I2C events
recent_i2c = uart.get_event_history(
    event_type=IOLineEvent.I2C0_DATA_RECEIVED,
    limit=5
)
```

### Clearing Event History

```python
uart.clear_event_history()
```

## Configuration

### Polling Interval

Control how often the IO lines are checked for changes:

```python
# Check every 100ms (faster response, higher CPU usage)
uart = UARTRegisterInterface(
    port='/dev/ttyUSB0',
    enable_events=True,
    event_poll_interval=0.1
)

# Check every 500ms (slower response, lower CPU usage)
uart = UARTRegisterInterface(
    port='/dev/ttyUSB0',
    enable_events=True,
    event_poll_interval=0.5
)
```

### Maximum History Size

The default history size is 1000 events. You can modify this:

```python
uart = UARTRegisterInterface(port='/dev/ttyUSB0', enable_events=True)
uart._max_history_size = 5000  # Store last 5000 events
```

## Advanced Usage Examples

### Example 1: Data Logger

```python
import csv
from datetime import datetime

class DataLogger:
    def __init__(self, filename):
        self.filename = filename
        self.file = open(filename, 'w', newline='')
        self.writer = csv.writer(self.file)
        self.writer.writerow(['Timestamp', 'Event', 'Channel', 'Value'])

    def log_event(self, event: IOEvent):
        self.writer.writerow([
            datetime.now().isoformat(),
            event.event_type.name,
            event.channel or '',
            event.value or ''
        ])
        self.file.flush()

    def close(self):
        self.file.close()

# Usage
logger = DataLogger('events.csv')
with UARTRegisterInterface(port='/dev/ttyUSB0', enable_events=True) as uart:
    uart.register_event_handler(IOLineEvent.I2C0_DATA_RECEIVED, logger.log_event)
    uart.register_event_handler(IOLineEvent.I2C1_DATA_RECEIVED, logger.log_event)

    # ... perform operations ...

logger.close()
```

### Example 2: Alert System

```python
import smtplib
from email.message import EmailMessage

class AlertSystem:
    def __init__(self, email_to):
        self.email_to = email_to
        self.alert_count = 0

    def on_error(self, event: IOEvent):
        self.alert_count += 1
        print(f"ALERT: {event.event_type.name} detected!")

        if self.alert_count >= 3:
            self.send_email(f"Multiple errors detected: {self.alert_count}")

    def send_email(self, message):
        # Email sending logic here
        print(f"Sending alert email: {message}")

# Usage
alerts = AlertSystem('admin@example.com')
with UARTRegisterInterface(port='/dev/ttyUSB0', enable_events=True) as uart:
    uart.register_event_handler(IOLineEvent.UART_CRC_ERROR, alerts.on_error)
    uart.register_event_handler(IOLineEvent.UART_TIMEOUT, alerts.on_error)

    # ... perform operations ...
```

### Example 3: State Machine

```python
from enum import Enum

class SystemState(Enum):
    IDLE = 1
    ACTIVE = 2
    ERROR = 3

class StateMachine:
    def __init__(self):
        self.state = SystemState.IDLE

    def on_system_change(self, event: IOEvent):
        error_flags = event.data.get('error_flags', 0)

        if error_flags != 0:
            self.transition_to(SystemState.ERROR)
        elif self.state == SystemState.ERROR and error_flags == 0:
            self.transition_to(SystemState.IDLE)

    def on_i2c_activity(self, event: IOEvent):
        if self.state == SystemState.IDLE:
            self.transition_to(SystemState.ACTIVE)

    def transition_to(self, new_state):
        if self.state != new_state:
            print(f"State transition: {self.state.name} -> {new_state.name}")
            self.state = new_state

# Usage
sm = StateMachine()
with UARTRegisterInterface(port='/dev/ttyUSB0', enable_events=True) as uart:
    uart.register_event_handler(IOLineEvent.SYSTEM_STATUS_CHANGE, sm.on_system_change)
    uart.register_event_handler(IOLineEvent.I2C0_DATA_RECEIVED, sm.on_i2c_activity)
    uart.register_event_handler(IOLineEvent.I2C1_DATA_RECEIVED, sm.on_i2c_activity)

    # ... perform operations ...
```

## Thread Safety

The event system is thread-safe. All event handler registrations and event emissions are protected by locks. Event handlers are called in the monitoring thread, so be mindful of thread safety in your handler code.

```python
import threading

class ThreadSafeCounter:
    def __init__(self):
        self.count = 0
        self.lock = threading.Lock()

    def on_event(self, event):
        with self.lock:
            self.count += 1
            print(f"Event count: {self.count}")

counter = ThreadSafeCounter()
uart.register_event_handler(IOLineEvent.I2C0_DATA_RECEIVED, counter.on_event)
```

## Best Practices

1. **Keep handlers lightweight**: Event handlers are called in the monitoring thread. Avoid heavy processing in handlers.

2. **Handle exceptions**: Always handle exceptions in your event handlers to prevent crashes.

   ```python
   def safe_handler(event):
       try:
           # Your handling code
           process_event(event)
       except Exception as e:
           print(f"Error in handler: {e}")
   ```

3. **Adjust polling interval**: Balance between responsiveness and CPU usage.

4. **Use appropriate event types**: Choose the most specific event type for your needs.

5. **Monitor event history size**: If running for extended periods, consider clearing history periodically.

   ```python
   # Clear history every hour
   import time
   last_clear = time.time()

   while running:
       if time.time() - last_clear > 3600:
           uart.clear_event_history()
           last_clear = time.time()
   ```

6. **Unregister handlers**: Clean up by unregistering handlers when no longer needed.

## Performance Considerations

- **Polling overhead**: Each poll reads multiple registers. Adjust `event_poll_interval` based on your needs.
- **Handler execution**: Handlers run in the monitoring thread and block other event processing.
- **History memory**: Each event consumes memory. Monitor history size for long-running applications.

## Troubleshooting

### Events not firing

1. Verify event monitoring is enabled: `enable_events=True`
2. Check that monitoring thread is running: `uart._event_monitor_running`
3. Verify handler registration: Check for typos in event type names
4. Ensure polling interval is appropriate for your application

### High CPU usage

1. Increase `event_poll_interval` (e.g., from 0.1 to 0.5 seconds)
2. Optimize handler code to be more efficient
3. Consider reducing number of custom conditions

### Missing events

1. Events may be too fast for polling interval - decrease `event_poll_interval`
2. Check event history to see if events were captured but not handled
3. Verify UART communication is working properly

### Memory usage growing

1. History is growing unbounded - call `clear_event_history()` periodically
2. Reduce `_max_history_size` if needed
3. Unregister unused handlers

## Examples

See the following example scripts for complete working examples:

- `python/examples/io_line_events_example.py` - Comprehensive event system demonstration
- `python/examples/basic_test.py` - Basic usage without events

## API Reference

### UARTRegisterInterface Event Methods

| Method | Description |
|--------|-------------|
| `register_event_handler(event_type, handler)` | Register callback for event type |
| `unregister_event_handler(event_type, handler)` | Remove callback |
| `register_custom_condition(name, condition, event_type)` | Register custom condition |
| `start_event_monitoring()` | Start monitoring thread |
| `stop_event_monitoring()` | Stop monitoring thread |
| `get_event_history(event_type, limit)` | Get event history |
| `clear_event_history()` | Clear event history |

### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enable_events` | bool | False | Enable automatic event monitoring |
| `event_poll_interval` | float | 0.1 | Polling interval in seconds |

## See Also

- [UART Register Interface Specification](UART_Register_Interface_Specification.md)
- [Quick Start Guide](QUICK_START.md)
- [Python API Reference](../python/uart_register_interface.py)
