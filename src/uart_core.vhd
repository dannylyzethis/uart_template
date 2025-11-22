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
    constant FIFO_DEPTH   : integer := 16;  -- 16-deep FIFOs

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
    signal rx_byte_received : std_logic := '0';  -- Internal flag for byte completion

    -- TX Internal Signals
    signal tx_clk_count  : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal tx_bit_index  : integer range 0 to 7 := 0;
    signal tx_byte       : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_line       : std_logic := '1';
    signal tx_busy_flag  : std_logic := '0';

    -- RX FIFO signals
    type fifo_array_type is array (0 to FIFO_DEPTH-1) of std_logic_vector(7 downto 0);
    signal rx_fifo       : fifo_array_type := (others => (others => '0'));
    signal rx_wr_ptr     : integer range 0 to FIFO_DEPTH-1 := 0;
    signal rx_rd_ptr     : integer range 0 to FIFO_DEPTH-1 := 0;
    signal rx_fifo_count : integer range 0 to FIFO_DEPTH := 0;
    signal rx_fifo_empty : std_logic := '1';
    signal rx_fifo_full  : std_logic := '0';

    -- TX FIFO signals
    signal tx_fifo       : fifo_array_type := (others => (others => '0'));
    signal tx_wr_ptr     : integer range 0 to FIFO_DEPTH-1 := 0;
    signal tx_rd_ptr     : integer range 0 to FIFO_DEPTH-1 := 0;
    signal tx_fifo_count : integer range 0 to FIFO_DEPTH := 0;
    signal tx_fifo_empty : std_logic := '1';
    signal tx_fifo_full  : std_logic := '0';
    signal tx_start_transmission : std_logic := '0';
    
begin

    -- Output assignments
    -- RX outputs: Read from FIFO
    rx_data <= rx_fifo(rx_rd_ptr);
    rx_valid <= rx_valid_flag;
    tx <= tx_line;
    -- TX busy when UART is transmitting OR FIFO is not empty
    tx_busy <= tx_busy_flag or (not tx_fifo_empty);
    
    -- UART RX Process
    rx_process: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_state <= RX_IDLE;
                rx_clk_count <= 0;
                rx_bit_index <= 0;
                rx_byte <= (others => '0');
                rx_byte_received <= '0';
            else
                rx_byte_received <= '0';  -- Default: clear received flag
                
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
                            rx_byte_received <= '1';  -- Signal that byte is received
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

                        -- Start transmission when FIFO has data
                        if tx_start_transmission = '1' then
                            tx_byte <= tx_fifo(tx_rd_ptr);
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

    -- RX FIFO Management Process
    -- Maintains compatibility: rx_valid pulses for one cycle when data available
    rx_fifo_process: process(clk)
        variable write_occurred : boolean;
        variable read_occurred  : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_wr_ptr <= 0;
                rx_rd_ptr <= 0;
                rx_fifo_count <= 0;
                rx_fifo_empty <= '1';
                rx_fifo_full <= '0';
                rx_valid_flag <= '0';
            else
                write_occurred := false;
                read_occurred := false;

                -- Write to RX FIFO when byte is received and FIFO not full
                if rx_byte_received = '1' and rx_fifo_full = '0' then
                    rx_fifo(rx_wr_ptr) <= rx_byte;
                    if rx_wr_ptr = FIFO_DEPTH-1 then
                        rx_wr_ptr <= 0;
                    else
                        rx_wr_ptr <= rx_wr_ptr + 1;
                    end if;
                    write_occurred := true;
                end if;

                -- Auto-read: Advance to next byte after rx_valid pulse
                -- rx_valid is a single-cycle pulse, similar to original behavior
                if rx_valid_flag = '1' and rx_fifo_empty = '0' then
                    if rx_rd_ptr = FIFO_DEPTH-1 then
                        rx_rd_ptr <= 0;
                    else
                        rx_rd_ptr <= rx_rd_ptr + 1;
                    end if;
                    read_occurred := true;
                end if;

                -- Update FIFO count
                if write_occurred and not read_occurred then
                    rx_fifo_count <= rx_fifo_count + 1;
                elsif read_occurred and not write_occurred then
                    rx_fifo_count <= rx_fifo_count - 1;
                end if;

                -- Update FIFO status flags
                rx_fifo_empty <= '0';
                rx_fifo_full <= '0';
                if rx_fifo_count = 0 and not write_occurred then
                    rx_fifo_empty <= '1';
                elsif rx_fifo_count = 1 and read_occurred and not write_occurred then
                    rx_fifo_empty <= '1';
                end if;
                if rx_fifo_count = FIFO_DEPTH then
                    rx_fifo_full <= '1';
                elsif rx_fifo_count = FIFO_DEPTH-1 and write_occurred and not read_occurred then
                    rx_fifo_full <= '1';
                end if;

                -- Generate rx_valid pulse when FIFO has data
                -- Pulse for one cycle when data becomes available
                if rx_fifo_empty = '0' and rx_valid_flag = '0' then
                    rx_valid_flag <= '1';
                else
                    rx_valid_flag <= '0';
                end if;
            end if;
        end if;
    end process;

    -- TX FIFO Management Process
    tx_fifo_process: process(clk)
        variable write_occurred : boolean;
        variable read_occurred  : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tx_wr_ptr <= 0;
                tx_rd_ptr <= 0;
                tx_fifo_count <= 0;
                tx_fifo_empty <= '1';
                tx_fifo_full <= '0';
                tx_start_transmission <= '0';
            else
                write_occurred := false;
                read_occurred := false;
                tx_start_transmission <= '0';  -- Default: clear start flag

                -- Write to TX FIFO when host sends data and FIFO not full
                if tx_send = '1' and tx_fifo_full = '0' then
                    tx_fifo(tx_wr_ptr) <= tx_data;
                    if tx_wr_ptr = FIFO_DEPTH-1 then
                        tx_wr_ptr <= 0;
                    else
                        tx_wr_ptr <= tx_wr_ptr + 1;
                    end if;
                    write_occurred := true;
                end if;

                -- Start transmission when FIFO has data and UART is idle
                if tx_fifo_empty = '0' and tx_state = TX_IDLE and tx_busy_flag = '0' then
                    tx_start_transmission <= '1';
                    -- Advance read pointer
                    if tx_rd_ptr = FIFO_DEPTH-1 then
                        tx_rd_ptr <= 0;
                    else
                        tx_rd_ptr <= tx_rd_ptr + 1;
                    end if;
                    read_occurred := true;
                end if;

                -- Update FIFO count
                if write_occurred and not read_occurred then
                    tx_fifo_count <= tx_fifo_count + 1;
                elsif read_occurred and not write_occurred then
                    tx_fifo_count <= tx_fifo_count - 1;
                end if;

                -- Update FIFO status flags
                tx_fifo_empty <= '0';
                tx_fifo_full <= '0';
                if tx_fifo_count = 0 and not write_occurred then
                    tx_fifo_empty <= '1';
                elsif tx_fifo_count = 1 and read_occurred and not write_occurred then
                    tx_fifo_empty <= '1';
                end if;
                if tx_fifo_count = FIFO_DEPTH then
                    tx_fifo_full <= '1';
                elsif tx_fifo_count = FIFO_DEPTH-1 and write_occurred and not read_occurred then
                    tx_fifo_full <= '1';
                end if;
            end if;
        end if;
    end process;

end behavioral;
