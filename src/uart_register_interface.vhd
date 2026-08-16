-- UART Register Interface with CRC for RF Test Control
-- Consistent addressing scheme for FPGA-based instrument control
-- Fixed for VHDL-2002 compatibility

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_register_interface is
    generic (
        CLK_FREQ        : integer := 100_000_000;  -- System clock frequency
        BAUD_RATE       : integer := 115200        -- UART baud rate
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- UART interface
        uart_rx         : in  std_logic;
        uart_tx         : out std_logic;
        
        -- Control registers (write from host)
        ctrl_reg0       : out std_logic_vector(63 downto 0);
        ctrl_reg1       : out std_logic_vector(63 downto 0);
        ctrl_reg2       : out std_logic_vector(63 downto 0);
        ctrl_reg3       : out std_logic_vector(63 downto 0);
        ctrl_reg4       : out std_logic_vector(63 downto 0);
        ctrl_reg5       : out std_logic_vector(63 downto 0);
        ctrl_write_strobe : out std_logic_vector(5 downto 0);
        
        -- Status registers (read by host)
        status_reg0     : in  std_logic_vector(63 downto 0);
        status_reg1     : in  std_logic_vector(63 downto 0);
        status_reg2     : in  std_logic_vector(63 downto 0);
        status_reg3     : in  std_logic_vector(63 downto 0);
        status_reg4     : in  std_logic_vector(63 downto 0);
        status_reg5     : in  std_logic_vector(63 downto 0);
        status_read_strobe : out std_logic_vector(5 downto 0);
        
        -- I2C interface 0
        i2c0_sda        : inout std_logic;
        i2c0_scl        : inout std_logic;
        i2c0_busy       : in    std_logic;
        i2c0_start      : out   std_logic;
        i2c0_data_in    : out   std_logic_vector(7 downto 0);
        i2c0_data_out   : in    std_logic_vector(7 downto 0);
        i2c0_data_valid : in    std_logic;
        i2c0_ack_error  : in    std_logic;
        
        -- I2C interface 1
        i2c1_sda        : inout std_logic;
        i2c1_scl        : inout std_logic;
        i2c1_busy       : in    std_logic;
        i2c1_start      : out   std_logic;
        i2c1_data_in    : out   std_logic_vector(7 downto 0);
        i2c1_data_out   : in    std_logic_vector(7 downto 0);
        i2c1_data_valid : in    std_logic;
        i2c1_ack_error  : in    std_logic;
        
        -- SPI interface 0
        spi0_sclk       : out   std_logic;
        spi0_mosi       : out   std_logic;
        spi0_miso       : in    std_logic;
        spi0_cs         : out   std_logic_vector(3 downto 0);
        spi0_start      : out   std_logic;
        spi0_busy       : in    std_logic;
        spi0_data_in    : out   std_logic_vector(31 downto 0);
        spi0_data_out   : in    std_logic_vector(31 downto 0);
        spi0_data_valid : in    std_logic;
        
        -- SPI interface 1
        spi1_sclk       : out   std_logic;
        spi1_mosi       : out   std_logic;
        spi1_miso       : in    std_logic;
        spi1_cs         : out   std_logic_vector(3 downto 0);
        spi1_start      : out   std_logic;
        spi1_busy       : in    std_logic;
        spi1_data_in    : out   std_logic_vector(31 downto 0);
        spi1_data_out   : in    std_logic_vector(31 downto 0);
        spi1_data_valid : in    std_logic;
        
        -- Status outputs
        cmd_valid       : out std_logic;
        cmd_error       : out std_logic;
        crc_error       : out std_logic;
        timeout_error   : out std_logic
    );
end uart_register_interface;

