library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity uart_max10_tb is end entity;
architecture test of uart_max10_tb is
    constant BIT_TIME : time := 8680 ns;
    signal clk : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal uart_rx : std_logic := '1';
    signal uart_tx : std_logic;
    signal sda0, scl0, sda1, scl1, sclk0, sclk1, mosi0, mosi1 : std_logic;
    signal cs0, cs1, led : std_logic_vector(3 downto 0);
    signal slave_write0, slave_write1 : std_logic_vector(7 downto 0);
    signal transactions0, transactions1, responses : natural := 0;
    signal expect_response : boolean := false;
    signal expected : std_logic_vector(63 downto 0) := (others => '0');
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
    dut: entity work.uart_max10_top
        generic map (DEVICE_ADDRESS => x"A5")
        port map (clk_50 => clk, reset_n => reset_n, uart_rx => uart_rx, uart_tx => uart_tx,
                  i2c0_sda => sda0, i2c0_scl => scl0, i2c1_sda => sda1, i2c1_scl => scl1,
                  spi0_sclk => sclk0, spi0_mosi => mosi0, spi0_miso => mosi0, spi0_cs_n => cs0,
                  spi1_sclk => sclk1, spi1_mosi => mosi1, spi1_miso => mosi1, spi1_cs_n => cs1,
                  led => led);
    slave0: entity work.i2c_test_slave
        generic map (ADDRESS => 16#50#, STRETCH_TIME => 17 us)
        port map (sda => sda0, scl => scl0, read_value => x"A5", write_value => slave_write0,
                  transactions => transactions0);
    slave1: entity work.i2c_test_slave
        generic map (ADDRESS => 16#51#, STRETCH_TIME => 11 us)
        port map (sda => sda1, scl => scl1, read_value => x"96", write_value => slave_write1,
                  transactions => transactions1);
    receiver: process
        variable value, checksum : std_logic_vector(7 downto 0);
        procedure receive_byte(variable byte_value : out std_logic_vector(7 downto 0)) is
        begin
            wait until falling_edge(uart_tx) for 2 ms;
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
            wait until expect_response;
            receive_byte(value);
            assert value = x"A5" report "UART response device mismatch" severity error;
            receive_byte(value);
            assert value = x"02" report "UART response header mismatch" severity error;
            checksum := crc8(crc8(x"00", x"A5"), value);
            for i in 0 to 7 loop
                receive_byte(value);
                assert value = expected(63-i*8 downto 56-i*8)
                    report "MAX 10 status readback mismatch" severity error;
                checksum := crc8(checksum, value);
            end loop;
            receive_byte(value);
            assert value = checksum report "UART response CRC mismatch" severity error;
            responses <= responses + 1;
        end loop;
    end process;
    stimulus: process
        variable expected_responses : natural := 0;
        procedure send_byte(value : std_logic_vector(7 downto 0)) is
        begin
            uart_rx <= '0'; wait for BIT_TIME;
            for i in 0 to 7 loop uart_rx <= value(i); wait for BIT_TIME; end loop;
            uart_rx <= '1'; wait for BIT_TIME;
        end procedure;
        procedure command(opcode, address : std_logic_vector(7 downto 0);
                          value : std_logic_vector(63 downto 0)) is
            variable checksum : std_logic_vector(7 downto 0);
        begin
            checksum := crc8(crc8(crc8(x"00", x"A5"), opcode), address);
            send_byte(x"A5"); send_byte(opcode); send_byte(address);
            for i in 0 to 7 loop
                checksum := crc8(checksum, value(63-i*8 downto 56-i*8));
                send_byte(value(63-i*8 downto 56-i*8));
            end loop;
            send_byte(checksum);
        end procedure;
        procedure read_status(address : std_logic_vector(7 downto 0);
                              value : std_logic_vector(63 downto 0)) is
        begin
            expected <= value;
            expect_response <= true;
            expected_responses := expected_responses + 1;
            command(x"02", address, x"0000000000000000");
            wait until responses = expected_responses for 2 ms;
            assert responses = expected_responses report "MAX 10 response timed out" severity error;
            expect_response <= false;
            wait for 2 * BIT_TIME;
        end procedure;
    begin
        wait for 123 ns;
        reset_n <= '1';
        wait for 1 us;
        command(x"01", x"02", x"D0000000D1001234"); -- Existing write encoding
        wait for 1 ms;
        assert transactions0 = 1 and transactions1 = 1 report "I2C writes did not finish" severity error;
        assert slave_write0 = x"12" and slave_write1 = x"34" report "I2C channel write mapping mismatch" severity error;
        command(x"01", x"02", x"D0800000D1800000"); -- New read bits 55 / 23
        wait for 1 ms;
        assert transactions0 = 2 and transactions1 = 2 report "I2C reads did not finish" severity error;
        read_status(x"12", x"0000000000A50096");
        command(x"01", x"04", x"8700010100000000"); -- SPI0 mode 0 / 8 bits
        command(x"01", x"05", x"BF00010200000000"); -- SPI1 mode 1 / 32 bits
        command(x"01", x"03", x"D3A5964B2C5A69B4");
        wait for 100 us;
        read_status(x"13", x"0000004B2C5A69B4");
        read_status(x"16", x"0000000000000000");
        test_completed <= true;
        report "PASS: MAX 10 50 MHz UART/I2C reads+writes/SPI readback/CRC";
        wait;
    end process;
end architecture;
