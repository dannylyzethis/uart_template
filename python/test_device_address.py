"""Addressed UART wire format and response validation without hardware."""
import sys
import unittest
from unittest.mock import Mock, patch

with patch.dict(sys.modules, {"serial": Mock()}):
    from uart_register_interface import UARTRegisterInterface
from test_fifo_status import crc8


class DeviceAddressTest(unittest.TestCase):
    def make_uart(self, address=0x16):
        uart = UARTRegisterInterface("unused", device_address=address)
        uart.serial = Mock(is_open=True)
        return uart

    def response(self, address, value, header=2):
        body = bytes([address, header]) + value.to_bytes(8, 'big')
        return body + bytes([crc8(body)])

    def test_default_and_custom_write_packets(self):
        for address in (0x16, 0xA5, 0, 255):
            with self.subTest(address=address):
                uart = self.make_uart(address)
                uart.write_register(0, 0x0123456789ABCDEF)
                packet = bytes(uart.serial.write.call_args.args[0])
                self.assertEqual(packet[:11], bytes([address, 1, 0]) + bytes.fromhex('0123456789ABCDEF'))
                self.assertEqual(len(packet), 12)
                self.assertEqual(crc8(packet), 0)

    def test_custom_read_request_and_reply(self):
        uart = self.make_uart(0xA5)
        uart.serial.read.return_value = self.response(0xA5, 0x0123456789ABCDEF)
        self.assertEqual(uart.read_register(0x10), 0x0123456789ABCDEF)
        packet = bytes(uart.serial.write.call_args.args[0])
        self.assertEqual(packet[:11], bytes([0xA5, 2, 0x10]) + bytes(8))
        self.assertEqual(crc8(packet), 0)
        uart.serial.read.assert_called_once_with(11)

    def test_wrong_device_header_crc_and_legacy_reply(self):
        uart = self.make_uart()
        good = self.response(0x16, 0x0123456789ABCDEF)
        for response in (self.response(0x17, 1), self.response(0x16, 1, header=1),
                         good[:-1] + bytes([good[-1] ^ 1]), good[1:]):
            with self.subTest(response=response):
                uart.serial.read.return_value = response
                self.assertIsNone(uart.read_register(0x10))
        self.assertEqual(uart.get_statistics()['responses_received'], 0)
        self.assertEqual(uart.get_statistics()['crc_errors'], 1)

    def test_address_byte_is_crc_protected(self):
        uart = self.make_uart()
        wrong = self.response(0x17, 0)
        uart.serial.read.return_value = bytes([0x16]) + wrong[1:]
        self.assertIsNone(uart.read_register(0x10))
        self.assertEqual(uart.get_statistics()['crc_errors'], 1)

    def test_invalid_address_configuration(self):
        for address in (-1, 256, 1.5, '0x16', None):
            with self.subTest(address=address):
                with self.assertRaises(ValueError):
                    self.make_uart(address)


if __name__ == '__main__':
    unittest.main()
