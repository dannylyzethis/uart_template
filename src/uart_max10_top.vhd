library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_max10_top is
    port (
        clk_50    : in  std_logic;
        reset_n   : in  std_logic;
        uart_rx   : in  std_logic;
        uart_tx   : out std_logic;

        i2c0_sda  : inout std_logic;
        i2c0_scl  : inout std_logic;
        i2c1_sda  : inout std_logic;
        i2c1_scl  : inout std_logic;

        spi0_sclk : out std_logic;
        spi0_mosi : out std_logic;
        spi0_miso : in  std_logic;
        spi0_cs_n : out std_logic_vector(3 downto 0);
        spi1_sclk : out std_logic;
        spi1_mosi : out std_logic;
        spi1_miso : in  std_logic;
        spi1_cs_n : out std_logic_vector(3 downto 0);

        led       : out std_logic_vector(3 downto 0)
    );
end uart_max10_top;

architecture rtl of uart_max10_top is
    constant CLK_FREQ : integer := 50_000_000;

    signal rst : std_logic;

    signal ctrl_reg1 : std_logic_vector(63 downto 0);
    signal ctrl_reg2 : std_logic_vector(63 downto 0);
    signal ctrl_reg4 : std_logic_vector(63 downto 0);
    signal ctrl_reg5 : std_logic_vector(63 downto 0);

    signal status_reg0 : std_logic_vector(63 downto 0);
    signal status_reg1 : std_logic_vector(63 downto 0);
    signal status_reg2 : std_logic_vector(63 downto 0);
    signal status_reg3 : std_logic_vector(63 downto 0);
    signal status_reg4 : std_logic_vector(63 downto 0);
    signal status_reg5 : std_logic_vector(63 downto 0);

    signal i2c0_start      : std_logic;
    signal i2c0_busy       : std_logic;
    signal i2c0_data_in    : std_logic_vector(7 downto 0);
    signal i2c0_data_out   : std_logic_vector(7 downto 0);
    signal i2c0_data_valid : std_logic;
    signal i2c0_ack_error  : std_logic;
    signal i2c1_start      : std_logic;
    signal i2c1_busy       : std_logic;
    signal i2c1_data_in    : std_logic_vector(7 downto 0);
    signal i2c1_data_out   : std_logic_vector(7 downto 0);
    signal i2c1_data_valid : std_logic;
    signal i2c1_ack_error  : std_logic;

    signal spi0_start      : std_logic;
    signal spi0_busy       : std_logic;
    signal spi0_data_in    : std_logic_vector(31 downto 0);
    signal spi0_data_out   : std_logic_vector(31 downto 0);
    signal spi0_data_valid : std_logic;
    signal spi1_start      : std_logic;
    signal spi1_busy       : std_logic;
    signal spi1_data_in    : std_logic_vector(31 downto 0);
    signal spi1_data_out   : std_logic_vector(31 downto 0);
    signal spi1_data_valid : std_logic;

    signal cmd_valid     : std_logic;
    signal cmd_error     : std_logic;
    signal crc_error     : std_logic;
    signal timeout_error : std_logic;

    signal i2c0_rx_latch : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c1_rx_latch : std_logic_vector(7 downto 0) := (others => '0');
    signal spi0_rx_latch : std_logic_vector(31 downto 0) := (others => '0');
    signal spi1_rx_latch : std_logic_vector(31 downto 0) := (others => '0');
    signal seconds_count : unsigned(31 downto 0) := (others => '0');
    signal second_divider: integer range 0 to CLK_FREQ - 1 := 0;
