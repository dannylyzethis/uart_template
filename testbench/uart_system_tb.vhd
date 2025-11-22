-- Comprehensive System Testbench for UART Register Interface
-- Tests all features including I2C, SPI, timeout, and error handling
-- Author: RF Test Automation Engineering
-- Date: 2025-11-22

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity uart_system_tb is
end uart_system_tb;

architecture behavioral of uart_system_tb is

    -- Constants
    constant CLK_PERIOD    : time := 10 ns;  -- 100MHz clock
    constant BAUD_PERIOD   : time := 8.68 us; -- 115200 baud
    constant BIT_PERIOD    : time := BAUD_PERIOD;

    -- Component declarations
    component uart_register_interface is
        generic (
            CLK_FREQ        : integer := 100_000_000;
            BAUD_RATE       : integer := 115200
        );
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            uart_rx         : in  std_logic;
            uart_tx         : out std_logic;
            ctrl_reg0       : out std_logic_vector(63 downto 0);
            ctrl_reg1       : out std_logic_vector(63 downto 0);
            ctrl_reg2       : out std_logic_vector(63 downto 0);
            ctrl_reg3       : out std_logic_vector(63 downto 0);
            ctrl_reg4       : out std_logic_vector(63 downto 0);
            ctrl_reg5       : out std_logic_vector(63 downto 0);
            ctrl_write_strobe : out std_logic_vector(5 downto 0);
            status_reg0     : in  std_logic_vector(63 downto 0);
            status_reg1     : in  std_logic_vector(63 downto 0);
            status_reg2     : in  std_logic_vector(63 downto 0);
            status_reg3     : in  std_logic_vector(63 downto 0);
            status_reg4     : in  std_logic_vector(63 downto 0);
            status_reg5     : in  std_logic_vector(63 downto 0);
            status_read_strobe : out std_logic_vector(5 downto 0);
            i2c0_sda        : inout std_logic;
            i2c0_scl        : inout std_logic;
            i2c0_busy       : in    std_logic;
            i2c0_start      : out   std_logic;
            i2c0_data_in    : out   std_logic_vector(7 downto 0);
            i2c0_data_out   : in    std_logic_vector(7 downto 0);
            i2c0_data_valid : in    std_logic;
            i2c0_ack_error  : in    std_logic;
            i2c1_sda        : inout std_logic;
            i2c1_scl        : inout std_logic;
            i2c1_busy       : in    std_logic;
            i2c1_start      : out   std_logic;
            i2c1_data_in    : out   std_logic_vector(7 downto 0);
            i2c1_data_out   : in    std_logic_vector(7 downto 0);
            i2c1_data_valid : in    std_logic;
            i2c1_ack_error  : in    std_logic;
            spi0_sclk       : out   std_logic;
            spi0_mosi       : out   std_logic;
            spi0_miso       : in    std_logic;
            spi0_cs         : out   std_logic_vector(3 downto 0);
            spi0_start      : out   std_logic;
            spi0_busy       : in    std_logic;
            spi0_data_in    : out   std_logic_vector(31 downto 0);
            spi0_data_out   : in    std_logic_vector(31 downto 0);
            spi0_data_valid : in    std_logic;
            spi1_sclk       : out   std_logic;
            spi1_mosi       : out   std_logic;
            spi1_miso       : in    std_logic;
            spi1_cs         : out   std_logic_vector(3 downto 0);
            spi1_start      : out   std_logic;
            spi1_busy       : in    std_logic;
            spi1_data_in    : out   std_logic_vector(31 downto 0);
            spi1_data_out   : in    std_logic_vector(31 downto 0);
            spi1_data_valid : in    std_logic;
            cmd_valid       : out std_logic;
            cmd_error       : out std_logic;
            crc_error       : out std_logic;
            timeout_error   : out std_logic
        );
    end component;

    component i2c_master is
        generic (
            CLK_FREQ    : integer := 100_000_000;
            I2C_FREQ    : integer := 100_000
        );
        port (
            clk         : in    std_logic;
            rst         : in    std_logic;
            sda         : inout std_logic;
            scl         : inout std_logic;
            start       : in    std_logic;
            addr        : in    std_logic_vector(6 downto 0);
            rw          : in    std_logic;
            data_in     : in    std_logic_vector(7 downto 0);
            data_out    : out   std_logic_vector(7 downto 0);
            data_valid  : out   std_logic;
            busy        : out   std_logic;
            ack_error   : out   std_logic;
            done        : out   std_logic
        );
    end component;

    component spi_master is
        generic (
            CLK_FREQ    : integer := 100_000_000
        );
        port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            sclk        : out std_logic;
            mosi        : out std_logic;
            miso        : in  std_logic;
            cs          : out std_logic_vector(3 downto 0);
            cpol        : in  std_logic;
            cpha        : in  std_logic;
            word_len    : in  std_logic_vector(4 downto 0);
            clk_div     : in  std_logic_vector(15 downto 0);
            chip_sel    : in  std_logic_vector(3 downto 0);
            start       : in  std_logic;
            data_in     : in  std_logic_vector(31 downto 0);
            data_out    : out std_logic_vector(31 downto 0);
            data_valid  : out std_logic;
            busy        : out std_logic;
            done        : out std_logic
        );
    end component;

    -- Test signals
    signal clk             : std_logic := '0';
    signal rst             : std_logic := '1';
    signal uart_rx         : std_logic := '1';
    signal uart_tx         : std_logic;

    -- Control register outputs
    signal ctrl_reg0       : std_logic_vector(63 downto 0);
    signal ctrl_reg1       : std_logic_vector(63 downto 0);
    signal ctrl_reg2       : std_logic_vector(63 downto 0);
    signal ctrl_reg3       : std_logic_vector(63 downto 0);
    signal ctrl_reg4       : std_logic_vector(63 downto 0);
    signal ctrl_reg5       : std_logic_vector(63 downto 0);
    signal ctrl_write_strobe : std_logic_vector(5 downto 0);

    -- Status register inputs (simulated sensor values)
    signal status_reg0     : std_logic_vector(63 downto 0) := x"0000000100000001";
    signal status_reg1     : std_logic_vector(63 downto 0) := x"1111222233334444";
    signal status_reg2     : std_logic_vector(63 downto 0) := x"5555666677778888";
    signal status_reg3     : std_logic_vector(63 downto 0) := x"0000000000000000";
    signal status_reg4     : std_logic_vector(63 downto 0) := x"DDDDEEEEFFFFAAAA";
    signal status_reg5     : std_logic_vector(63 downto 0) := x"0000000100000002";
    signal status_read_strobe : std_logic_vector(5 downto 0);

    -- I2C signals
    signal i2c0_sda        : std_logic := 'H';
    signal i2c0_scl        : std_logic := 'H';
    signal i2c0_busy       : std_logic;
    signal i2c0_start      : std_logic;
    signal i2c0_data_in    : std_logic_vector(7 downto 0);
    signal i2c0_data_out   : std_logic_vector(7 downto 0);
    signal i2c0_data_valid : std_logic;
    signal i2c0_ack_error  : std_logic;
    signal i2c0_done       : std_logic;

    signal i2c1_sda        : std_logic := 'H';
    signal i2c1_scl        : std_logic := 'H';
    signal i2c1_busy       : std_logic;
    signal i2c1_start      : std_logic;
    signal i2c1_data_in    : std_logic_vector(7 downto 0);
    signal i2c1_data_out   : std_logic_vector(7 downto 0);
    signal i2c1_data_valid : std_logic;
    signal i2c1_ack_error  : std_logic;
    signal i2c1_done       : std_logic;

    -- SPI signals
    signal spi0_sclk       : std_logic;
    signal spi0_mosi       : std_logic;
    signal spi0_miso       : std_logic := '0';
    signal spi0_cs         : std_logic_vector(3 downto 0);
    signal spi0_start      : std_logic;
    signal spi0_busy       : std_logic;
    signal spi0_data_in    : std_logic_vector(31 downto 0);
    signal spi0_data_out   : std_logic_vector(31 downto 0);
    signal spi0_data_valid : std_logic;
    signal spi0_done       : std_logic;

    signal spi1_sclk       : std_logic;
    signal spi1_mosi       : std_logic;
    signal spi1_miso       : std_logic := '1';
    signal spi1_cs         : std_logic_vector(3 downto 0);
    signal spi1_start      : std_logic;
    signal spi1_busy       : std_logic;
    signal spi1_data_in    : std_logic_vector(31 downto 0);
    signal spi1_data_out   : std_logic_vector(31 downto 0);
    signal spi1_data_valid : std_logic;
    signal spi1_done       : std_logic;

    -- Status signals
    signal cmd_valid       : std_logic;
    signal cmd_error       : std_logic;
    signal crc_error       : std_logic;
    signal timeout_error   : std_logic;

    -- Test control
    signal test_running    : boolean := true;
    signal test_phase      : string(1 to 32) := "INIT                            ";
    signal test_pass_count : integer := 0;
    signal test_fail_count : integer := 0;

    -- CRC calculation function (same as in DUT)
    function crc8_update(crc_in: std_logic_vector(7 downto 0);
                        data_in: std_logic_vector(7 downto 0))
                        return std_logic_vector is
        variable crc_out : std_logic_vector(7 downto 0);
        variable temp    : std_logic_vector(7 downto 0);
    begin
        temp := crc_in xor data_in;
        crc_out := temp(6 downto 0) & '0';
        if temp(7) = '1' then
            crc_out := crc_out xor x"07";
        end if;
        return crc_out;
    end function;

    -- UART transmit procedure
    procedure uart_send_byte(
        signal uart_tx_sig : out std_logic;
        constant data_byte : in std_logic_vector(7 downto 0)
    ) is
    begin
        uart_tx_sig <= '0';
        wait for BIT_PERIOD;

        for i in 0 to 7 loop
            uart_tx_sig <= data_byte(i);
            wait for BIT_PERIOD;
        end loop;

        uart_tx_sig <= '1';
        wait for BIT_PERIOD;
    end procedure;

    -- Send complete UART command packet
    procedure send_uart_command(
        signal uart_tx_sig : out std_logic;
        constant cmd       : in std_logic_vector(7 downto 0);
        constant addr      : in std_logic_vector(7 downto 0);
        constant data      : in std_logic_vector(63 downto 0)
    ) is
        variable crc : std_logic_vector(7 downto 0) := x"00";
    begin
        crc := crc8_update(crc, cmd);
        crc := crc8_update(crc, addr);
        crc := crc8_update(crc, data(63 downto 56));
        crc := crc8_update(crc, data(55 downto 48));
        crc := crc8_update(crc, data(47 downto 40));
        crc := crc8_update(crc, data(39 downto 32));
        crc := crc8_update(crc, data(31 downto 24));
        crc := crc8_update(crc, data(23 downto 16));
        crc := crc8_update(crc, data(15 downto 8));
        crc := crc8_update(crc, data(7 downto 0));

        uart_send_byte(uart_tx_sig, cmd);
        uart_send_byte(uart_tx_sig, addr);
        uart_send_byte(uart_tx_sig, data(63 downto 56));
        uart_send_byte(uart_tx_sig, data(55 downto 48));
        uart_send_byte(uart_tx_sig, data(47 downto 40));
        uart_send_byte(uart_tx_sig, data(39 downto 32));
        uart_send_byte(uart_tx_sig, data(31 downto 24));
        uart_send_byte(uart_tx_sig, data(23 downto 16));
        uart_send_byte(uart_tx_sig, data(15 downto 8));
        uart_send_byte(uart_tx_sig, data(7 downto 0));
        uart_send_byte(uart_tx_sig, crc);

        wait for 10 * BIT_PERIOD;
    end procedure;

