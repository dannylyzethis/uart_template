library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity uart_address_tb is
    generic (DEVICE_ID : natural range 0 to 255 := 22);
end entity;
architecture test of uart_address_tb is
    constant DEVICE_BYTE : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(DEVICE_ID, 8));
    constant OTHER_BYTE : std_logic_vector(7 downto 0) := not DEVICE_BYTE;
    signal command_count, write_count : natural := 0;
    signal cmd_valid : std_logic;
    signal write_strobe : std_logic_vector(5 downto 0);
    constant BIT_TIME : time := 1 us;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal uart_rx : std_logic := '1';
    signal uart_tx, cmd_error, crc_error, timeout_error : std_logic;
    signal ctrl0 : std_logic_vector(63 downto 0);
    signal responses, expected_count : natural := 0;
    type responses_type is array (0 to 63) of std_logic_vector(63 downto 0);
    signal expected_words : responses_type := (others => (others => '0'));
    signal test_completed : boolean := false;
    function crc8(crc, value : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable result : std_logic_vector(7 downto 0) := crc;
    begin
        for i in 7 downto 0 loop
            if (result(7) xor value(i)) = '1' then
                result := (result(6 downto 0) & '0') xor x"07";
            else result := result(6 downto 0) & '0'; end if;
        end loop;
        return result;
    end function;
begin
    clk <= not clk after 10 ns;
    dut: entity work.uart_register_interface
        generic map (CLK_FREQ => 50_000_000, BAUD_RATE => 1_000_000,
                     RX_FIFO_DEPTH => 64, TX_FIFO_DEPTH => 16, DEVICE_ADDRESS => DEVICE_BYTE)
        port map (clk => clk, rst => rst, uart_rx => uart_rx, uart_tx => uart_tx,
                  ctrl_reg0 => ctrl0, ctrl_reg1 => open, ctrl_reg2 => open, ctrl_reg3 => open,
                  ctrl_reg4 => open, ctrl_reg5 => open, ctrl_write_strobe => write_strobe,
                  status_reg0 => x"1122334455667788", status_reg1 => x"8877665544332211",
                  status_reg2 => x"0000000000000000", status_reg3 => x"0000000000000000",
                  status_reg4 => x"0000000000000000", status_reg5 => x"0000000000000000",
                  status_read_strobe => open,
                  i2c0_sda => open, i2c0_scl => open, i2c0_busy => '0', i2c0_start => open,
                  i2c0_data_in => open, i2c0_data_out => x"00", i2c0_data_valid => '0', i2c0_ack_error => '0',
                  i2c1_sda => open, i2c1_scl => open, i2c1_busy => '0', i2c1_start => open,
                  i2c1_data_in => open, i2c1_data_out => x"00", i2c1_data_valid => '0', i2c1_ack_error => '0',
                  spi0_sclk => open, spi0_mosi => open, spi0_miso => '0', spi0_cs => open,
                  spi0_start => open, spi0_busy => '0', spi0_data_in => open,
                  spi0_data_out => x"00000000", spi0_data_valid => '0',
                  spi1_sclk => open, spi1_mosi => open, spi1_miso => '0', spi1_cs => open,
                  spi1_start => open, spi1_busy => '0', spi1_data_in => open,
                  spi1_data_out => x"00000000", spi1_data_valid => '0',
                  cmd_valid => cmd_valid, cmd_error => cmd_error, crc_error => crc_error,
                  timeout_error => timeout_error);
    receiver: process
        variable value, checksum : std_logic_vector(7 downto 0);
        procedure receive_byte(variable byte_value : out std_logic_vector(7 downto 0)) is
        begin
            wait until falling_edge(uart_tx) for 25 ms;
            assert uart_tx = '0' report "UART response start timed out" severity error;
            wait for BIT_TIME + BIT_TIME/2;
            for i in 0 to 7 loop
                byte_value(i) := uart_tx;
                wait for BIT_TIME;
            end loop;
            assert uart_tx = '1' report "UART response framing error" severity error;
        end procedure;
    begin
        loop
            receive_byte(value);
            assert value = DEVICE_BYTE report "UART response device mismatch" severity error;
            receive_byte(value);
            assert value = x"02" report "UART response header mismatch" severity error;
            assert responses < expected_count report "Unrequested UART response" severity error;
            checksum := crc8(crc8(x"00", DEVICE_BYTE), value);
            for i in 0 to 7 loop
                receive_byte(value);
                assert value = expected_words(responses)(63-i*8 downto 56-i*8)
                    report "MAX 10 status readback mismatch" severity error;
                checksum := crc8(checksum, value);
            end loop;
            receive_byte(value);
            assert value = checksum report "UART response CRC mismatch" severity error;
            responses <= responses + 1;
        end loop;
    end process;
    count_commands: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                command_count <= 0; write_count <= 0;
            else
            if cmd_valid = '1' then command_count <= command_count + 1; end if;
            if write_strobe /= "000000" then write_count <= write_count + 1; end if;
            end if;
        end if;
    end process;
    stimulus: process
        variable expected_responses : natural := 0;
        variable declare_crc : std_logic_vector(7 downto 0);
        procedure send_byte(value : std_logic_vector(7 downto 0)) is
        begin
            uart_rx <= '0'; wait for BIT_TIME;
            for i in 0 to 7 loop uart_rx <= value(i); wait for BIT_TIME; end loop;
            uart_rx <= '1'; wait for BIT_TIME;
        end procedure;
        procedure command(opcode, address : std_logic_vector(7 downto 0);
                          value : std_logic_vector(63 downto 0);
                          destination : std_logic_vector(7 downto 0) := DEVICE_BYTE;
                          corrupt_crc : boolean := false) is
            variable checksum : std_logic_vector(7 downto 0);
        begin
            checksum := crc8(crc8(crc8(x"00", destination), opcode), address);
            send_byte(destination); send_byte(opcode); send_byte(address);
            for i in 0 to 7 loop
                checksum := crc8(checksum, value(63-i*8 downto 56-i*8));
                send_byte(value(63-i*8 downto 56-i*8));
            end loop;
            if corrupt_crc then checksum := checksum xor x"01"; end if;
            send_byte(checksum);
        end procedure;
        procedure request_status(address : std_logic_vector(7 downto 0);
                                 value : std_logic_vector(63 downto 0)) is
        begin
            expected_words(expected_responses) <= value;
            expected_responses := expected_responses + 1;
            expected_count <= expected_responses;
            command(x"02", address, x"0000000000000000");
        end procedure;
        procedure drain is
        begin
            if responses /= expected_responses then
                wait until responses = expected_responses for 14 ms;
            end if;
            assert responses = expected_responses report "FIFO response timed out" severity error;
            wait for 2 * BIT_TIME;
        end procedure;
    begin
        wait for 123 ns; rst <= '0'; wait for 1 us;
        -- Foreign data deliberately contains the local address and read/write opcodes.
        command(x"01", x"00", DEVICE_BYTE & x"01001602001600", OTHER_BYTE);
        command(x"02", x"10", x"0000000000000000", OTHER_BYTE);
        command(x"FF", x"FF", x"FFFFFFFFFFFFFFFF", OTHER_BYTE, true);
        wait for 200 us;
        assert command_count = 0 and write_count = 0 and ctrl0 = x"0000000000000000"
            report "Foreign command had a side effect" severity error;
        assert uart_tx = '1' and responses = 0 and cmd_error = '0' and crc_error = '0'
            report "Foreign packet generated a response or protocol error" severity error;
        -- Local traffic immediately following a foreign packet remains aligned.
        command(x"01", x"00", x"0123456789ABCDEF");
        request_status(x"10", x"1122334455667788"); drain;
        assert ctrl0 = x"0123456789ABCDEF" and write_count = 1 and command_count = 2
            report "Addressed command did not execute exactly once" severity error;
        command(x"01", x"00", x"FFFFFFFFFFFFFFFF", DEVICE_BYTE, true);
        wait for 2 us;
        assert crc_error = '1' and write_count = 1 and ctrl0 = x"0123456789ABCDEF"
            report "Bad local CRC changed a register" severity error;
        command(x"01", x"06", x"0000000000000004");
        -- CRC for OTHER_BYTE must fail if only the wire address changes to local.
        send_byte(DEVICE_BYTE); send_byte(x"01"); send_byte(x"00");
        for i in 0 to 7 loop send_byte(x"00"); end loop;
        -- Build the checksum using the foreign address, independently of command().
        declare_crc := crc8(crc8(crc8(x"00", OTHER_BYTE), x"01"), x"00");
        for i in 0 to 7 loop declare_crc := crc8(declare_crc, x"00"); end loop;
        send_byte(declare_crc); wait for 2 us;
        assert crc_error = '1' and write_count = 1 report "Address excluded from CRC" severity error;
        command(x"01", x"06", x"0000000000000004");
        -- Partial foreign traffic times out silently and returns to packet boundary.
        send_byte(OTHER_BYTE); send_byte(x"01"); wait for 11 ms;
        assert timeout_error = '0' report "Foreign timeout polluted local errors" severity error;
        request_status(x"16", x"0000000000000000"); drain;
        command(x"01", x"00", x"FEDCBA9876543210"); wait for 2 us;
        assert ctrl0 = x"FEDCBA9876543210" and write_count = 2
            report "Parser did not recover after foreign timeout" severity error;
        test_completed <= true;
        report "PASS: device address filtering, CRC coverage, response address and foreign timeout";
        wait;
    end process;
end architecture;
