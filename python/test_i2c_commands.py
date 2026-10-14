"""Offline wire-format tests; serial hardware/dependency is deliberately mocked."""
import sys
import unittest
from unittest.mock import Mock, patch

with patch.dict(sys.modules, {"serial": Mock()}):
    from uart_register_interface import UARTRegisterInterface


class I2CCommandsTest(unittest.TestCase):
    def setUp(self):
        self.uart = UARTRegisterInterface("unused")
        self.uart.serial = Mock(is_open=True)

    def check_packet(self, prefix):
        packet = bytes(self.uart.serial.write.call_args.args[0])
        self.assertEqual(packet[:10], bytes.fromhex(prefix))
        self.assertEqual(len(packet), 11)
        # CRC-8 residue over the transmitted packet must be zero.
        crc = 0
        for byte in packet:
            crc ^= byte
            for _ in range(8):
                crc = ((crc << 1) ^ (0x07 if crc & 0x80 else 0)) & 0xFF
        self.assertEqual(crc, 0)

    def test_channel_zero_read(self):
        self.assertTrue(self.uart.start_i2c_read(0, 0x50))
        self.check_packet("01 02 D0 80 00 00 00 00 00 00")

    def test_channel_one_read(self):
        self.assertTrue(self.uart.start_i2c_read(1, 0x51))
        self.check_packet("01 02 00 00 00 00 D1 80 00 00")

    def test_existing_write_encoding(self):
        self.uart.write_i2c(0, 0x50, 0x12)
        self.check_packet("01 02 D0 00 00 00 00 00 12 00")
        self.uart.write_i2c(1, 0x51, 0x34)
        self.check_packet("01 02 00 00 00 00 D1 00 00 34")

    def test_invalid_read_parameters_send_nothing(self):
        for channel, address in ((-1, 0x50), (2, 0x50), (0, -1), (1, 128)):
            with self.subTest(channel=channel, address=address):
                with self.assertRaises(ValueError):
                    self.uart.start_i2c_read(channel, address)
        self.uart.serial.write.assert_not_called()


if __name__ == "__main__":
    unittest.main()
