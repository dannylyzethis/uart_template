-- Diagnostic coverage beyond the legacy mode-1/8-bit test.
-- Covers all SPI modes, word lengths and clock divider boundaries.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity spi_modes_tb is
    generic (MODE : natural range 0 to 3 := 0; BITS : positive range 5 to 32 := 8; DIVIDER : natural range 0 to 65535 := 1);
end entity;
architecture test of spi_modes_tb is
    function logic_bit(value : natural) return std_logic is
    begin
        if value = 0 then return '0'; else return '1'; end if;
    end function;
    constant CPOL : std_logic := logic_bit(MODE / 2);
    constant CPHA : std_logic := logic_bit(MODE mod 2);
    constant PATTERN : std_logic_vector(31 downto 0) := x"D3A5964B";
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start : std_logic := '0';
    signal sclk, mosi, valid, busy, done : std_logic;
    signal cs : std_logic_vector(3 downto 0);
    signal received, captured : std_logic_vector(31 downto 0) := (others => '0');
    signal samples, edges, valid_count, done_count : natural := 0;
    signal last_edge : time := 0 ns;
    signal test_completed : boolean := false;
begin
    clk <= not clk after 10 ns; -- MAX 10 target clock: 50 MHz
    dut: entity work.spi_master
        generic map (CLK_FREQ => 50_000_000)
        port map (clk => clk, rst => rst, sclk => sclk, mosi => mosi,
                  miso => mosi, cs => cs, cpol => CPOL, cpha => CPHA,
                  word_len => std_logic_vector(to_unsigned(BITS-1, 5)),
                  clk_div => std_logic_vector(to_unsigned(DIVIDER, 16)), chip_sel => "0001", start => start,
                  data_in => PATTERN, data_out => received,
                  data_valid => valid, busy => busy, done => done);
    monitor: process(sclk)
    begin
        if sclk'event and cs(0) = '0' then
            edges <= edges + 1;
            last_edge <= now;
            if (CPHA = '0' and sclk /= CPOL) or (CPHA = '1' and sclk = CPOL) then
                captured <= captured(30 downto 0) & mosi;
                samples <= samples + 1;
            end if;
        end if;
    end process;
    pulses: process(clk)
    begin
        if rising_edge(clk) then
            if valid = '1' then valid_count <= valid_count + 1; end if;
            if done = '1' then done_count <= done_count + 1; end if;
        end if;
    end process;
    cs_hold: process(cs)
    begin
        if rising_edge(cs(0)) then
            assert now - last_edge >= (DIVIDER + 1) * 20 ns
                report "SPI CS hold shorter than one half clock" severity error;
        end if;
    end process;
    stimulus: process
    begin
        wait for 80 ns;
        wait until falling_edge(clk);
        rst <= '0';
        wait until falling_edge(clk);
        start <= '1';
        wait until falling_edge(clk);
        start <= '0';
        wait until done = '1' for (2 * BITS + 8) * (DIVIDER + 1) * 20 ns;
        assert done = '1' report "SPI transaction timed out" severity error;
        wait for 41 ns;
        assert edges = 2 * BITS report "SPI total edge count mismatch" severity error;
        assert valid_count = 1 and done_count = 1 report "SPI completion pulse count mismatch" severity error;
        assert busy = '0' report "SPI busy did not clear" severity error;
        assert samples = BITS report "SPI sample edge count mismatch" severity error;
        assert captured(BITS-1 downto 0) = PATTERN(BITS-1 downto 0)
            report "SPI MOSI word mismatch" severity error;
        assert received(BITS-1 downto 0) = PATTERN(BITS-1 downto 0)
            report "SPI loopback word mismatch" severity error;
        assert cs = "1111" and sclk = CPOL report "SPI idle mismatch" severity error;
        test_completed <= true;
        report "PASS: SPI mode " & integer'image(MODE) & " bits " & integer'image(BITS);
        wait;
    end process;
end architecture;
