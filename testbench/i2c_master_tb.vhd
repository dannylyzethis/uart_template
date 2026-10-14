library ieee;
use ieee.std_logic_1164.all;
entity i2c_master_tb is
    generic (STRETCH : boolean := false; I2C_HZ : positive := 100_000);
end entity;
architecture test of i2c_master_tb is
    function stretch_delay return time is
    begin
        if STRETCH then return 17 us; else return 0 ns; end if;
    end function;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start, rw : std_logic := '0';
    signal sda, scl, valid, busy, ack_error, done : std_logic;
    signal tx, rx, slave_read, slave_write : std_logic_vector(7 downto 0) := x"00";
    signal nack_phase : natural range 0 to 2 := 0;
    signal transactions, valid_count, done_count : natural := 0;
    signal test_completed : boolean := false;
    type values_type is array (natural range <>) of std_logic_vector(7 downto 0);
    constant VALUES : values_type := (x"00", x"FF", x"A5", x"96");
begin
    clk <= not clk after 10 ns;
    dut: entity work.i2c_master
        generic map (CLK_FREQ => 50_000_000, I2C_FREQ => I2C_HZ)
        port map (clk => clk, rst => rst, sda => sda, scl => scl, start => start,
                  addr => "1010000", rw => rw, data_in => tx, data_out => rx,
                  data_valid => valid, busy => busy, ack_error => ack_error, done => done);
    slave: entity work.i2c_test_slave
        generic map (STRETCH_TIME => stretch_delay)
        port map (sda => sda, scl => scl, read_value => slave_read,
                  nack_phase => nack_phase, write_value => slave_write,
                  transactions => transactions);
    pulses: process(clk)
    begin
        if rising_edge(clk) then
            if valid = '1' then valid_count <= valid_count + 1; end if;
            if done = '1' then done_count <= done_count + 1; end if;
        end if;
    end process;
    high_time_check: process(scl)
        variable high_since : time := 0 ns;
        variable seen_rise : boolean := false;
    begin
        if rising_edge(scl) then
            high_since := now; seen_rise := true;
        elsif falling_edge(scl) and seen_rise then
            assert now - high_since >= 2 * (50_000_000 / (4 * I2C_HZ)) * 20 ns
                report "I2C high phase shortened by stretching" severity error;
        end if;
    end process;
    stimulus: process
        variable expected_reads, expected_transactions : natural := 0;
        procedure transfer(reading : std_logic; value : std_logic_vector(7 downto 0);
                           nack : natural := 0) is
        begin
            wait until falling_edge(clk);
            rw <= reading; tx <= value; slave_read <= value; nack_phase <= nack;
            start <= '1';
            wait until falling_edge(clk);
            start <= '0';
            wait until done = '1' for 1 ms;
            assert done = '1' report "I2C transfer timed out" severity error;
            if nack = 0 then
                assert ack_error = '0' report "Unexpected I2C NACK" severity error;
            else
                assert ack_error = '1' report "I2C NACK not reported" severity error;
            end if;
            if reading = '1' and nack = 0 then
                expected_reads := expected_reads + 1;
                assert rx = value report "I2C read word mismatch" severity error;
            elsif reading = '0' and nack /= 1 then
                assert slave_write = value report "I2C write word mismatch" severity error;
            end if;
            expected_transactions := expected_transactions + 1;
            wait for 200 ns;
            assert transactions = expected_transactions report "I2C STOP missing" severity error;
            assert valid_count = expected_reads report "I2C data_valid pulse count mismatch" severity error;
            assert done_count = expected_transactions report "I2C done pulse count mismatch" severity error;
            assert busy = '0' and to_x01(sda) = '1' and to_x01(scl) = '1'
                report "I2C did not return idle" severity error;
        end procedure;
    begin
        wait for 100 ns;
        wait until falling_edge(clk);
        rst <= '0';
        for i in VALUES'range loop
            transfer('1', VALUES(i));
            transfer('0', VALUES(i));
        end loop;
        transfer('0', x"69", 1);
        transfer('0', x"69", 2);
        transfer('1', x"69", 1);
        test_completed <= true;
        report "PASS: I2C read/write, ACK/NACK, STOP and pulse counts; stretch=" & boolean'image(STRETCH);
        wait;
    end process;
end architecture;