architecture behavioral of uart_register_interface is
    
    -- UART component (simplified - you'd use your preferred UART core)
    component uart_core is
        generic (
            CLK_FREQ  : integer;
            BAUD_RATE : integer
        );
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            rx        : in  std_logic;
            tx        : out std_logic;
            rx_data   : out std_logic_vector(7 downto 0);
            rx_valid  : out std_logic;
            framing_error : out std_logic;
            tx_data   : in  std_logic_vector(7 downto 0);
            tx_send   : in  std_logic;
            tx_busy   : out std_logic
        );
    end component;
    
    -- CRC-8 calculation function
    function crc8_update(crc_in: std_logic_vector(7 downto 0); 
                        data_in: std_logic_vector(7 downto 0)) 
                        return std_logic_vector is
        variable crc_out : std_logic_vector(7 downto 0) := crc_in;
    begin
        for bit_index in 7 downto 0 loop
            if (crc_out(7) xor data_in(bit_index)) = '1' then
                crc_out := (crc_out(6 downto 0) & '0') xor x"07";
            else
                crc_out := crc_out(6 downto 0) & '0';
            end if;
        end loop;
        return crc_out;
    end function;
    
    -- Command packet format: [CMD][ADDR][DATA0..DATA7][CRC]
    -- CMD: 8-bit command (0x01=Write Control, 0x02=Read Status)
    -- ADDR: 8-bit register address (0x00-0x06 for control, 0x10-0x16 for status)
    -- DATA: 64-bit data (big endian)
    -- CRC: 8-bit CRC-8 of all previous bytes
    
    type state_type is (IDLE, RX_CMD, RX_ADDR, RX_DATA0, RX_DATA1, 
                       RX_DATA2, RX_DATA3, RX_DATA4, RX_DATA5, RX_DATA6, RX_DATA7, 
                       RX_CRC, PROCESS_CMD, 
                       TX_RESPONSE, TX_DATA0, TX_DATA1, TX_DATA2, TX_DATA3, 
                       TX_DATA4, TX_DATA5, TX_DATA6, TX_DATA7, TX_CRC_OUT);
    
    signal state : state_type := IDLE;
    
    -- UART signals
    signal rx_data    : std_logic_vector(7 downto 0);
    signal rx_valid   : std_logic;
    signal uart_framing_error : std_logic;
    signal tx_data    : std_logic_vector(7 downto 0);
    signal tx_send    : std_logic;
    signal tx_busy    : std_logic;
    
    -- UART RX synchronizer chain (critical for clock domain crossing)
    signal uart_rx_sync : std_logic_vector(2 downto 0) := "111";
    
    -- Command packet registers
    signal cmd_byte   : std_logic_vector(7 downto 0);
    signal addr_byte  : std_logic_vector(7 downto 0);
    signal data_word  : std_logic_vector(63 downto 0);
    signal received_crc : std_logic_vector(7 downto 0);
    signal calc_crc   : std_logic_vector(7 downto 0);
    
    -- Internal control registers
    type ctrl_reg_array_type is array (0 to 5) of std_logic_vector(63 downto 0);
    signal ctrl_registers : ctrl_reg_array_type := (others => (others => '0'));
    
    -- Control signals
    signal cmd_valid_int  : std_logic := '0';

    -- Sticky error register (read at 0x16, write-one-to-clear at 0x06).
    -- Bits 63:8 are reserved for future error sources.
    constant ERR_INVALID_OPCODE : integer := 0;
    constant ERR_INVALID_ADDRESS: integer := 1;
    constant ERR_CRC            : integer := 2;
    constant ERR_TIMEOUT        : integer := 3;
    constant ERR_UART_FRAMING   : integer := 4;
    constant ERR_UNEXPECTED_RX  : integer := 5;
    constant ERR_I2C0_ACK       : integer := 6;
    constant ERR_I2C1_ACK       : integer := 7;
    signal error_flags_int : std_logic_vector(63 downto 0) := (others => '0');
    
    -- Response data
    signal response_data : std_logic_vector(63 downto 0);
    signal tx_crc_calc   : std_logic_vector(7 downto 0);
    
    -- I2C/SPI control signals
    signal i2c0_start_int : std_logic := '0';
    signal i2c1_start_int : std_logic := '0';
    signal spi0_start_int : std_logic := '0';
    signal spi1_start_int : std_logic := '0';
    
    -- SPI configuration registers (extracted from control registers)
    signal spi0_config    : std_logic_vector(63 downto 0);
    signal spi1_config    : std_logic_vector(63 downto 0);
    
    -- Internal strobe signals for reading outputs
    signal ctrl_write_strobe_int : std_logic_vector(5 downto 0);
    signal status_read_strobe_int : std_logic_vector(5 downto 0);

    -- Timeout and watchdog
    constant TIMEOUT_CYCLES : integer := CLK_FREQ / 100;  -- 10 ms
    signal timeout_counter : integer range 0 to TIMEOUT_CYCLES := 0;

