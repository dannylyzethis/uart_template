-- Testbench for UART Register Interface with I2C/SPI Control
-- Compatible with ModelSim simulation

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity uart_register_tb is
end uart_register_tb;

architecture behavioral of uart_register_tb is
    
    -- Constants
    constant CLK_PERIOD    : time := 10 ns;  -- 100MHz clock
    constant BAUD_PERIOD   : time := 8.68 us; -- 115200 baud
    constant BIT_PERIOD    : time := BAUD_PERIOD;
    
    -- Component declaration
    component uart_register_interface is
        generic (
            CLK_FREQ        : integer := 100_000_000;
            BAUD_RATE       : integer := 115200
        );
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            uart_rx         : in  std_logic;
            uart_tx         : out std_logic;
            ctrl_reg0       : out std_logic_vector(63 downto 0);
            ctrl_reg1       : out std_logic_vector(63 downto 0);
            ctrl_reg2       : out std_logic_vector(63 downto 0);
            ctrl_reg3       : out std_logic_vector(63 downto 0);
            ctrl_reg4       : out std_logic_vector(63 downto 0);
            ctrl_reg5       : out std_logic_vector(63 downto 0);
            ctrl_write_strobe : out std_logic_vector(5 downto 0);
            status_reg0     : in  std_logic_vector(63 downto 0);
            status_reg1     : in  std_logic_vector(63 downto 0);
            status_reg2     : in  std_logic_vector(63 downto 0);
            status_reg3     : in  std_logic_vector(63 downto 0);
            status_reg4     : in  std_logic_vector(63 downto 0);
            status_reg5     : in  std_logic_vector(63 downto 0);
            status_read_strobe : out std_logic_vector(5 downto 0);
            i2c0_sda        : inout std_logic;
            i2c0_scl        : inout std_logic;
            i2c0_busy       : in    std_logic;
            i2c0_start      : out   std_logic;
            i2c0_data_in    : out   std_logic_vector(7 downto 0);
            i2c0_data_out   : in    std_logic_vector(7 downto 0);
            i2c0_data_valid : in    std_logic;
            i2c0_ack_error  : in    std_logic;
            i2c1_sda        : inout std_logic;
            i2c1_scl        : inout std_logic;
            i2c1_busy       : in    std_logic;
            i2c1_start      : out   std_logic;
            i2c1_data_in    : out   std_logic_vector(7 downto 0);
            i2c1_data_out   : in    std_logic_vector(7 downto 0);
            i2c1_data_valid : in    std_logic;
            i2c1_ack_error  : in    std_logic;
            spi0_sclk       : out   std_logic;
            spi0_mosi       : out   std_logic;
            spi0_miso       : in    std_logic;
            spi0_cs         : out   std_logic_vector(3 downto 0);
            spi0_start      : out   std_logic;
            spi0_busy       : in    std_logic;
            spi0_data_in    : out   std_logic_vector(31 downto 0);
            spi0_data_out   : in    std_logic_vector(31 downto 0);
            spi0_data_valid : in    std_logic;
            spi1_sclk       : out   std_logic;
            spi1_mosi       : out   std_logic;
            spi1_miso       : in    std_logic;
            spi1_cs         : out   std_logic_vector(3 downto 0);
            spi1_start      : out   std_logic;
            spi1_busy       : in    std_logic;
            spi1_data_in    : out   std_logic_vector(31 downto 0);
            spi1_data_out   : in    std_logic_vector(31 downto 0);
            spi1_data_valid : in    std_logic;
            cmd_valid       : out std_logic;
            cmd_error       : out std_logic;
            crc_error       : out std_logic
        );
    end component;
    
    -- Simple UART core for testing
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
    
    -- Test signals
    signal clk             : std_logic := '0';
    signal rst             : std_logic := '1';
    signal uart_rx         : std_logic := '1';
    signal uart_tx         : std_logic;
    
    -- Control register outputs
    signal ctrl_reg0       : std_logic_vector(63 downto 0);
    signal ctrl_reg1       : std_logic_vector(63 downto 0);
    signal ctrl_reg2       : std_logic_vector(63 downto 0);
    signal ctrl_reg3       : std_logic_vector(63 downto 0);
    signal ctrl_reg4       : std_logic_vector(63 downto 0);
    signal ctrl_reg5       : std_logic_vector(63 downto 0);
    signal ctrl_write_strobe : std_logic_vector(5 downto 0);
    
    -- Status register inputs (simulated values)
    signal status_reg0     : std_logic_vector(63 downto 0) := x"0123456789ABCDEF";
    signal status_reg1     : std_logic_vector(63 downto 0) := x"1111222233334444";
    signal status_reg2     : std_logic_vector(63 downto 0) := x"5555666677778888";
    signal status_reg3     : std_logic_vector(63 downto 0) := x"9999AAAABBBBCCCC";
    signal status_reg4     : std_logic_vector(63 downto 0) := x"DDDDEEEEFFFFAAAA";
    signal status_reg5     : std_logic_vector(63 downto 0) := x"BBBBCCCCDDDDEEEE";
    signal status_read_strobe : std_logic_vector(5 downto 0);
    
    -- I2C signals
    signal i2c0_sda        : std_logic := 'H';
    signal i2c0_scl        : std_logic := 'H';
    signal i2c0_busy       : std_logic := '0';
    signal i2c0_start      : std_logic;
    signal i2c0_data_in    : std_logic_vector(7 downto 0);
    signal i2c0_data_out   : std_logic_vector(7 downto 0) := x"A5";
    signal i2c0_data_valid : std_logic := '0';
    signal i2c0_ack_error  : std_logic := '0';
    
    signal i2c1_sda        : std_logic := 'H';
    signal i2c1_scl        : std_logic := 'H';
    signal i2c1_busy       : std_logic := '0';
    signal i2c1_start      : std_logic;
    signal i2c1_data_in    : std_logic_vector(7 downto 0);
    signal i2c1_data_out   : std_logic_vector(7 downto 0) := x"5A";
    signal i2c1_data_valid : std_logic := '0';
    signal i2c1_ack_error  : std_logic := '0';
    
    -- SPI signals
    signal spi0_sclk       : std_logic;
    signal spi0_mosi       : std_logic;
    signal spi0_miso       : std_logic := '0';
    signal spi0_cs         : std_logic_vector(3 downto 0);
    signal spi0_start      : std_logic;
    signal spi0_busy       : std_logic := '0';
    signal spi0_data_in    : std_logic_vector(31 downto 0);
    signal spi0_data_out   : std_logic_vector(31 downto 0) := x"DEADBEEF";
    signal spi0_data_valid : std_logic := '0';
    
    signal spi1_sclk       : std_logic;
    signal spi1_mosi       : std_logic;
    signal spi1_miso       : std_logic := '1';
    signal spi1_cs         : std_logic_vector(3 downto 0);
    signal spi1_start      : std_logic;
    signal spi1_busy       : std_logic := '0';
    signal spi1_data_in    : std_logic_vector(31 downto 0);
    signal spi1_data_out   : std_logic_vector(31 downto 0) := x"CAFEBABE";
    signal spi1_data_valid : std_logic := '0';
    
    -- Status signals
    signal cmd_valid       : std_logic;
    signal cmd_error       : std_logic;
    signal crc_error       : std_logic;
    
    -- Test control
    signal test_running    : boolean := true;
    signal test_phase      : string(1 to 16) := "INIT            ";
    
    -- CRC calculation function (same as in DUT)
    function crc8_update(crc_in: std_logic_vector(7 downto 0); 
                        data_in: std_logic_vector(7 downto 0)) 
                        return std_logic_vector is
        variable crc_out : std_logic_vector(7 downto 0);
        variable temp    : std_logic_vector(7 downto 0);
    begin
        temp := crc_in xor data_in;
        crc_out := temp(6 downto 0) & '0';
        if temp(7) = '1' then
            crc_out := crc_out xor x"07";
        end if;
        return crc_out;
    end function;
    
    -- UART transmit procedure
    procedure uart_send_byte(
        signal uart_tx_sig : out std_logic;
        constant data_byte : in std_logic_vector(7 downto 0)
    ) is
    begin
        -- Start bit
        uart_tx_sig <= '0';
        wait for BIT_PERIOD;
        
        -- Data bits (LSB first)
        for i in 0 to 7 loop
            uart_tx_sig <= data_byte(i);
            wait for BIT_PERIOD;
        end loop;
        
        -- Stop bit
        uart_tx_sig <= '1';
        wait for BIT_PERIOD;
    end procedure;
    
    -- Send complete UART command packet
    procedure send_uart_command(
        signal uart_tx_sig : out std_logic;
        constant cmd       : in std_logic_vector(7 downto 0);
        constant addr      : in std_logic_vector(7 downto 0);
        constant data      : in std_logic_vector(63 downto 0)
    ) is
        variable crc : std_logic_vector(7 downto 0) := x"00";
    begin
        -- Calculate CRC
        crc := crc8_update(crc, cmd);
        crc := crc8_update(crc, addr);
        crc := crc8_update(crc, data(63 downto 56));
        crc := crc8_update(crc, data(55 downto 48));
        crc := crc8_update(crc, data(47 downto 40));
        crc := crc8_update(crc, data(39 downto 32));
        crc := crc8_update(crc, data(31 downto 24));
        crc := crc8_update(crc, data(23 downto 16));
        crc := crc8_update(crc, data(15 downto 8));
        crc := crc8_update(crc, data(7 downto 0));
        
        -- Send packet
        uart_send_byte(uart_tx_sig, cmd);
        uart_send_byte(uart_tx_sig, addr);
        uart_send_byte(uart_tx_sig, data(63 downto 56));
        uart_send_byte(uart_tx_sig, data(55 downto 48));
        uart_send_byte(uart_tx_sig, data(47 downto 40));
        uart_send_byte(uart_tx_sig, data(39 downto 32));
        uart_send_byte(uart_tx_sig, data(31 downto 24));
        uart_send_byte(uart_tx_sig, data(23 downto 16));
        uart_send_byte(uart_tx_sig, data(15 downto 8));
        uart_send_byte(uart_tx_sig, data(7 downto 0));
        uart_send_byte(uart_tx_sig, crc);
        
        wait for 10 * BIT_PERIOD; -- Allow processing time
    end procedure;

