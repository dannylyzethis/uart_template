"""Offline tests for FIFO register wire format, decoding and sticky flags."""
import sys
import unittest
from unittest.mock import Mock, patch

with patch.dict(sys.modules, {"serial": Mock()}):
    from uart_register_interface import UARTRegisterInterface, ErrorFlag


def crc8(data):
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ (7 if crc & 128 else 0)) & 255
    return crc


class FIFOStatusTest(unittest.TestCase):
    def setUp(self):
        self.uart = UARTRegisterInterface("unused")
        self.uart.serial = Mock(is_open=True)

    def respond(self, value):
        data = bytes([2]) + value.to_bytes(8, 'big')
        self.uart.serial.read.return_value = data + bytes([crc8(data)])

    def check_request(self, address):
        packet = bytes(self.uart.serial.write.call_args.args[0])
        self.assertEqual(packet[:10], bytes([2, address]) + bytes(8))
        self.assertEqual(len(packet), 11)
        self.assertEqual(crc8(packet), 0)

    def test_capacity_wire_format(self):
        self.respond((64 << 16) | 3)
        self.assertEqual(self.uart.read_fifo_capacity(), {'rx_depth': 3, 'tx_depth': 64})
        self.check_request(0x18)

    def test_status_flags_and_levels(self):
        for bit in range(4):
            with self.subTest(bit=bit):
                self.respond((1 << (32 + bit)) | (16 << 16) | 7)
                status = self.uart.read_fifo_status()
                self.assertEqual(status['rx_level'], 7)
                self.assertEqual(status['tx_level'], 16)
                for index, key in enumerate(('tx_busy', 'rx_recovering', 'rx_full', 'tx_full')):
                    self.assertEqual(status[key], index == bit)
                self.check_request(0x17)

    def test_overflow_flags_and_clear(self):
        self.respond(0x300)
        self.assertEqual(self.uart.read_error_flags(), ErrorFlag.RX_OVERFLOW | ErrorFlag.TX_OVERFLOW)
        self.uart.clear_error_flags(ErrorFlag.RX_OVERFLOW)
        packet = bytes(self.uart.serial.write.call_args.args[0])
        self.assertEqual(packet[:10], bytes.fromhex('01 06 00 00 00 00 00 00 01 00'))
        self.assertEqual(crc8(packet), 0)

    def test_missing_and_corrupt_responses(self):
        for response in (b'', bytes(10)):
            self.uart.serial.read.return_value = response
            self.assertEqual(self.uart.read_fifo_status(), {})
            self.assertEqual(self.uart.read_fifo_capacity(), {})

    def test_invalid_address(self):
        with self.assertRaises(ValueError):
            self.uart.read_register(0x19)
        self.uart.serial.write.assert_not_called()


if __name__ == '__main__':
    unittest.main()
