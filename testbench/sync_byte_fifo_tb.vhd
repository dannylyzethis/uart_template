library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity sync_byte_fifo_tb is
    generic (DEPTH : positive := 64);
end entity;
architecture test of sync_byte_fifo_tb is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal push, pop : std_logic := '0';
    signal input_byte, output_byte : std_logic_vector(7 downto 0) := x"00";
    signal empty, full, overflow, underflow : std_logic;
    signal level : natural range 0 to DEPTH;
    signal test_completed : boolean := false;
begin
    clk <= not clk after 10 ns;
    dut: entity work.sync_byte_fifo
        generic map (DEPTH => DEPTH)
        port map (clk => clk, rst => rst, push => push, pop => pop, data_in => input_byte,
                  data_out => output_byte, empty => empty, full => full, level => level,
                  overflow => overflow, underflow => underflow);
    stimulus: process
        type queue_type is array (0 to DEPTH-1) of std_logic_vector(7 downto 0);
        variable queue : queue_type;
        variable count : natural := 0;
        variable random : unsigned(15 downto 0) := x"ACE1";
        procedure cycle(writing, reading : std_logic; value : natural) is
            variable expect_overflow, expect_underflow : std_logic;
        begin
            expect_overflow := '0'; expect_underflow := '0';
            wait until falling_edge(clk);
            push <= writing; pop <= reading;
            input_byte <= std_logic_vector(to_unsigned(value mod 256, 8));
            if reading = '1' then
                if count = 0 then expect_underflow := '1';
                else
                    assert output_byte = queue(0) report "FIFO popped wrong byte" severity error;
                    for i in 0 to DEPTH-2 loop queue(i) := queue(i+1); end loop;
                    count := count - 1;
                end if;
            end if;
            if writing = '1' then
                if count = DEPTH then expect_overflow := '1';
                else
                    queue(count) := std_logic_vector(to_unsigned(value mod 256, 8));
                    count := count + 1;
                end if;
            end if;
            wait until rising_edge(clk); wait for 1 ns;
            assert level = count report "FIFO level mismatch" severity error;
            assert (empty = '1') = (count = 0) report "FIFO empty mismatch" severity error;
            assert (full = '1') = (count = DEPTH) report "FIFO full mismatch" severity error;
            assert overflow = expect_overflow and underflow = expect_underflow
                report "FIFO rejected-operation flags mismatch" severity error;
            if count /= 0 then
                assert output_byte = queue(0) report "FIFO head mismatch" severity error;
            end if;
        end procedure;
    begin
        wait for 100 ns;
        wait until falling_edge(clk); rst <= '0';
        cycle('0','1',0);
        cycle('1','1',17);
        cycle('0','1',0);
        for i in 0 to DEPTH-1 loop cycle('1','0',i); end loop;
        cycle('1','0',255);
        for i in 0 to 2*DEPTH loop cycle('1','1',i+64); end loop;
        for i in 0 to DEPTH loop cycle('0','1',0); end loop;
        for i in 0 to 1999 loop
            random := random(14 downto 0) & (random(15) xor random(13) xor random(12) xor random(10));
            cycle(random(0), random(1), to_integer(random(9 downto 2)));
        end loop;
        cycle('1','0',99);
        wait until falling_edge(clk); rst <= '1'; push <= '0'; pop <= '0';
        wait until rising_edge(clk); wait for 1 ns;
        assert level = 0 and empty = '1' and overflow = '0' and underflow = '0'
            report "FIFO reset failed" severity error;
        count := 0;
        wait until falling_edge(clk); rst <= '0';
        cycle('1','0',42); cycle('0','1',0); cycle('0','0',0);
        test_completed <= true;
        report "PASS: FIFO depth " & integer'image(DEPTH);
        wait;
    end process;
end architecture;
