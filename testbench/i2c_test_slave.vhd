-- Single-byte I2C slave model with open-drain pull-ups, ACK/NACK and stretching.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity i2c_test_slave is
    generic (ADDRESS : natural := 16#50#; STRETCH_TIME : time := 0 ns);
    port (sda, scl : inout std_logic;
          read_value : in std_logic_vector(7 downto 0);
          nack_phase : in natural range 0 to 2 := 0;
          write_value : out std_logic_vector(7 downto 0);
          transactions : out natural := 0);
end entity;
architecture model of i2c_test_slave is
    signal sda_drive, scl_drive : std_logic := 'Z';
begin
    sda <= 'H';
    scl <= 'H';
    sda <= sda_drive;
    scl <= scl_drive;
    slave: process
        variable address_byte, value : std_logic_vector(7 downto 0);
        variable count : natural := 0;
        procedure high_phase is
        begin
            if STRETCH_TIME > 0 ns then
                scl_drive <= '0';
                wait for STRETCH_TIME;
            end if;
            scl_drive <= 'Z';
            wait until rising_edge(scl);
        end procedure;
    begin
        loop
            wait until falling_edge(sda) and to_x01(scl) = '1'; -- START
            wait until falling_edge(scl);
            for bit_index in 7 downto 0 loop
                high_phase;
                address_byte(bit_index) := to_x01(sda);
                wait until falling_edge(scl);
            end loop;
            assert address_byte(7 downto 1) = std_logic_vector(to_unsigned(ADDRESS, 7))
                report "I2C slave: address mismatch" severity error;
            if nack_phase = 1 then sda_drive <= 'Z'; else sda_drive <= '0'; end if;
            high_phase;
            wait until falling_edge(scl);
            sda_drive <= 'Z';
            if nack_phase /= 1 then
                if address_byte(0) = '1' then
                    for bit_index in 7 downto 0 loop
                        if read_value(bit_index) = '0' then sda_drive <= '0';
                        else sda_drive <= 'Z'; end if;
                        high_phase;
                        wait until falling_edge(scl);
                    end loop;
                    sda_drive <= 'Z';
                    high_phase;
                    assert to_x01(sda) = '1' report "I2C master must NACK final read byte" severity error;
                    wait until falling_edge(scl);
                else
                    for bit_index in 7 downto 0 loop
                        high_phase;
                        value(bit_index) := to_x01(sda);
                        wait until falling_edge(scl);
                    end loop;
                    write_value <= value;
                    if nack_phase = 2 then sda_drive <= 'Z'; else sda_drive <= '0'; end if;
                    high_phase;
                    wait until falling_edge(scl);
                    sda_drive <= 'Z';
                end if;
            end if;
            -- Also stretch the clock preceding STOP, so it cannot be emitted early.
            if STRETCH_TIME > 0 ns then
                scl_drive <= '0';
                wait for STRETCH_TIME;
                scl_drive <= 'Z';
            end if;
            wait until rising_edge(sda) and to_x01(scl) = '1'; -- STOP
            count := count + 1;
            transactions <= count;
        end loop;
    end process;
end architecture;
