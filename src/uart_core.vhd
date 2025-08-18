-- Clean UART Core for Testing
-- No signal name conflicts

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_core is
    generic (
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 115200
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        rx        : in  std_logic;
        tx        : out std_logic;
        rx_data   : out std_logic_vector(7 downto 0);
        rx_valid  : out std_logic;
        tx_data   : in  std_logic_vector(7 downto 0);
        tx_send   : in  std_logic;
        tx_busy   : out std_logic
    );
end uart_core;

architecture behavioral of uart_core is
    
    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;
    
    -- RX State Machine
    type rx_state_type is (RX_IDLE, RX_START, RX_DATA_BITS, RX_STOP);
    signal rx_state : rx_state_type := RX_IDLE;
    
    -- TX State Machine  
    type tx_state_type is (TX_IDLE, TX_START, TX_DATA_BITS, TX_STOP);
    signal tx_state : tx_state_type := TX_IDLE;
    
    -- RX Internal Signals
    signal rx_clk_count  : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal rx_bit_index  : integer range 0 to 7 := 0;
    signal rx_byte       : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_valid_flag : std_logic := '0';
    
    -- TX Internal Signals
    signal tx_clk_count  : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal tx_bit_index  : integer range 0 to 7 := 0;
    signal tx_byte       : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_line       : std_logic := '1';
    signal tx_busy_flag  : std_logic := '0';
    
begin
    
    -- Output assignments
    rx_data <= rx_byte;
    rx_valid <= rx_valid_flag;
    tx <= tx_line;
    tx_busy <= tx_busy_flag;
    
    -- UART RX Process
    rx_process: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_state <= RX_IDLE;
                rx_clk_count <= 0;
                rx_bit_index <= 0;
                rx_byte <= (others => '0');
                rx_valid_flag <= '0';
            else
                rx_valid_flag <= '0';  -- Default: clear valid flag
                
                case rx_state is
                    when RX_IDLE =>
                        rx_clk_count <= 0;
                        rx_bit_index <= 0;
                        
                        if rx = '0' then  -- Start bit detected
                            rx_state <= RX_START;
                        end if;
                    
                    when RX_START =>
                        if rx_clk_count = CLKS_PER_BIT/2 then
                            if rx = '0' then  -- Confirm start bit
                                rx_clk_count <= 0;
                                rx_state <= RX_DATA_BITS;
                            else
                                rx_state <= RX_IDLE;  -- False start
                            end if;
                        else
                            rx_clk_count <= rx_clk_count + 1;
                        end if;
                    
                    when RX_DATA_BITS =>
                        if rx_clk_count = CLKS_PER_BIT-1 then
                            rx_clk_count <= 0;
                            rx_byte(rx_bit_index) <= rx;
                            
                            if rx_bit_index = 7 then
                                rx_bit_index <= 0;
                                rx_state <= RX_STOP;
                            else
                                rx_bit_index <= rx_bit_index + 1;
                            end if;
                        else
                            rx_clk_count <= rx_clk_count + 1;
                        end if;
                    
                    when RX_STOP =>
                        if rx_clk_count = CLKS_PER_BIT-1 then
                            rx_valid_flag <= '1';  -- Data is valid
                            rx_clk_count <= 0;
                            rx_state <= RX_IDLE;
                        else
                            rx_clk_count <= rx_clk_count + 1;
                        end if;
                    
                    when others =>
                        rx_state <= RX_IDLE;
                end case;
            end if;
        end if;
    end process;
    
    -- UART TX Process
    tx_process: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tx_state <= TX_IDLE;
                tx_clk_count <= 0;
                tx_bit_index <= 0;
                tx_byte <= (others => '0');
                tx_line <= '1';
                tx_busy_flag <= '0';
            else
                case tx_state is
                    when TX_IDLE =>
                        tx_line <= '1';  -- Idle high
                        tx_clk_count <= 0;
                        tx_bit_index <= 0;
                        tx_busy_flag <= '0';
                        
                        if tx_send = '1' then
                            tx_byte <= tx_data;
                            tx_busy_flag <= '1';
                            tx_state <= TX_START;
                        end if;
                    
                    when TX_START =>
                        tx_line <= '0';  -- Start bit
                        
                        if tx_clk_count = CLKS_PER_BIT-1 then
                            tx_clk_count <= 0;
                            tx_state <= TX_DATA_BITS;
                        else
                            tx_clk_count <= tx_clk_count + 1;
                        end if;
                    
                    when TX_DATA_BITS =>
                        tx_line <= tx_byte(tx_bit_index);
                        
                        if tx_clk_count = CLKS_PER_BIT-1 then
                            tx_clk_count <= 0;
                            
                            if tx_bit_index = 7 then
                                tx_bit_index <= 0;
                                tx_state <= TX_STOP;
                            else
                                tx_bit_index <= tx_bit_index + 1;
                            end if;
                        else
                            tx_clk_count <= tx_clk_count + 1;
                        end if;
                    
                    when TX_STOP =>
                        tx_line <= '1';  -- Stop bit
                        
                        if tx_clk_count = CLKS_PER_BIT-1 then
                            tx_clk_count <= 0;
                            tx_state <= TX_IDLE;
                        else
                            tx_clk_count <= tx_clk_count + 1;
                        end if;
                    
                    when others =>
                        tx_state <= TX_IDLE;
                end case;
            end if;
        end if;
    end process;
    
end behavioral;