begin
    rst <= not reset_n;

    register_interface: entity work.uart_register_interface
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => 115200
        )
        port map (
            clk => clk_50, rst => rst, uart_rx => uart_rx, uart_tx => uart_tx,
            ctrl_reg0 => open, ctrl_reg1 => ctrl_reg1,
            ctrl_reg2 => ctrl_reg2, ctrl_reg3 => open,
            ctrl_reg4 => ctrl_reg4, ctrl_reg5 => ctrl_reg5,
            ctrl_write_strobe => open,
            status_reg0 => status_reg0, status_reg1 => status_reg1,
            status_reg2 => status_reg2, status_reg3 => status_reg3,
            status_reg4 => status_reg4, status_reg5 => status_reg5,
            status_read_strobe => open,
            i2c0_sda => i2c0_sda, i2c0_scl => i2c0_scl,
            i2c0_busy => i2c0_busy, i2c0_start => i2c0_start,
            i2c0_data_in => i2c0_data_in, i2c0_data_out => i2c0_data_out,
            i2c0_data_valid => i2c0_data_valid, i2c0_ack_error => i2c0_ack_error,
            i2c1_sda => i2c1_sda, i2c1_scl => i2c1_scl,
            i2c1_busy => i2c1_busy, i2c1_start => i2c1_start,
            i2c1_data_in => i2c1_data_in, i2c1_data_out => i2c1_data_out,
            i2c1_data_valid => i2c1_data_valid, i2c1_ack_error => i2c1_ack_error,
            spi0_sclk => open, spi0_mosi => open,
            spi0_miso => spi0_miso, spi0_cs => open,
            spi0_start => spi0_start, spi0_busy => spi0_busy,
            spi0_data_in => spi0_data_in, spi0_data_out => spi0_data_out,
            spi0_data_valid => spi0_data_valid,
            spi1_sclk => open, spi1_mosi => open,
            spi1_miso => spi1_miso, spi1_cs => open,
            spi1_start => spi1_start, spi1_busy => spi1_busy,
            spi1_data_in => spi1_data_in, spi1_data_out => spi1_data_out,
            spi1_data_valid => spi1_data_valid,
            cmd_valid => cmd_valid, cmd_error => cmd_error,
            crc_error => crc_error, timeout_error => timeout_error
        );

    i2c_master_0: entity work.i2c_master
        generic map (CLK_FREQ => CLK_FREQ, I2C_FREQ => 100_000)
        port map (
            clk => clk_50, rst => rst, sda => i2c0_sda, scl => i2c0_scl,
            start => i2c0_start, addr => ctrl_reg2(62 downto 56), rw => '0',
            data_in => i2c0_data_in, data_out => i2c0_data_out,
            data_valid => i2c0_data_valid, busy => i2c0_busy,
            ack_error => i2c0_ack_error, done => open
        );

    i2c_master_1: entity work.i2c_master
        generic map (CLK_FREQ => CLK_FREQ, I2C_FREQ => 100_000)
        port map (
            clk => clk_50, rst => rst, sda => i2c1_sda, scl => i2c1_scl,
            start => i2c1_start, addr => ctrl_reg2(30 downto 24), rw => '0',
            data_in => i2c1_data_in, data_out => i2c1_data_out,
            data_valid => i2c1_data_valid, busy => i2c1_busy,
            ack_error => i2c1_ack_error, done => open
        );

    spi_master_0: entity work.spi_master
        generic map (CLK_FREQ => CLK_FREQ)
        port map (
            clk => clk_50, rst => rst, sclk => spi0_sclk,
            mosi => spi0_mosi, miso => spi0_miso, cs => spi0_cs_n,
            cpol => ctrl_reg4(62), cpha => ctrl_reg4(61),
            word_len => ctrl_reg4(60 downto 56),
            clk_div => ctrl_reg4(55 downto 40),
            chip_sel => ctrl_reg4(35 downto 32), start => spi0_start,
            data_in => spi0_data_in, data_out => spi0_data_out,
            data_valid => spi0_data_valid, busy => spi0_busy, done => open
        );

    spi_master_1: entity work.spi_master
        generic map (CLK_FREQ => CLK_FREQ)
        port map (
            clk => clk_50, rst => rst, sclk => spi1_sclk,
            mosi => spi1_mosi, miso => spi1_miso, cs => spi1_cs_n,
            cpol => ctrl_reg5(62), cpha => ctrl_reg5(61),
            word_len => ctrl_reg5(60 downto 56),
            clk_div => ctrl_reg5(55 downto 40),
            chip_sel => ctrl_reg5(35 downto 32), start => spi1_start,
            data_in => spi1_data_in, data_out => spi1_data_out,
            data_valid => spi1_data_valid, busy => spi1_busy, done => open
        );

    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if rst = '1' then
                i2c0_rx_latch <= (others => '0');
                i2c1_rx_latch <= (others => '0');
                spi0_rx_latch <= (others => '0');
                spi1_rx_latch <= (others => '0');
                seconds_count <= (others => '0');
                second_divider <= 0;
            else
                if i2c0_data_valid = '1' then i2c0_rx_latch <= i2c0_data_out; end if;
                if i2c1_data_valid = '1' then i2c1_rx_latch <= i2c1_data_out; end if;
                if spi0_data_valid = '1' then spi0_rx_latch <= spi0_data_out; end if;
                if spi1_data_valid = '1' then spi1_rx_latch <= spi1_data_out; end if;

                if second_divider = CLK_FREQ - 1 then
                    second_divider <= 0;
                    seconds_count <= seconds_count + 1;
                else
                    second_divider <= second_divider + 1;
                end if;
            end if;
        end if;
    end process;

    status_reg0 <= std_logic_vector(seconds_count) &
                   spi1_busy & spi0_busy & i2c1_busy & i2c0_busy & "0000" &
                   "00" & i2c1_ack_error & i2c0_ack_error & "0000" &
                   x"00" & "000" & timeout_error & crc_error & cmd_error & cmd_valid & '1';
    status_reg1 <= (others => '0');
    status_reg2 <= x"00000000" & x"00" & i2c0_rx_latch & x"00" & i2c1_rx_latch;
    status_reg3 <= spi0_rx_latch & spi1_rx_latch;
    status_reg4 <= ctrl_reg1;
    status_reg5 <= (others => '0');

    -- The evaluation-kit LEDs are active-low.
    led(0) <= reset_n;
    led(1) <= not (spi0_busy or spi1_busy);
    led(2) <= not (i2c0_busy or i2c1_busy);
    led(3) <= not (cmd_error or crc_error or timeout_error);
end rtl;
