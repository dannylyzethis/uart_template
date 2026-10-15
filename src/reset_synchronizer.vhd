-- Capture active-low external reset; release only after two clock edges.
-- Downstream logic uses synchronous resets, so its outputs reset on clk edges.
library ieee;
use ieee.std_logic_1164.all;
entity reset_synchronizer is
    port (clk : in std_logic; reset_n : in std_logic; rst : out std_logic);
end entity;
architecture rtl of reset_synchronizer is
    signal reset_sync : std_logic_vector(1 downto 0) := "11";
    attribute preserve : boolean;
    attribute preserve of reset_sync : signal is true;
    attribute altera_attribute : string;
    attribute altera_attribute of reset_sync : signal is
        "-name SYNCHRONIZER_IDENTIFICATION ""FORCED IF ASYNCHRONOUS""";
begin
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            reset_sync <= "11";
        elsif rising_edge(clk) then
            reset_sync <= reset_sync(0) & '0';
        end if;
    end process;
    rst <= reset_sync(1);
end architecture;
