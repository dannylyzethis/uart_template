-- Simple I2C Master for Testing
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_master is
    port (
        clk         : in    std_logic;
        rst         : in    std_logic;
        sda         : inout std_logic;
        scl         : inout std_logic;
        start       : in    std_logic;
        data_in     : in    std_logic_vector(7 downto 0);
        data_out    : out   std_logic_vector(7 downto 0);
        data_valid  : out   std_logic;
        busy        : out   std_logic;
        ack_error   : out   std_logic
    );
end i2c_master;

architecture behavioral of i2c_master is
    signal busy_int : std_logic := '0';
    signal counter  : integer range 0 to 1000 := 0;
begin
    
    busy <= busy_int;
    data_out <= x"A5";  -- Dummy read data
    ack_error <= '0';   -- No errors in simulation
    
    -- Simple behavioral model
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                busy_int <= '0';
                data_valid <= '0';
                counter <= 0;
            else
                data_valid <= '0';  -- Default
                
                if start = '1' and busy_int = '0' then
                    busy_int <= '1';
                    counter <= 0;
                elsif busy_int = '1' then
                    counter <= counter + 1;
                    if counter = 100 then  -- Simulate I2C transaction time
                        busy_int <= '0';
                        data_valid <= '1';
                        counter <= 0;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- I2C lines - just pull high when not driven
    sda <= 'H';
    scl <= 'H';
    
end behavioral;

-- Simple SPI Master for Testing
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        sclk        : out std_logic;
        mosi        : out std_logic;
        miso        : in  std_logic;
        cs          : out std_logic_vector(3 downto 0);
        start       : in  std_logic;
        data_in     : in  std_logic_vector(31 downto 0);
        data_out    : out std_logic_vector(31 downto 0);
        data_valid  : out std_logic;
        busy        : out std_logic
    );
end spi_master;

architecture behavioral of spi_master is
    signal busy_int : std_logic := '0';
    signal counter  : integer range 0 to 1000 := 0;
    signal sclk_int : std_logic := '0';
begin
    
    busy <= busy_int;
    sclk <= sclk_int;
    mosi <= '0';  -- Dummy MOSI
    cs <= "1110"; -- Default CS pattern
    data_out <= x"DEADBEEF";  -- Dummy read data
    
    -- Simple behavioral model
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                busy_int <= '0';
                data_valid <= '0';
                counter <= 0;
                sclk_int <= '0';
            else
                data_valid <= '0';  -- Default
                
                if start = '1' and busy_int = '0' then
                    busy_int <= '1';
                    counter <= 0;
                elsif busy_int = '1' then
                    counter <= counter + 1;
                    sclk_int <= not sclk_int;  -- Toggle clock
                    if counter = 64 then  -- Simulate SPI transaction time
                        busy_int <= '0';
                        data_valid <= '1';
                        counter <= 0;
                        sclk_int <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
end behavioral;