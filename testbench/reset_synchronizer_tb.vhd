library ieee;
use ieee.std_logic_1164.all;
entity reset_synchronizer_tb is end entity;
architecture test of reset_synchronizer_tb is
    signal clk : std_logic := '0';
    signal reset_n : std_logic := '1';
    signal rst : std_logic;
    signal clock_enabled : boolean := true;
    signal test_completed : boolean := false;
begin
    process
    begin
        wait for 10 ns;
        if clock_enabled then clk <= not clk; else clk <= '0'; end if;
    end process;
    dut: entity work.reset_synchronizer
        port map (clk => clk, reset_n => reset_n, rst => rst);
    process
        procedure check_release is
        begin
            wait until rising_edge(clk); wait for 1 ns;
            assert rst = '1' report "Reset released before second edge" severity error;
            wait until rising_edge(clk); wait for 1 ns;
            assert rst = '0' report "Reset failed to release on second edge" severity error;
        end procedure;
    begin
        wait for 1 ns;
        assert rst = '1' report "Power-up reset missing" severity error;
        check_release;
        -- Sweep deassertion across every nanosecond of the 20 ns period.
        for phase in 0 to 19 loop
            wait until falling_edge(clk); wait for 1 ns;
            reset_n <= '0'; wait for 1 ns;
            assert rst = '1' report "Reset assertion was not asynchronous" severity error;
            wait for phase * 1 ns + 1500 ps;
            reset_n <= '1'; wait for 0 ns;
            check_release;
        end loop;
        -- A brief pulse entirely between clock edges must still be captured.
        wait until falling_edge(clk); wait for 2 ns;
        reset_n <= '0'; wait for 2 ns; reset_n <= '1'; wait for 1 ns;
        assert rst = '1' report "Short reset pulse lost" severity error;
        check_release;
        -- Reset can assert without a running clock, but cannot release without it.
        wait until falling_edge(clk); clock_enabled <= false;
        wait for 3 ns; reset_n <= '0'; wait for 1 ns;
        assert rst = '1' report "Stopped-clock assertion failed" severity error;
        reset_n <= '1'; wait for 100 ns;
        assert rst = '1' report "Reset released without clock" severity error;
        clock_enabled <= true; check_release;
        test_completed <= true;
        report "PASS: reset startup, phase sweep, short pulse and stopped clock";
        wait;
    end process;
end architecture;