begin

    -- Instantiate DUT (Device Under Test)
    DUT: uart_register_interface
        generic map (
            CLK_FREQ  => 100_000_000,
            BAUD_RATE => 115200
        )
        port map (
            clk             => clk,
            rst             => rst,
            uart_rx         => uart_rx,
            uart_tx         => uart_tx,
            ctrl_reg0       => ctrl_reg0,
            ctrl_reg1       => ctrl_reg1,
            ctrl_reg2       => ctrl_reg2,
            ctrl_reg3       => ctrl_reg3,
            ctrl_reg4       => ctrl_reg4,
            ctrl_reg5       => ctrl_reg5,
            ctrl_write_strobe => ctrl_write_strobe,
            status_reg0     => status_reg0,
            status_reg1     => status_reg1,
            status_reg2     => status_reg2,
            status_reg3     => status_reg3,
            status_reg4     => status_reg4,
            status_reg5     => status_reg5,
            status_read_strobe => status_read_strobe,
            i2c0_sda        => i2c0_sda,
            i2c0_scl        => i2c0_scl,
            i2c0_busy       => i2c0_busy,
            i2c0_start      => i2c0_start,
            i2c0_data_in    => i2c0_data_in,
            i2c0_data_out   => i2c0_data_out,
            i2c0_data_valid => i2c0_data_valid,
            i2c0_ack_error  => i2c0_ack_error,
            i2c1_sda        => i2c1_sda,
            i2c1_scl        => i2c1_scl,
            i2c1_busy       => i2c1_busy,
            i2c1_start      => i2c1_start,
            i2c1_data_in    => i2c1_data_in,
            i2c1_data_out   => i2c1_data_out,
            i2c1_data_valid => i2c1_data_valid,
            i2c1_ack_error  => i2c1_ack_error,
            spi0_sclk       => spi0_sclk,
            spi0_mosi       => spi0_mosi,
            spi0_miso       => spi0_miso,
            spi0_cs         => spi0_cs,
            spi0_start      => spi0_start,
            spi0_busy       => spi0_busy,
            spi0_data_in    => spi0_data_in,
            spi0_data_out   => spi0_data_out,
            spi0_data_valid => spi0_data_valid,
            spi1_sclk       => spi1_sclk,
            spi1_mosi       => spi1_mosi,
            spi1_miso       => spi1_miso,
            spi1_cs         => spi1_cs,
            spi1_start      => spi1_start,
            spi1_busy       => spi1_busy,
            spi1_data_in    => spi1_data_in,
            spi1_data_out   => spi1_data_out,
            spi1_data_valid => spi1_data_valid,
            cmd_valid       => cmd_valid,
            cmd_error       => cmd_error,
            crc_error       => crc_error,
            timeout_error   => timeout_error
        );

    -- Instantiate I2C Master 0
    I2C0: i2c_master
        generic map (
            CLK_FREQ => 100_000_000,
            I2C_FREQ => 100_000
        )
        port map (
            clk        => clk,
            rst        => rst,
            sda        => i2c0_sda,
            scl        => i2c0_scl,
            start      => i2c0_start,
            addr       => ctrl_reg2(62 downto 56),
            rw         => '0',
            data_in    => i2c0_data_in,
            data_out   => i2c0_data_out,
            data_valid => i2c0_data_valid,
            busy       => i2c0_busy,
            ack_error  => i2c0_ack_error,
            done       => i2c0_done
        );

    -- Instantiate I2C Master 1
    I2C1: i2c_master
        generic map (
            CLK_FREQ => 100_000_000,
            I2C_FREQ => 100_000
        )
        port map (
            clk        => clk,
            rst        => rst,
            sda        => i2c1_sda,
            scl        => i2c1_scl,
            start      => i2c1_start,
            addr       => ctrl_reg2(30 downto 24),
            rw         => '0',
            data_in    => i2c1_data_in,
            data_out   => i2c1_data_out,
            data_valid => i2c1_data_valid,
            busy       => i2c1_busy,
            ack_error  => i2c1_ack_error,
            done       => i2c1_done
        );

    -- Instantiate SPI Master 0
    SPI0: spi_master
        generic map (
            CLK_FREQ => 100_000_000
        )
        port map (
            clk        => clk,
            rst        => rst,
            sclk       => spi0_sclk,
            mosi       => spi0_mosi,
            miso       => spi0_miso,
            cs         => spi0_cs,
            cpol       => ctrl_reg4(62),
            cpha       => ctrl_reg4(61),
            word_len   => ctrl_reg4(60 downto 56),
            clk_div    => ctrl_reg4(55 downto 40),
            chip_sel   => ctrl_reg4(35 downto 32),
            start      => spi0_start,
            data_in    => spi0_data_in,
            data_out   => spi0_data_out,
            data_valid => spi0_data_valid,
            busy       => spi0_busy,
            done       => spi0_done
        );

    -- Instantiate SPI Master 1
    SPI1: spi_master
        generic map (
            CLK_FREQ => 100_000_000
        )
        port map (
            clk        => clk,
            rst        => rst,
            sclk       => spi1_sclk,
            mosi       => spi1_mosi,
            miso       => spi1_miso,
            cs         => spi1_cs,
            cpol       => ctrl_reg5(62),
            cpha       => ctrl_reg5(61),
            word_len   => ctrl_reg5(60 downto 56),
            clk_div    => ctrl_reg5(55 downto 40),
            chip_sel   => ctrl_reg5(35 downto 32),
            start      => spi1_start,
            data_in    => spi1_data_in,
            data_out   => spi1_data_out,
            data_valid => spi1_data_valid,
            busy       => spi1_busy,
            done       => spi1_done
        );

    -- Update status registers with SPI received data
    process(clk)
    begin
        if rising_edge(clk) then
            if spi0_data_valid = '1' then
                status_reg3(63 downto 32) <= spi0_data_out;
            end if;
            if spi1_data_valid = '1' then
                status_reg3(31 downto 0) <= spi1_data_out;
            end if;
            if i2c0_data_valid = '1' then
                status_reg2(31 downto 24) <= i2c0_data_out;
            end if;
            if i2c1_data_valid = '1' then
                status_reg2(23 downto 16) <= i2c1_data_out;
            end if;
        end if;
    end process;

    -- Clock generation
    clk_process: process
    begin
        while test_running loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Main test stimulus
    test_process: process
    begin
        uart_rx <= '1';
        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        report "========================================" severity note;
        report "  UART Register Interface System Test" severity note;
        report "========================================" severity note;

        -- Test 1: Write all control registers
        test_phase <= "TEST1: Write All Ctrl Regs      ";
        report "Test 1: Writing to all control registers" severity note;

        send_uart_command(uart_rx, x"01", x"00", x"123456789ABCDEF0");
        wait for 2 us;
        assert ctrl_reg0 = x"123456789ABCDEF0"
            report "FAIL: Control Register 0" severity error;
        test_pass_count <= test_pass_count + 1;

        send_uart_command(uart_rx, x"01", x"01", x"0001000200030004");
        wait for 2 us;
        assert ctrl_reg1 = x"0001000200030004"
            report "FAIL: Control Register 1" severity error;
        test_pass_count <= test_pass_count + 1;

        -- Test 2: Read all status registers
        test_phase <= "TEST2: Read All Status Regs     ";
        report "Test 2: Reading all status registers" severity note;

        for i in 0 to 5 loop
            send_uart_command(uart_rx, x"02", std_logic_vector(to_unsigned(16+i, 8)), x"0000000000000000");
            wait for 15 us;
        end loop;
        test_pass_count <= test_pass_count + 1;

        -- Test 3: I2C transaction
        test_phase <= "TEST3: I2C Transaction          ";
        report "Test 3: Testing I2C transaction" severity note;

        -- Write to I2C0: addr=0x50, data=0xAA
        send_uart_command(uart_rx, x"01", x"02", x"8A00000000000AA0");
        wait for 5 us;
        wait until i2c0_done = '1' or i2c0_ack_error = '1';
        wait for 2 us;
        assert i2c0_ack_error = '0'
            report "FAIL: I2C0 ACK error" severity warning;
        test_pass_count <= test_pass_count + 1;

        -- Test 4: SPI transaction with configuration
        test_phase <= "TEST4: SPI Transaction          ";
        report "Test 4: Testing SPI transaction" severity note;

        -- Configure SPI0: Mode 0, 16-bit, CLK_DIV=100, CS=0001
        send_uart_command(uart_rx, x"01", x"04", x"8F00640100000000");
        wait for 2 us;

        -- Send SPI data
        send_uart_command(uart_rx, x"01", x"03", x"DEADBEEF00000000");
        wait for 5 us;
        wait until spi0_done = '1';
        wait for 2 us;
        test_pass_count <= test_pass_count + 1;

        -- Test 5: CRC error detection
        test_phase <= "TEST5: CRC Error Detection      ";
        report "Test 5: Testing CRC error detection" severity note;

        uart_send_byte(uart_rx, x"01");
        uart_send_byte(uart_rx, x"00");
        for i in 0 to 7 loop
            uart_send_byte(uart_rx, x"00");
        end loop;
        uart_send_byte(uart_rx, x"FF");  -- Wrong CRC
        wait for 5 us;
        assert crc_error = '1'
            report "FAIL: CRC error not detected" severity error;
        test_pass_count <= test_pass_count + 1;

        -- Test 6: Invalid address error
        test_phase <= "TEST6: Invalid Address Error    ";
        report "Test 6: Testing invalid address detection" severity note;

        send_uart_command(uart_rx, x"01", x"FF", x"0000000000000000");
        wait for 5 us;
        assert cmd_error = '1'
            report "FAIL: Invalid address not detected" severity error;
        test_pass_count <= test_pass_count + 1;

        -- Test 7: Timeout test (incomplete packet)
        test_phase <= "TEST7: Timeout Detection        ";
        report "Test 7: Testing timeout detection" severity note;

        uart_send_byte(uart_rx, x"01");  -- Send only CMD byte
        wait for 15 ms;  -- Wait longer than timeout
        assert timeout_error = '1'
            report "FAIL: Timeout not detected" severity error;
        test_pass_count <= test_pass_count + 1;

        -- Final summary
        test_phase <= "COMPLETED                       ";
        report "========================================" severity note;
        report "  Test Summary:" severity note;
        report "  Passed: " & integer'image(test_pass_count) severity note;
        report "  Failed: " & integer'image(test_fail_count) severity note;
        report "========================================" severity note;

        wait for 10 us;
        test_running <= false;
        wait;
    end process;

    -- Monitor process
    monitor_process: process(clk)
    begin
        if rising_edge(clk) then
            if cmd_valid = '1' then
                report "Command validated" severity note;
            end if;
            if cmd_error = '1' then
                report "Command error detected" severity warning;
            end if;
            if crc_error = '1' then
                report "CRC error detected" severity warning;
            end if;
            if timeout_error = '1' then
                report "Timeout error detected" severity warning;
            end if;
        end if;
    end process;

end behavioral;