begin
    
    -- Instantiate DUT
    DUT: uart_register_interface
        generic map (
            CLK_FREQ  => 100_000_000,
            BAUD_RATE => 115200
        )
        port map (
            clk             => clk,
            rst             => rst,
            uart_rx         => uart_rx,
            uart_tx         => uart_tx,
            ctrl_reg0       => ctrl_reg0,
            ctrl_reg1       => ctrl_reg1,
            ctrl_reg2       => ctrl_reg2,
            ctrl_reg3       => ctrl_reg3,
            ctrl_reg4       => ctrl_reg4,
            ctrl_reg5       => ctrl_reg5,
            ctrl_write_strobe => ctrl_write_strobe,
            status_reg0     => status_reg0,
            status_reg1     => status_reg1,
            status_reg2     => status_reg2,
            status_reg3     => status_reg3,
            status_reg4     => status_reg4,
            status_reg5     => status_reg5,
            status_read_strobe => status_read_strobe,
            i2c0_sda        => i2c0_sda,
            i2c0_scl        => i2c0_scl,
            i2c0_busy       => i2c0_busy,
            i2c0_start      => i2c0_start,
            i2c0_data_in    => i2c0_data_in,
            i2c0_data_out   => i2c0_data_out,
            i2c0_data_valid => i2c0_data_valid,
            i2c0_ack_error  => i2c0_ack_error,
            i2c1_sda        => i2c1_sda,
            i2c1_scl        => i2c1_scl,
            i2c1_busy       => i2c1_busy,
            i2c1_start      => i2c1_start,
            i2c1_data_in    => i2c1_data_in,
            i2c1_data_out   => i2c1_data_out,
            i2c1_data_valid => i2c1_data_valid,
            i2c1_ack_error  => i2c1_ack_error,
            spi0_sclk       => spi0_sclk,
            spi0_mosi       => spi0_mosi,
            spi0_miso       => spi0_miso,
            spi0_cs         => spi0_cs,
            spi0_start      => spi0_start,
            spi0_busy       => spi0_busy,
            spi0_data_in    => spi0_data_in,
            spi0_data_out   => spi0_data_out,
            spi0_data_valid => spi0_data_valid,
            spi1_sclk       => spi1_sclk,
            spi1_mosi       => spi1_mosi,
            spi1_miso       => spi1_miso,
            spi1_cs         => spi1_cs,
            spi1_start      => spi1_start,
            spi1_busy       => spi1_busy,
            spi1_data_in    => spi1_data_in,
            spi1_data_out   => spi1_data_out,
            spi1_data_valid => spi1_data_valid,
            cmd_valid       => cmd_valid,
            cmd_error       => cmd_error,
            crc_error       => crc_error
        );
    
    -- Clock generation
    clk_process: process
    begin
        while test_running loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- Main test stimulus
    test_process: process
    begin
        -- Initialize
        uart_rx <= '1';  -- UART idle state
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;
        
        report "=== Starting UART Register Interface Test ===" severity note;
        
        -- Test 1: Write to Control Register 0
        test_phase <= "WRITE_CTRL0     ";
        report "Test 1: Writing to Control Register 0" severity note;
        send_uart_command(uart_rx, x"01", x"00", x"123456789ABCDEF0");
        
        wait for 1 us;
        assert ctrl_reg0 = x"123456789ABCDEF0" 
            report "ERROR: Control Register 0 write failed" severity error;
        assert ctrl_write_strobe(0) = '1' 
            report "ERROR: Control Register 0 write strobe not asserted" severity error;
        
        -- Test 2: Write to Control Register 1 (Switch Control)
        test_phase <= "WRITE_CTRL1     ";
        report "Test 2: Writing to Control Register 1 (Switch Control)" severity note;
        send_uart_command(uart_rx, x"01", x"01", x"0001000200030004");
        
        wait for 1 us;
        assert ctrl_reg1 = x"0001000200030004" 
            report "ERROR: Control Register 1 write failed" severity error;
        
        -- Test 3: Write to I2C Control Register (should trigger I2C)
        test_phase <= "WRITE_I2C       ";
        report "Test 3: Writing to I2C Control Register" severity note;
        send_uart_command(uart_rx, x"01", x"02", x"8000000080000055"); -- I2C0 and I2C1 enable
        
        wait for 1 us;
        assert i2c0_start = '1' or i2c1_start = '1'
            report "ERROR: I2C start signals not asserted" severity warning;
        
        -- Test 4: Write SPI Configuration
        test_phase <= "WRITE_SPI_CFG   ";
        report "Test 4: Writing SPI Configuration" severity note;
        -- SPI0: Enable=1, CPOL=0, CPHA=1, WordLen=31(32bits), ClkDiv=100, CS=0001
        send_uart_command(uart_rx, x"01", x"04", x"DF00640100000000");
        
        wait for 1 us;
        assert ctrl_reg4 = x"DF00640100000000" 
            report "ERROR: SPI0 configuration write failed" severity error;
        
        -- Test 5: Write SPI Data (should trigger SPI transaction)
        test_phase <= "WRITE_SPI_DATA  ";
        report "Test 5: Writing SPI Data" severity note;
        send_uart_command(uart_rx, x"01", x"03", x"DEADBEEFCAFEBABE");
        
        wait for 1 us;
        assert spi0_data_in = x"DEADBEEF" 
            report "ERROR: SPI0 data not correct" severity error;
        assert spi1_data_in = x"CAFEBABE" 
            report "ERROR: SPI1 data not correct" severity error;
        
        -- Test 6: Read Status Register 0
        test_phase <= "READ_STATUS0    ";
        report "Test 6: Reading Status Register 0" severity note;
        send_uart_command(uart_rx, x"02", x"10", x"0000000000000000");
        
        wait for 5 us;  -- Allow time for response
        assert status_read_strobe(0) = '1' 
            report "ERROR: Status Register 0 read strobe not asserted" severity warning;
        
        -- Test 7: Test CRC Error
        test_phase <= "CRC_ERROR_TEST  ";
        report "Test 7: Testing CRC Error Detection" severity note;
        uart_send_byte(uart_rx, x"01");  -- CMD
        uart_send_byte(uart_rx, x"00");  -- ADDR
        uart_send_byte(uart_rx, x"12");  -- DATA
        uart_send_byte(uart_rx, x"34");
        uart_send_byte(uart_rx, x"56");
        uart_send_byte(uart_rx, x"78");
        uart_send_byte(uart_rx, x"9A");
        uart_send_byte(uart_rx, x"BC");
        uart_send_byte(uart_rx, x"DE");
        uart_send_byte(uart_rx, x"F0");
        uart_send_byte(uart_rx, x"FF");  -- Wrong CRC
        
        wait for 2 us;
        assert crc_error = '1' 
            report "ERROR: CRC error not detected" severity error;
        
        -- Test 8: Test Invalid Address
        test_phase <= "INVALID_ADDR    ";
        report "Test 8: Testing Invalid Address" severity note;
        send_uart_command(uart_rx, x"01", x"FF", x"0000000000000000");
        
        wait for 2 us;
        assert cmd_error = '1' 
            report "ERROR: Command error not detected for invalid address" severity error;
        
        -- Test completed
        test_phase <= "COMPLETED       ";
        report "=== All Tests Completed ===" severity note;
        
        wait for 10 us;
        test_running <= false;
        wait;
    end process;
    
    -- Monitor process for debugging
    monitor_process: process(clk)
    begin
        if rising_edge(clk) then
            -- Monitor control register writes
            for i in 0 to 5 loop
                if ctrl_write_strobe(i) = '1' then
                    report "Control Register " & integer'image(i) & " written" severity note;
                end if;
            end loop;
            
            -- Monitor status register reads
            for i in 0 to 5 loop
                if status_read_strobe(i) = '1' then
                    report "Status Register " & integer'image(i) & " read" severity note;
                end if;
            end loop;
            
            -- Monitor I2C activity
            if i2c0_start = '1' then
                report "I2C0 transaction started" severity note;
            end if;
            if i2c1_start = '1' then
                report "I2C1 transaction started" severity note;
            end if;
            
            -- Monitor SPI activity  
            if spi0_start = '1' then
                report "SPI0 transaction started" severity note;
            end if;
            if spi1_start = '1' then
                report "SPI1 transaction started" severity note;
            end if;
            
            -- Monitor errors
            if cmd_error = '1' then
                report "Command error detected" severity warning;
            end if;
            if crc_error = '1' then
                report "CRC error detected" severity warning;
            end if;
        end if;
    end process;

end behavioral;

-- Note: You'll need to create a simple uart_core component or 
-- modify the testbench to work with your specific UART implementation.
-- The uart_core component can be a simple behavioral model for testing.