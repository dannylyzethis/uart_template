library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity spi_master_tb is
end spi_master_tb;

architecture behavioral of spi_master_tb is
    constant CLK_PERIOD : time := 10 ns;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal sclk       : std_logic;
    signal mosi       : std_logic;
    signal miso       : std_logic := '1';
    signal cs         : std_logic_vector(3 downto 0);
    signal start      : std_logic := '0';
    signal data_out   : std_logic_vector(31 downto 0);
    signal data_valid : std_logic;
    signal busy       : std_logic;
    signal done       : std_logic;
    signal captured   : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_count  : integer range 0 to 8 := 0;
    signal test_completed : boolean := false;
begin
    clk <= not clk after CLK_PERIOD / 2;

    DUT: entity work.spi_master
        port map (
            clk        => clk,
            rst        => rst,
            sclk       => sclk,
            mosi       => mosi,
            miso       => miso,
            cs         => cs,
            cpol       => '0',
            cpha       => '1',
            word_len   => "00111",  -- 8 bits
            clk_div    => x"0001",
            chip_sel   => "0001",
            start      => start,
            data_in    => x"000000A5",
            data_out   => data_out,
            data_valid => data_valid,
            busy       => busy,
            done       => done
        );

    -- Mode 1 samples MOSI on each falling (trailing) SCLK edge.
    capture_mosi: process(sclk)
    begin
        if falling_edge(sclk) and cs /= "1111" and bit_count < 8 then
            captured <= captured(6 downto 0) & mosi;
            bit_count <= bit_count + 1;
        end if;
    end process;

    stimulus: process
    begin
        wait for 4 * CLK_PERIOD;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1' for 2 us;
        assert done = '1' report "SPI mode 1 timed out" severity error;
        wait for 1 ns;
        assert captured = x"A5" report "SPI mode 1 MOSI mismatch" severity error;
        assert data_out(7 downto 0) = x"FF" report "SPI mode 1 MISO mismatch" severity error;
        assert cs = "1111" and sclk = '0' report "SPI mode 1 bus did not return idle" severity error;

        report "PASS: SPI mode 1 transmitted 0xA5 and received 0xFF" severity note;
        test_completed <= true;
        wait;
    end process;
end behavioral;