begin
    
    -- UART RX synchronizer for clock domain crossing
    -- Essential for reliable operation with asynchronous UART input
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                uart_rx_sync <= "111";  -- Initialize to idle state
            else
                -- Two FF synchronizer chain
                uart_rx_sync <= uart_rx_sync(1 downto 0) & uart_rx;
            end if;
        end if;
    end process;
    
    -- UART instantiation
    uart_inst: uart_core
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk      => clk,
            rst      => rst,
            rx       => uart_rx_sync(2),  -- Use synchronized RX signal
            tx       => uart_tx,
            rx_data  => rx_data,
            rx_valid => rx_valid,
            framing_error => uart_framing_error,
            tx_data  => tx_data,
            tx_send  => tx_send,
            tx_busy  => tx_busy
        );
    
    -- Main state machine
    process(clk)
        variable addr_int : integer range 0 to 255;
        variable error_set_mask   : std_logic_vector(63 downto 0);
        variable error_clear_mask : std_logic_vector(63 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                calc_crc <= (others => '0');
                cmd_valid_int <= '0';
                tx_send <= '0';
                ctrl_write_strobe_int <= (others => '0');
                status_read_strobe_int <= (others => '0');
                ctrl_registers <= (others => (others => '0'));
                timeout_counter <= 0;
                error_flags_int <= (others => '0');

            else
                error_set_mask := (others => '0');
                error_clear_mask := (others => '0');

                if uart_framing_error = '1' then
                    error_set_mask(ERR_UART_FRAMING) := '1';
                end if;
                if i2c0_ack_error = '1' then
                    error_set_mask(ERR_I2C0_ACK) := '1';
                end if;
                if i2c1_ack_error = '1' then
                    error_set_mask(ERR_I2C1_ACK) := '1';
                end if;
                if rx_valid = '1' and
                   (state = PROCESS_CMD or state = TX_RESPONSE or
                    state = TX_DATA0 or state = TX_DATA1 or state = TX_DATA2 or
                    state = TX_DATA3 or state = TX_DATA4 or state = TX_DATA5 or
                    state = TX_DATA6 or state = TX_DATA7 or state = TX_CRC_OUT) then
                    error_set_mask(ERR_UNEXPECTED_RX) := '1';
                end if;

                -- Clear strobes by default
                ctrl_write_strobe_int <= (others => '0');
                status_read_strobe_int <= (others => '0');
                tx_send <= '0';
                cmd_valid_int <= '0';

                -- Timeout watchdog counter
                if state = IDLE then
                    timeout_counter <= 0;
                else
                    if timeout_counter = TIMEOUT_CYCLES - 1 then
                        -- Timeout occurred - force return to IDLE
                        error_set_mask(ERR_TIMEOUT) := '1';
                        state <= IDLE;
                        timeout_counter <= 0;
                    else
                        timeout_counter <= timeout_counter + 1;
                    end if;
                end if;

                -- Only process commands if not in timeout
                if timeout_counter /= TIMEOUT_CYCLES - 1 then
                    case state is
                        when IDLE =>
                            if rx_valid = '1' then
                            cmd_byte <= rx_data;
                            calc_crc <= crc8_update(x"00", rx_data);
                            state <= RX_ADDR;
                        end if;
                    
                    when RX_ADDR =>
                        if rx_valid = '1' then
                            addr_byte <= rx_data;
                            calc_crc <= crc8_update(calc_crc, rx_data);
                            state <= RX_DATA0;
                        end if;
                    
                    when RX_DATA0 =>
                        if rx_valid = '1' then
                            data_word(63 downto 56) <= rx_data;
                            calc_crc <= crc8_update(calc_crc, rx_data);
                            state <= RX_DATA1;
                        end if;
                    
                    when RX_DATA1 =>
                        if rx_valid = '1' then
                            data_word(55 downto 48) <= rx_data;
                            calc_crc <= crc8_update(calc_crc, rx_data);
                            state <= RX_DATA2;
                        end if;
                    
                    when RX_DATA2 =>
                        if rx_valid = '1' then
                            data_word(47 downto 40) <= rx_data;
                            calc_crc <= crc8_update(calc_crc, rx_data);
                            state <= RX_DATA3;
                        end if;
                    
                    when RX_DATA3 =>
                        if rx_valid = '1' then
                            data_word(39 downto 32) <= rx_data;
                            calc_crc <= crc8_update(calc_crc, rx_data);
                            state <= RX_DATA4;
                        end if;
                    
                    when RX_DATA4 =>
                        if rx_valid = '1' then
                            data_word(31 downto 24) <= rx_data;
                            calc_crc <= crc8_update(calc_crc, rx_data);
                            state <= RX_DATA5;
                        end if;
                    
                    when RX_DATA5 =>
                        if rx_valid = '1' then
                            data_word(23 downto 16) <= rx_data;
                            calc_crc <= crc8_update(calc_crc, rx_data);
                            state <= RX_DATA6;
                        end if;
                    
                    when RX_DATA6 =>
                        if rx_valid = '1' then
                            data_word(15 downto 8) <= rx_data;
                            calc_crc <= crc8_update(calc_crc, rx_data);
                            state <= RX_DATA7;
                        end if;
                    
                    when RX_DATA7 =>
                        if rx_valid = '1' then
                            data_word(7 downto 0) <= rx_data;
                            calc_crc <= crc8_update(calc_crc, rx_data);
                            state <= RX_CRC;
                        end if;
                    
                    when RX_CRC =>
                        if rx_valid = '1' then
                            received_crc <= rx_data;
                            state <= PROCESS_CMD;
                        end if;
                    
                    when PROCESS_CMD =>
                        -- Check CRC
                        if calc_crc /= received_crc then
                            error_set_mask(ERR_CRC) := '1';
                            state <= IDLE;
                        else
                            addr_int := to_integer(unsigned(addr_byte));
                            cmd_valid_int <= '1';
                            
                            case cmd_byte is
                                when x"01" => -- Write Control Register
                                    if addr_int >= 0 and addr_int <= 5 then
                                        ctrl_registers(addr_int) <= data_word;
                                        ctrl_write_strobe_int(addr_int) <= '1';
                                        state <= IDLE;
                                    elsif addr_int = 6 then
                                        error_clear_mask := data_word;
                                        state <= IDLE;
                                    else
                                        error_set_mask(ERR_INVALID_ADDRESS) := '1';
                                        state <= IDLE;
                                    end if;
                                
                                when x"02" => -- Read Status Register
                                    if addr_int >= 16 and addr_int <= 22 then -- 0x10-0x16
                                        case addr_int is
                                            when 16 => response_data <= status_reg0;
                                            when 17 => response_data <= status_reg1;
                                            when 18 => response_data <= status_reg2;
                                            when 19 => response_data <= status_reg3;
                                            when 20 => response_data <= status_reg4;
                                            when 21 => response_data <= status_reg5;
                                            when 22 => response_data <= error_flags_int or error_set_mask;
                                            when others => response_data <= (others => '0');
                                        end case;
                                        if addr_int <= 21 then
                                            status_read_strobe_int(addr_int - 16) <= '1';
                                        end if;
                                        -- Start CRC calculation for response
                                        tx_crc_calc <= crc8_update(x"00", x"02"); -- Response header
                                        state <= TX_RESPONSE;
                                    else
                                        error_set_mask(ERR_INVALID_ADDRESS) := '1';
                                        state <= IDLE;
                                    end if;
                                
                                when others =>
                                    error_set_mask(ERR_INVALID_OPCODE) := '1';
                                    state <= IDLE;
                            end case;
                        end if;
                    
                    when TX_RESPONSE =>
                        if tx_busy = '0' then
                            tx_data <= x"02"; -- Response header
                            tx_send <= '1';
                            state <= TX_DATA0;
                        end if;
                    
                    when TX_DATA0 =>
                        if tx_busy = '0' and tx_send = '0' then
                            tx_data <= response_data(63 downto 56);
                            tx_crc_calc <= crc8_update(tx_crc_calc, response_data(63 downto 56));
                            tx_send <= '1';
                            state <= TX_DATA1;
                        end if;
                    
                    when TX_DATA1 =>
                        if tx_busy = '0' and tx_send = '0' then
                            tx_data <= response_data(55 downto 48);
                            tx_crc_calc <= crc8_update(tx_crc_calc, response_data(55 downto 48));
                            tx_send <= '1';
                            state <= TX_DATA2;
                        end if;
                    
                    when TX_DATA2 =>
                        if tx_busy = '0' and tx_send = '0' then
                            tx_data <= response_data(47 downto 40);
                            tx_crc_calc <= crc8_update(tx_crc_calc, response_data(47 downto 40));
                            tx_send <= '1';
                            state <= TX_DATA3;
                        end if;
                    
                    when TX_DATA3 =>
                        if tx_busy = '0' and tx_send = '0' then
                            tx_data <= response_data(39 downto 32);
                            tx_crc_calc <= crc8_update(tx_crc_calc, response_data(39 downto 32));
                            tx_send <= '1';
                            state <= TX_DATA4;
                        end if;
                    
                    when TX_DATA4 =>
                        if tx_busy = '0' and tx_send = '0' then
                            tx_data <= response_data(31 downto 24);
                            tx_crc_calc <= crc8_update(tx_crc_calc, response_data(31 downto 24));
                            tx_send <= '1';
                            state <= TX_DATA5;
                        end if;
                    
                    when TX_DATA5 =>
                        if tx_busy = '0' and tx_send = '0' then
                            tx_data <= response_data(23 downto 16);
                            tx_crc_calc <= crc8_update(tx_crc_calc, response_data(23 downto 16));
                            tx_send <= '1';
                            state <= TX_DATA6;
                        end if;
                    
                    when TX_DATA6 =>
                        if tx_busy = '0' and tx_send = '0' then
                            tx_data <= response_data(15 downto 8);
                            tx_crc_calc <= crc8_update(tx_crc_calc, response_data(15 downto 8));
                            tx_send <= '1';
                            state <= TX_DATA7;
                        end if;
                    
                    when TX_DATA7 =>
                        if tx_busy = '0' and tx_send = '0' then
                            tx_data <= response_data(7 downto 0);
                            tx_crc_calc <= crc8_update(tx_crc_calc, response_data(7 downto 0));
                            tx_send <= '1';
                            state <= TX_CRC_OUT;
                        end if;
                    
                    when TX_CRC_OUT =>
                        if tx_busy = '0' and tx_send = '0' then
                            tx_data <= tx_crc_calc;
                            tx_send <= '1';
                            state <= IDLE;
                        end if;
                    
                        when others =>
                            state <= IDLE;
                    end case;
                end if;  -- timeout check

                -- New hardware errors win over a simultaneous software clear.
                error_flags_int <= (error_flags_int and not error_clear_mask) or error_set_mask;
            end if;  -- reset check
        end if;  -- rising_edge
    end process;
    
    -- Output control registers
    ctrl_reg0 <= ctrl_registers(0);
    ctrl_reg1 <= ctrl_registers(1);
    ctrl_reg2 <= ctrl_registers(2);
    ctrl_reg3 <= ctrl_registers(3);
    ctrl_reg4 <= ctrl_registers(4);
    ctrl_reg5 <= ctrl_registers(5);
    
    -- Output strobe signals
    ctrl_write_strobe <= ctrl_write_strobe_int;
    status_read_strobe <= status_read_strobe_int;
    
    -- Extract SPI configuration
    spi0_config <= ctrl_registers(4);  -- Control register 4 for SPI0 config
    spi1_config <= ctrl_registers(5);  -- Control register 5 for SPI1 config
    
    -- I2C control outputs
    -- These bus ports are passive in the register-interface block. The actual
    -- I2C masters own the open-drain drivers at the system integration level.
    i2c0_sda <= 'Z';
    i2c0_scl <= 'Z';
    i2c1_sda <= 'Z';
    i2c1_scl <= 'Z';

    i2c0_start <= i2c0_start_int;
    i2c1_start <= i2c1_start_int;
    
    -- I2C data outputs (from control registers)
    i2c0_data_in <= ctrl_registers(2)(15 downto 8);   -- Byte 1 of ctrl_reg2
    i2c1_data_in <= ctrl_registers(2)(7 downto 0);    -- Byte 0 of ctrl_reg2
    
    -- SPI control outputs
    spi0_start <= spi0_start_int;
    spi1_start <= spi1_start_int;
    
    -- SPI data outputs (from control registers)
    spi0_data_in <= ctrl_registers(3)(63 downto 32);  -- Upper 32 bits of ctrl_reg3
    spi1_data_in <= ctrl_registers(3)(31 downto 0);   -- Lower 32 bits of ctrl_reg3
    
    -- The external SPI masters own the physical bus outputs. Drive high
    -- impedance here to avoid a second driver when this register block and
    -- the masters are connected to the same top-level nets.
    spi0_sclk <= 'Z';
    spi0_mosi <= 'Z';
    spi0_cs <= (others => 'Z');
    spi1_sclk <= 'Z';
    spi1_mosi <= 'Z';
    spi1_cs <= (others => 'Z');
    
    -- I2C/SPI trigger logic
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                i2c0_start_int <= '0';
                i2c1_start_int <= '0';
                spi0_start_int <= '0';
                spi1_start_int <= '0';
            else
                -- Generate single-cycle start pulses when control registers are written
                i2c0_start_int <= '0';
                i2c1_start_int <= '0';
                spi0_start_int <= '0';
                spi1_start_int <= '0';
                
                -- Trigger I2C transactions when ctrl_reg2 is written
                if ctrl_write_strobe_int(2) = '1' then
                    if ctrl_registers(2)(63) = '1' then  -- I2C0 enable bit
                        i2c0_start_int <= '1';
                    end if;
                    if ctrl_registers(2)(31) = '1' then  -- I2C1 enable bit
                        i2c1_start_int <= '1';
                    end if;
                end if;
                
                -- SPI configuration writes only update settings. Writing the
                -- shared data register launches each enabled SPI channel, so
                -- the newly written transmit word is already available.
                if ctrl_write_strobe_int(3) = '1' then
                    if spi0_config(63) = '1' then  -- SPI0 enable bit
                        spi0_start_int <= '1';
                    end if;
                    if spi1_config(63) = '1' then  -- SPI1 enable bit
                        spi1_start_int <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Output status signals
    cmd_valid <= cmd_valid_int;
    cmd_error <= error_flags_int(ERR_INVALID_OPCODE) or
                 error_flags_int(ERR_INVALID_ADDRESS) or
                 error_flags_int(ERR_UNEXPECTED_RX);
    crc_error <= error_flags_int(ERR_CRC);
    timeout_error <= error_flags_int(ERR_TIMEOUT);

end behavioral;


-- Updated Register Map for RF Test Control with I2C/SPI:
-- 
-- CONTROL REGISTERS (Write from LabVIEW):
-- Address 0x00: Control Register 0 - System Control
--   [63:32] Reserved
--   [31:16] Reserved  
--   [15:8]  Reserved
--   [7:0]   System control bits (reset, enable, etc.)
--
-- Address 0x01: Control Register 1 - Switch Control
--   [63:48] Switch Bank 3 positions
--   [47:32] Switch Bank 2 positions  
--   [31:16] Switch Bank 1 positions
--   [15:0]  Switch Bank 0 positions
--
-- Address 0x02: Control Register 2 - I2C Control & Data
--   [63]    I2C0 Start transaction (write 1 to trigger)
--   [62:56] I2C0 Device address (7-bit)
--   [55:48] Reserved
--   [47:32] Reserved
--   [31]    I2C1 Start transaction (write 1 to trigger)
--   [30:24] I2C1 Device address (7-bit)
--   [23:16] Reserved
--   [15:8]  I2C0 Data byte
--   [7:0]   I2C1 Data byte
--
-- Address 0x03: Control Register 3 - SPI Data
--   [63:32] SPI0 32-bit data to transmit
--   [31:0]  SPI1 32-bit data to transmit
--
-- Address 0x04: Control Register 4 - SPI0 Configuration
--   [63]    SPI0 Enable/Start transaction
--   [62]    Clock polarity (CPOL): 0=idle low, 1=idle high
--   [61]    Clock phase (CPHA): 0=sample leading edge, 1=sample trailing edge
--   [60:56] Word length (5-32 bits, actual length = value + 1)
--   [55:40] Clock divider (divide system clock by this value)
--   [39:36] Reserved
--   [35:32] Chip select (4-bit, one-hot encoded)
--   [31:0]  Reserved
--
-- Address 0x05: Control Register 5 - SPI1 Configuration
--   [63]    SPI1 Enable/Start transaction  
--   [62]    Clock polarity (CPOL): 0=idle low, 1=idle high
--   [61]    Clock phase (CPHA): 0=sample leading edge, 1=sample trailing edge
--   [60:56] Word length (5-32 bits, actual length = value + 1)
--   [55:40] Clock divider (divide system clock by this value)
--   [39:36] Reserved
--   [35:32] Chip select (4-bit, one-hot encoded)
--   [31:0]  Reserved
--
-- Address 0x06: Sticky Error Clear
--   [63:0]  Write-one-to-clear mask for Status Register 0x16
--
-- STATUS REGISTERS (Read by LabVIEW):
-- Address 0x10: Status Register 0 - System Status
--   [63:32] Timestamp (seconds since reset)
--   [31:24] I2C/SPI busy flags: [7:6]=SPI1/0 busy, [5:4]=I2C1/0 busy
--   [23:16] I2C/SPI error flags: [7:6]=SPI1/0 errors, [5:4]=I2C1/0 ACK errors
--   [15:8]  Temperature (�C)
--   [7:0]   System status bits
--
-- Address 0x11: Status Register 1 - Current Measurements
--   [63:48] Current monitor 3 (�A)
--   [47:32] Current monitor 2 (�A)
--   [31:16] Current monitor 1 (�A)
--   [15:0]  Current monitor 0 (�A)
--
-- Address 0x12: Status Register 2 - Voltage Measurements & I2C Data  
--   [63:48] Voltage monitor 1 (mV)
--   [47:32] Voltage monitor 0 (mV)
--   [31:16] I2C0 received data (last 2 bytes)
--   [15:0]  I2C1 received data (last 2 bytes)
--
-- Address 0x13: Status Register 3 - SPI Received Data
--   [63:32] SPI0 last received 32-bit data
--   [31:0]  SPI1 last received 32-bit data
--
-- Address 0x14: Status Register 4 - Switch Positions Readback
--   [63:48] Switch Bank 3 actual positions
--   [47:32] Switch Bank 2 actual positions
--   [31:16] Switch Bank 1 actual positions
--   [15:0]  Switch Bank 0 actual positions
--
-- Address 0x15: Status Register 5 - Counters & Performance
--   [63:48] SPI transaction counters
--   [47:32] I2C transaction counters  
--   [31:16] Test completion counter
--   [15:0]  Error counter
--
-- Address 0x16: Sticky Error Status
--   [7:0]   Protocol, UART framing, timeout, and I2C ACK error flags
--   [63:8]  Reserved for future error sources
