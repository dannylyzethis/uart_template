-- UART Register Interface with CRC for RF Test Control
-- Consistent addressing scheme for FPGA-based instrument control
-- Fixed for VHDL-2002 compatibility

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_register_interface is
    generic (
        CLK_FREQ        : integer := 100_000_000;  -- System clock frequency
        BAUD_RATE       : integer := 115200;       -- UART baud rate
        DEVICE_ADDRESS  : integer range 0 to 255 := 0  -- Device address (0xFF = broadcast)
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

        -- GPIO outputs (256 bits total = 4 x 64-bit registers, addresses 0x06-0x09)
        gpio_out0       : out std_logic_vector(63 downto 0);
        gpio_out1       : out std_logic_vector(63 downto 0);
        gpio_out2       : out std_logic_vector(63 downto 0);
        gpio_out3       : out std_logic_vector(63 downto 0);
        gpio_write_strobe : out std_logic_vector(3 downto 0);

        -- GPIO inputs (256 bits total = 4 x 64-bit registers, addresses 0x16-0x19)
        gpio_in0        : in  std_logic_vector(63 downto 0);
        gpio_in1        : in  std_logic_vector(63 downto 0);
        gpio_in2        : in  std_logic_vector(63 downto 0);
        gpio_in3        : in  std_logic_vector(63 downto 0);
        gpio_read_strobe : out std_logic_vector(3 downto 0);

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
            tx_data   : in  std_logic_vector(7 downto 0);
            tx_send   : in  std_logic;
            tx_busy   : out std_logic
        );
    end component;
    
    -- CRC-8 calculation function
    function crc8_update(crc_in: std_logic_vector(7 downto 0); 
                        data_in: std_logic_vector(7 downto 0)) 
                        return std_logic_vector is
        variable crc_out : std_logic_vector(7 downto 0);
        variable temp    : std_logic_vector(7 downto 0);
    begin
        temp := crc_in xor data_in;
        crc_out := temp(6 downto 0) & '0';
        if temp(7) = '1' then
            crc_out := crc_out xor x"07";  -- CRC-8 polynomial
        end if;
        return crc_out;
    end function;
    
    -- Command packet format: [DEV_ADDR][CMD][ADDR][DATA0..DATA7][CRC]
    -- DEV_ADDR: 8-bit device address (0x00-0xFE specific device, 0xFF broadcast)
    -- CMD: 8-bit command (0x01=Write Control, 0x02=Read Status)
    -- ADDR: 8-bit register address (0x00-0x05 for control, 0x10-0x15 for status)
    -- DATA: 64-bit data (big endian)
    -- CRC: 8-bit CRC-8 of all previous bytes
    -- Total packet size: 12 bytes

    type state_type is (IDLE, RX_DEV_ADDR, RX_CMD, RX_ADDR, RX_DATA0, RX_DATA1,
                       RX_DATA2, RX_DATA3, RX_DATA4, RX_DATA5, RX_DATA6, RX_DATA7,
                       RX_CRC, PROCESS_CMD,
                       TX_RESPONSE, TX_DATA0, TX_DATA1, TX_DATA2, TX_DATA3,
                       TX_DATA4, TX_DATA5, TX_DATA6, TX_DATA7, TX_CRC_OUT);

    signal state : state_type := IDLE;
    
    -- UART signals
    signal rx_data    : std_logic_vector(7 downto 0);
    signal rx_valid   : std_logic;
    signal tx_data    : std_logic_vector(7 downto 0);
    signal tx_send    : std_logic;
    signal tx_busy    : std_logic;
    
    -- UART RX synchronizer chain (critical for clock domain crossing)
    signal uart_rx_sync : std_logic_vector(2 downto 0) := "111";
    
    -- Command packet registers
    signal dev_addr_byte : std_logic_vector(7 downto 0);
    signal cmd_byte   : std_logic_vector(7 downto 0);
    signal addr_byte  : std_logic_vector(7 downto 0);
    signal data_word  : std_logic_vector(63 downto 0);
    signal received_crc : std_logic_vector(7 downto 0);
    signal calc_crc   : std_logic_vector(7 downto 0);
    signal addr_match : std_logic := '0';  -- Address matched flag
    
    -- Internal control registers (0-5: system/I2C/SPI, 6-9: GPIO)
    type ctrl_reg_array_type is array (0 to 9) of std_logic_vector(63 downto 0);
    signal ctrl_registers : ctrl_reg_array_type := (others => (others => '0'));
    
    -- Control signals
    signal crc_error_int  : std_logic := '0';
    signal cmd_error_int  : std_logic := '0';
    signal cmd_valid_int  : std_logic := '0';
    
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
    signal gpio_write_strobe_int : std_logic_vector(3 downto 0);
    signal gpio_read_strobe_int : std_logic_vector(3 downto 0);

    -- Timeout and watchdog
    constant TIMEOUT_CYCLES : integer := 1_000_000;  -- 10ms at 100MHz (safety timeout)
    signal timeout_counter : integer range 0 to TIMEOUT_CYCLES := 0;
    signal timeout_error   : std_logic := '0';

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
            tx_data  => tx_data,
            tx_send  => tx_send,
            tx_busy  => tx_busy
        );
    
    -- Main state machine
    process(clk)
        variable addr_int : integer range 0 to 255;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                calc_crc <= (others => '0');
                crc_error_int <= '0';
                cmd_error_int <= '0';
                cmd_valid_int <= '0';
                tx_send <= '0';
                ctrl_write_strobe_int <= (others => '0');
                status_read_strobe_int <= (others => '0');
                gpio_write_strobe_int <= (others => '0');
                gpio_read_strobe_int <= (others => '0');
                ctrl_registers <= (others => (others => '0'));
                timeout_counter <= 0;
                timeout_error <= '0';

            else
                -- Clear strobes by default
                ctrl_write_strobe_int <= (others => '0');
                status_read_strobe_int <= (others => '0');
                gpio_write_strobe_int <= (others => '0');
                gpio_read_strobe_int <= (others => '0');
                tx_send <= '0';
                cmd_valid_int <= '0';

                -- Timeout watchdog counter
                if state = IDLE then
                    timeout_counter <= 0;
                    timeout_error <= '0';
                else
                    if timeout_counter = TIMEOUT_CYCLES - 1 then
                        -- Timeout occurred - force return to IDLE
                        timeout_error <= '1';
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
                                dev_addr_byte <= rx_data;
                                calc_crc <= crc8_update(x"00", rx_data);
                                state <= RX_DEV_ADDR;
                                crc_error_int <= '0';
                                cmd_error_int <= '0';
                                addr_match <= '0';
                            end if;

                        when RX_DEV_ADDR =>
                            if rx_valid = '1' then
                                -- Check if address matches this device or is broadcast
                                if (to_integer(unsigned(dev_addr_byte)) = DEVICE_ADDRESS) or
                                   (dev_addr_byte = x"FF") then
                                    -- Address matches - continue receiving command
                                    addr_match <= '1';
                                    cmd_byte <= rx_data;
                                    calc_crc <= crc8_update(calc_crc, rx_data);
                                    state <= RX_ADDR;
                                else
                                    -- Address doesn't match - ignore packet and return to IDLE
                                    addr_match <= '0';
                                    state <= IDLE;
                                end if;
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
                            crc_error_int <= '1';
                            state <= IDLE;
                        else
                            addr_int := to_integer(unsigned(addr_byte));
                            cmd_valid_int <= '1';
                            
                            case cmd_byte is
                                when x"01" => -- Write Control Register
                                    if addr_int >= 0 and addr_int <= 9 then  -- 0x00-0x09 (includes GPIO)
                                        ctrl_registers(addr_int) <= data_word;
                                        -- Strobe system/I2C/SPI registers (0-5)
                                        if addr_int <= 5 then
                                            ctrl_write_strobe_int(addr_int) <= '1';
                                        -- Strobe GPIO registers (6-9)
                                        elsif addr_int >= 6 and addr_int <= 9 then
                                            gpio_write_strobe_int(addr_int - 6) <= '1';
                                        end if;
                                        state <= IDLE;
                                    else
                                        cmd_error_int <= '1';
                                        state <= IDLE;
                                    end if;

                                when x"02" => -- Read Status Register
                                    if addr_int >= 16 and addr_int <= 25 then -- 0x10-0x19 (includes GPIO)
                                        -- System/I2C/SPI status registers (0x10-0x15)
                                        if addr_int <= 21 then
                                            case addr_int is
                                                when 16 => response_data <= status_reg0;
                                                when 17 => response_data <= status_reg1;
                                                when 18 => response_data <= status_reg2;
                                                when 19 => response_data <= status_reg3;
                                                when 20 => response_data <= status_reg4;
                                                when 21 => response_data <= status_reg5;
                                                when others => response_data <= (others => '0');
                                            end case;
                                            status_read_strobe_int(addr_int - 16) <= '1';
                                        -- GPIO input registers (0x16-0x19)
                                        elsif addr_int >= 22 and addr_int <= 25 then
                                            case addr_int is
                                                when 22 => response_data <= gpio_in0;
                                                when 23 => response_data <= gpio_in1;
                                                when 24 => response_data <= gpio_in2;
                                                when 25 => response_data <= gpio_in3;
                                                when others => response_data <= (others => '0');
                                            end case;
                                            gpio_read_strobe_int(addr_int - 22) <= '1';
                                        end if;
                                        -- Start CRC calculation for response
                                        tx_crc_calc <= crc8_update(x"00", x"02"); -- Response header
                                        state <= TX_RESPONSE;
                                    else
                                        cmd_error_int <= '1';
                                        state <= IDLE;
                                    end if;
                                
                                when others =>
                                    cmd_error_int <= '1';
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

    -- Output GPIO registers
    gpio_out0 <= ctrl_registers(6);
    gpio_out1 <= ctrl_registers(7);
    gpio_out2 <= ctrl_registers(8);
    gpio_out3 <= ctrl_registers(9);

    -- Output strobe signals
    ctrl_write_strobe <= ctrl_write_strobe_int;
    status_read_strobe <= status_read_strobe_int;
    gpio_write_strobe <= gpio_write_strobe_int;
    gpio_read_strobe <= gpio_read_strobe_int;
    
    -- Extract SPI configuration
    spi0_config <= ctrl_registers(4);  -- Control register 4 for SPI0 config
    spi1_config <= ctrl_registers(5);  -- Control register 5 for SPI1 config
    
    -- I2C control outputs
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
    
    -- SPI chip select outputs (from configuration)
    spi0_cs <= spi0_config(35 downto 32);  -- 4-bit chip select
    spi1_cs <= spi1_config(35 downto 32);  -- 4-bit chip select
    
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
                
                -- Trigger SPI0 transaction when ctrl_reg4 is written with enable bit set
                if ctrl_write_strobe_int(4) = '1' then
                    if spi0_config(63) = '1' then  -- SPI0 enable bit
                        spi0_start_int <= '1';
                    end if;
                end if;

                -- Trigger SPI1 transaction when ctrl_reg5 is written with enable bit set
                if ctrl_write_strobe_int(5) = '1' then
                    if spi1_config(63) = '1' then  -- SPI1 enable bit
                        spi1_start_int <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Output status signals
    cmd_valid <= cmd_valid_int;
    cmd_error <= cmd_error_int;
    crc_error <= crc_error_int;
    timeout_error <= timeout_error;

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