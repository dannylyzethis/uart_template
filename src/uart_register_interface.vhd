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
        timeout_error   : out std_logic;

        -- Interrupt output
        irq_out         : out std_logic  -- Interrupt request (active high)
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
    
    -- Internal control registers (0-5: system/I2C/SPI, 6-9: GPIO, 10: watchdog, 11: IRQ enable, 12: BIST)
    type ctrl_reg_array_type is array (0 to 12) of std_logic_vector(63 downto 0);
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

    -- Timeout and watchdog (now programmable via register 0x0A)
    constant DEFAULT_TIMEOUT_MS : integer := 10;  -- Default 10ms timeout
    constant MAX_TIMEOUT_CYCLES : integer := 10_000_000;  -- Max 100ms at 100MHz
    signal timeout_cycles : integer range 0 to MAX_TIMEOUT_CYCLES := 1_000_000;  -- Programm able
    signal timeout_counter : integer range 0 to MAX_TIMEOUT_CYCLES := 0;
    signal timeout_error   : std_logic := '0';

    -- Diagnostic counters (for register 0x1A)
    signal packet_rx_count    : unsigned(15 downto 0) := (others => '0');  -- Total packets received
    signal packet_tx_count    : unsigned(15 downto 0) := (others => '0');  -- Total packets transmitted
    signal crc_error_count    : unsigned(15 downto 0) := (others => '0');  -- CRC errors
    signal timeout_count      : unsigned(15 downto 0) := (others => '0');  -- Timeout events
    signal cmd_error_count    : unsigned(15 downto 0) := (others => '0');  -- Command errors
    signal last_error_code    : std_logic_vector(7 downto 0) := (others => '0');  -- Last error type

    -- Interrupt system (control via register 0x0B, status via register 0x1B)
    signal irq_enable_mask    : std_logic_vector(7 downto 0) := (others => '0');  -- IRQ enable bits
    signal irq_status_bits    : std_logic_vector(7 downto 0) := (others => '0');  -- IRQ status (latched)
    signal irq_out_int        : std_logic := '0';
    -- IRQ bit definitions:
    -- Bit 0: CRC error interrupt
    -- Bit 1: Timeout error interrupt
    -- Bit 2: Command error interrupt
    -- Bit 3: I2C0 transaction complete/error
    -- Bit 4: I2C1 transaction complete/error
    -- Bit 5: SPI0 transaction complete
    -- Bit 6: SPI1 transaction complete
    -- Bit 7: GPIO input change (future enhancement)

    -- Timestamp counter (register 0x1C = 28)
    -- Free-running 64-bit counter at system clock rate
    -- Provides precise timing for debugging and performance analysis
    signal timestamp_counter  : unsigned(63 downto 0) := (others => '0');

    -- Built-In Self-Test (BIST) system (register 0x0C = 12 for control, 0x1D = 29 for status)
    signal bist_control       : std_logic_vector(7 downto 0) := (others => '0');
    signal bist_status        : std_logic_vector(7 downto 0) := (others => '0');
    signal bist_running       : std_logic := '0';
    signal bist_test_counter  : integer range 0 to 255 := 0;
    signal bist_error_count   : unsigned(7 downto 0) := (others => '0');  -- Register mismatch count
    signal bist_failed_addr   : std_logic_vector(7 downto 0) := (others => '0');  -- Last failed register
    -- BIST control bits (register 0x0C):
    --   Bit 0: Start BIST (write 1 to start, auto-clears)
    --   Bit 1: CRC test enable
    --   Bit 2: Counter/timestamp test enable
    --   Bit 3: Register payload validation enable (write/read/verify)
    --   Bits 7-4: Reserved
    -- BIST status bits (register 0x1D = 29):
    --   Bit 0: BIST running
    --   Bit 1: BIST pass (all enabled tests passed)
    --   Bit 2: CRC test pass
    --   Bit 3: Counter test pass
    --   Bit 4: Register payload test pass
    --   Bit 5: Payload mismatch detected (sticky until next BIST)
    --   Bits 7-6: Reserved

    -- GPIO Edge Detection System (registers 0x0D, 0x0E, 0x1F)
    -- Monitors up to 64 GPIO pins (banks 0-1) for rising/falling edges
    -- Generates interrupt (bit 7) when configured edge is detected

    -- Register 0x0D (13): GPIO Edge Detection Enable
    --   [63:32] Bank 1 pin enable mask (bits 0-31 for gpio_in1[31:0])
    --   [31:0]  Bank 0 pin enable mask (bits 0-31 for gpio_in0[31:0])
    signal gpio_edge_enable   : std_logic_vector(63 downto 0) := (others => '0');

    -- Register 0x0E (14): GPIO Edge Type Configuration
    --   [63:0] Edge type for pins 0-31 (2 bits per pin)
    --          Bits [1:0]   = pin 0:  00=disabled, 01=rising, 10=falling, 11=both
    --          Bits [3:2]   = pin 1
    --          ...
    --          Bits [63:62] = pin 31
    signal gpio_edge_config   : std_logic_vector(63 downto 0) := (others => '0');

    -- Register 0x1F (31): GPIO Edge Status (read/write-1-to-clear)
    --   [63:32] Bank 1 edge detected flags (write 1 to clear)
    --   [31:0]  Bank 0 edge detected flags (write 1 to clear)
    signal gpio_edge_status   : std_logic_vector(63 downto 0) := (others => '0');

    -- GPIO input synchronizers (2-FF for metastability protection)
    -- Asynchronous GPIO inputs must be synchronized to system clock domain
    -- All 4 GPIO input banks are synchronized for reliable reads
    signal gpio_in0_sync1     : std_logic_vector(63 downto 0) := (others => '0');
    signal gpio_in0_sync2     : std_logic_vector(63 downto 0) := (others => '0');
    signal gpio_in1_sync1     : std_logic_vector(63 downto 0) := (others => '0');
    signal gpio_in1_sync2     : std_logic_vector(63 downto 0) := (others => '0');
    signal gpio_in2_sync1     : std_logic_vector(63 downto 0) := (others => '0');
    signal gpio_in2_sync2     : std_logic_vector(63 downto 0) := (others => '0');
    signal gpio_in3_sync1     : std_logic_vector(63 downto 0) := (others => '0');
    signal gpio_in3_sync2     : std_logic_vector(63 downto 0) := (others => '0');

    -- Previous GPIO state for edge detection
    signal gpio_in0_prev      : std_logic_vector(63 downto 0) := (others => '0');
    signal gpio_in1_prev      : std_logic_vector(63 downto 0) := (others => '0');

    -- Edge detection working signals
    signal gpio0_edges        : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio1_edges        : std_logic_vector(31 downto 0) := (others => '0');
    signal gpio_edge_clear    : std_logic_vector(63 downto 0) := (others => '0');  -- Clear request from main FSM
    signal irq_status_clear   : std_logic_vector(7 downto 0) := (others => '0');   -- Clear request from main FSM

    -- Transaction History Buffer (registers 0x0F control, 0x20 data)
    -- Stores last 16 UART transactions for debugging
    -- Each entry: [63:32]=timestamp, [31:24]=cmd, [23:16]=addr, [15:8]=flags, [7:0]=index
    constant HISTORY_DEPTH    : integer := 16;
    type history_array_type is array (0 to HISTORY_DEPTH-1) of std_logic_vector(63 downto 0);
    signal history_buffer     : history_array_type := (others => (others => '0'));
    signal history_wr_ptr     : integer range 0 to HISTORY_DEPTH-1 := 0;
    signal history_rd_ptr     : integer range 0 to HISTORY_DEPTH-1 := 0;
    signal history_count      : integer range 0 to HISTORY_DEPTH := 0;
    signal history_clear      : std_logic := '0';

    -- Performance Metrics (register 0x21 = 33)
    -- Tracks transaction latency statistics (command received to response sent)
    signal perf_min_latency   : unsigned(15 downto 0) := (others => '1');  -- Init to max value
    signal perf_max_latency   : unsigned(15 downto 0) := (others => '0');
    signal perf_total_latency : unsigned(31 downto 0) := (others => '0');  -- For average calculation
    signal perf_avg_latency   : unsigned(15 downto 0) := (others => '0');  -- Pre-calculated average (avoids division in read path)
    signal perf_count         : unsigned(15 downto 0) := (others => '0');
    signal transaction_start_time : unsigned(15 downto 0) := (others => '0');  -- Capture start timestamp
    signal measure_latency    : std_logic := '0';  -- Flag to indicate measurement in progress

begin

    -- Output assignments
    irq_out <= irq_out_int;

    -- Interrupt generation logic
    -- IRQ is asserted when any enabled interrupt source is active
    irq_out_int <= '1' when (irq_status_bits and irq_enable_mask) /= x"00" else '0';

    -- Timestamp counter process
    -- Increments every clock cycle for precise timing measurements
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                timestamp_counter <= (others => '0');
            else
                timestamp_counter <= timestamp_counter + 1;
            end if;
        end if;
    end process;

    -- GPIO Input Synchronizer Process
    -- Two-stage flip-flop synchronizer to prevent metastability
    -- Asynchronous GPIO inputs are sampled into system clock domain
    -- This is CRITICAL for reliable edge detection and prevents metastability
    -- All 4 GPIO banks (256 pins total) are synchronized
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                gpio_in0_sync1 <= (others => '0');
                gpio_in0_sync2 <= (others => '0');
                gpio_in1_sync1 <= (others => '0');
                gpio_in1_sync2 <= (others => '0');
                gpio_in2_sync1 <= (others => '0');
                gpio_in2_sync2 <= (others => '0');
                gpio_in3_sync1 <= (others => '0');
                gpio_in3_sync2 <= (others => '0');
            else
                -- First stage: sample asynchronous inputs
                gpio_in0_sync1 <= gpio_in0;
                gpio_in1_sync1 <= gpio_in1;
                gpio_in2_sync1 <= gpio_in2;
                gpio_in3_sync1 <= gpio_in3;

                -- Second stage: re-sample to eliminate metastability
                gpio_in0_sync2 <= gpio_in0_sync1;
                gpio_in1_sync2 <= gpio_in1_sync1;
                gpio_in2_sync2 <= gpio_in2_sync1;
                gpio_in3_sync2 <= gpio_in3_sync1;
            end if;
        end if;
    end process;

    -- GPIO Edge Detection Process
    -- Monitors configured GPIO pins for rising/falling edges
    -- Generates interrupt (bit 7) when edge is detected
    process(clk)
        variable edge_type : std_logic_vector(1 downto 0);
        variable rising_edge_detected : std_logic;
        variable falling_edge_detected : std_logic;
        variable any_edge_detected : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                gpio_in0_prev <= (others => '0');
                gpio_in1_prev <= (others => '0');
                gpio_edge_status <= (others => '0');
                gpio0_edges <= (others => '0');
                gpio1_edges <= (others => '0');
            else
                -- Update previous state (using synchronized inputs)
                gpio_in0_prev <= gpio_in0_sync2;
                gpio_in1_prev <= gpio_in1_sync2;

                -- Detect edges on Bank 0 (pins 0-31)
                for i in 0 to 31 loop
                    if gpio_edge_enable(i) = '1' then
                        -- Get edge type configuration for this pin (2 bits per pin)
                        edge_type := gpio_edge_config((i*2)+1 downto i*2);

                        -- Detect rising edge (0->1 transition)
                        rising_edge_detected := '0';
                        if gpio_in0_prev(i) = '0' and gpio_in0_sync2(i) = '1' then
                            rising_edge_detected := '1';
                        end if;

                        -- Detect falling edge (1->0 transition)
                        falling_edge_detected := '0';
                        if gpio_in0_prev(i) = '1' and gpio_in0_sync2(i) = '0' then
                            falling_edge_detected := '1';
                        end if;

                        -- Check if configured edge type matches detected edge
                        any_edge_detected := '0';
                        case edge_type is
                            when "01" =>  -- Rising edge only
                                if rising_edge_detected = '1' then
                                    any_edge_detected := '1';
                                end if;
                            when "10" =>  -- Falling edge only
                                if falling_edge_detected = '1' then
                                    any_edge_detected := '1';
                                end if;
                            when "11" =>  -- Both edges
                                if rising_edge_detected = '1' or falling_edge_detected = '1' then
                                    any_edge_detected := '1';
                                end if;
                            when others =>  -- Disabled
                                any_edge_detected := '0';
                        end case;

                        -- Latch edge status (sticky until cleared)
                        if any_edge_detected = '1' then
                            gpio_edge_status(i) <= '1';
                            gpio0_edges(i) <= '1';
                        end if;
                    end if;
                end loop;

                -- Detect edges on Bank 1 (pins 32-63, mapped to gpio_in1[0-31])
                -- NOTE: Bank 1 shares edge configuration with Bank 0 (pin N of Bank 1 uses same config as pin N of Bank 0)
                -- This saves register space but means both banks must use identical edge types
                for i in 0 to 31 loop
                    if gpio_edge_enable(32 + i) = '1' then
                        -- Get edge type configuration for this pin (shared with Bank 0 pin i)
                        edge_type := gpio_edge_config((i*2)+1 downto i*2);

                        -- Detect rising edge (using synchronized input)
                        rising_edge_detected := '0';
                        if gpio_in1_prev(i) = '0' and gpio_in1_sync2(i) = '1' then
                            rising_edge_detected := '1';
                        end if;

                        -- Detect falling edge (using synchronized input)
                        falling_edge_detected := '0';
                        if gpio_in1_prev(i) = '1' and gpio_in1_sync2(i) = '0' then
                            falling_edge_detected := '1';
                        end if;

                        -- Check if configured edge type matches detected edge
                        any_edge_detected := '0';
                        case edge_type is
                            when "01" =>  -- Rising edge only
                                if rising_edge_detected = '1' then
                                    any_edge_detected := '1';
                                end if;
                            when "10" =>  -- Falling edge only
                                if falling_edge_detected = '1' then
                                    any_edge_detected := '1';
                                end if;
                            when "11" =>  -- Both edges
                                if rising_edge_detected = '1' or falling_edge_detected = '1' then
                                    any_edge_detected := '1';
                                end if;
                            when others =>  -- Disabled
                                any_edge_detected := '0';
                        end case;

                        -- Latch edge status
                        if any_edge_detected = '1' then
                            gpio_edge_status(32 + i) <= '1';
                            gpio1_edges(i) <= '1';
                        end if;
                    end if;
                end loop;

                -- Generate GPIO interrupt (bit 7) if any edge is detected
                if (gpio0_edges /= x"00000000") or (gpio1_edges /= x"00000000") then
                    irq_status_bits(7) <= '1';
                end if;

                -- Handle clear requests from main FSM (write-1-to-clear from software)
                gpio_edge_status <= gpio_edge_status and not gpio_edge_clear;
                if irq_status_clear(7) = '1' then
                    irq_status_bits(7) <= '0';
                end if;
                -- Clear the clear request signals after processing
                gpio_edge_clear <= (others => '0');
                irq_status_clear <= (others => '0');

                -- Clear edge flags after they've been latched into status
                gpio0_edges <= (others => '0');
                gpio1_edges <= (others => '0');
            end if;
        end if;
    end process;

    -- Performance Metrics Process
    -- Tracks transaction latency (command receive to response send)
    process(clk)
        variable current_latency : unsigned(15 downto 0);
        variable avg_latency : unsigned(15 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                perf_min_latency <= (others => '1');  -- Max value
                perf_max_latency <= (others => '0');
                perf_total_latency <= (others => '0');
                perf_avg_latency <= (others => '0');
                perf_count <= (others => '0');
                transaction_start_time <= (others => '0');
                measure_latency <= '0';
            else
                -- Start latency measurement when command is valid
                if cmd_valid_int = '1' and measure_latency = '0' then
                    transaction_start_time <= timestamp_counter(15 downto 0);  -- Capture lower 16 bits
                    measure_latency <= '1';
                end if;

                -- Complete latency measurement when entering TX_RESPONSE state
                if state = TX_RESPONSE and measure_latency = '1' then
                    -- Calculate latency (handle wraparound)
                    current_latency := timestamp_counter(15 downto 0) - transaction_start_time;

                    -- Update min latency
                    if current_latency < perf_min_latency then
                        perf_min_latency <= current_latency;
                    end if;

                    -- Update max latency
                    if current_latency > perf_max_latency then
                        perf_max_latency <= current_latency;
                    end if;

                    -- Update total for average calculation (with saturation)
                    if perf_total_latency < x"FFFF0000" then  -- Prevent overflow
                        perf_total_latency <= perf_total_latency + current_latency;
                    end if;

                    -- Increment count (with saturation)
                    if perf_count < x"FFFF" then
                        perf_count <= perf_count + 1;
                    end if;

                    -- Calculate average latency (avoid division by zero)
                    -- Use upper 16 bits of total divided by count
                    if perf_count > 0 then
                        perf_avg_latency <= perf_total_latency(31 downto 16) / (perf_count + 1);  -- +1 because we just incremented
                    else
                        perf_avg_latency <= current_latency;  -- First sample
                    end if;

                    measure_latency <= '0';
                end if;

                -- Clear measurement flag if transaction fails
                if state = IDLE and measure_latency = '1' then
                    measure_latency <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Transaction History Buffer Process
    -- Logs UART transactions with timestamp for debugging
    process(clk)
        variable transaction_flags : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' or history_clear = '1' then
                history_wr_ptr <= 0;
                history_rd_ptr <= 0;
                history_count <= 0;
                history_clear <= '0';
                -- Don't need to clear buffer contents, just pointers
            else
                -- Capture transaction when command is valid
                if cmd_valid_int = '1' then
                    -- Build transaction flags
                    transaction_flags := (
                        7 => crc_error_int,
                        6 => timeout_error,
                        5 => cmd_error_int,
                        4 => '0',  -- Reserved
                        3 => '0',  -- Reserved
                        2 downto 0 => "000"  -- Reserved
                    );

                    -- Store transaction record
                    history_buffer(history_wr_ptr) <=
                        std_logic_vector(timestamp_counter(31 downto 0)) &  -- [63:32] Lower 32 bits of timestamp
                        cmd_byte &                                           -- [31:24] Command
                        addr_byte &                                          -- [23:16] Address
                        transaction_flags &                                  -- [15:8]  Status flags
                        std_logic_vector(to_unsigned(history_wr_ptr, 8));   -- [7:0]   Entry index

                    -- Increment write pointer (circular)
                    if history_wr_ptr = HISTORY_DEPTH-1 then
                        history_wr_ptr <= 0;
                    else
                        history_wr_ptr <= history_wr_ptr + 1;
                    end if;

                    -- Update count (saturate at HISTORY_DEPTH)
                    if history_count < HISTORY_DEPTH then
                        history_count <= history_count + 1;
                    else
                        -- Buffer full, oldest entry is being overwritten
                        -- Move read pointer to track oldest entry
                        if history_rd_ptr = HISTORY_DEPTH-1 then
                            history_rd_ptr <= 0;
                        else
                            history_rd_ptr <= history_rd_ptr + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Built-In Self-Test (BIST) process
    -- Runs comprehensive functional tests when triggered including register payload validation
    process(clk)
        variable crc_test_result      : std_logic;
        variable counter_test_result  : std_logic;
        variable register_test_result : std_logic;
        variable timestamp_prev       : unsigned(63 downto 0);
        variable test_pattern         : std_logic_vector(63 downto 0);
        variable readback_value       : std_logic_vector(63 downto 0);
        variable reg_index            : integer range 0 to 9;
        variable saved_reg_values     : ctrl_reg_array_type;  -- Save original values
    begin
        if rising_edge(clk) then
            if rst = '1' then
                bist_running <= '0';
                bist_status <= (others => '0');
                bist_test_counter <= 0;
                bist_error_count <= (others => '0');
                bist_failed_addr <= (others => '0');
            else
                -- Start BIST when bit 0 of control register is set
                if bist_control(0) = '1' and bist_running = '0' then
                    bist_running <= '1';
                    bist_test_counter <= 0;
                    bist_status <= (others => '0');
                    bist_error_count <= (others => '0');
                    bist_failed_addr <= (others => '0');
                    bist_control(0) <= '0';  -- Auto-clear start bit
                    timestamp_prev := timestamp_counter;
                    -- Save current register values for restoration
                    saved_reg_values := ctrl_registers;
                end if;

                -- Run BIST tests
                if bist_running = '1' then
                    bist_test_counter <= bist_test_counter + 1;

                    case bist_test_counter is
                        when 10 =>
                            -- Test 1: CRC calculation validation
                            crc_test_result := '0';
                            if crc8_update(x"00", x"AA") = x"5C" then
                                crc_test_result := '1';
                            end if;
                            bist_status(2) <= crc_test_result;  -- CRC test result

                        when 20 =>
                            -- Test 2: Counter/timestamp increment validation
                            counter_test_result := '0';
                            if timestamp_counter > timestamp_prev then
                                counter_test_result := '1';
                            end if;
                            bist_status(3) <= counter_test_result;  -- Counter test result

                        -- Test 3: Register payload validation (write/read/verify)
                        -- Test registers 0-9 with known patterns
                        when 30 =>
                            -- Initialize register test
                            register_test_result := '1';  -- Assume pass
                            reg_index := 0;
                            test_pattern := x"5A5A5A5A5A5A5A5A";
                            -- Write test pattern to register 0
                            ctrl_registers(0) <= test_pattern;

                        when 31 =>
                            -- Read back and verify register 0
                            readback_value := ctrl_registers(0);
                            if readback_value /= x"5A5A5A5A5A5A5A5A" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"00";  -- Address 0 failed
                                bist_status(5) <= '1';  -- Set mismatch flag
                            end if;
                            -- Write pattern to register 1
                            ctrl_registers(1) <= x"A5A5A5A5A5A5A5A5";

                        when 32 =>
                            -- Verify register 1
                            readback_value := ctrl_registers(1);
                            if readback_value /= x"A5A5A5A5A5A5A5A5" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"01";
                                bist_status(5) <= '1';
                            end if;
                            -- Write pattern to register 2
                            ctrl_registers(2) <= x"FF00FF00FF00FF00";

                        when 33 =>
                            -- Verify register 2
                            readback_value := ctrl_registers(2);
                            if readback_value /= x"FF00FF00FF00FF00" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"02";
                                bist_status(5) <= '1';
                            end if;
                            -- Write pattern to register 3
                            ctrl_registers(3) <= x"00FF00FF00FF00FF";

                        when 34 =>
                            -- Verify register 3
                            readback_value := ctrl_registers(3);
                            if readback_value /= x"00FF00FF00FF00FF" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"03";
                                bist_status(5) <= '1';
                            end if;
                            -- Write pattern to register 4
                            ctrl_registers(4) <= x"DEADBEEFCAFEBABE";

                        when 35 =>
                            -- Verify register 4
                            readback_value := ctrl_registers(4);
                            if readback_value /= x"DEADBEEFCAFEBABE" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"04";
                                bist_status(5) <= '1';
                            end if;
                            -- Write pattern to register 5
                            ctrl_registers(5) <= x"0123456789ABCDEF";

                        when 36 =>
                            -- Verify register 5
                            readback_value := ctrl_registers(5);
                            if readback_value /= x"0123456789ABCDEF" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"05";
                                bist_status(5) <= '1';
                            end if;
                            -- Write pattern to register 6 (GPIO bank 0)
                            ctrl_registers(6) <= x"FFFFFFFF00000000";

                        when 37 =>
                            -- Verify register 6
                            readback_value := ctrl_registers(6);
                            if readback_value /= x"FFFFFFFF00000000" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"06";
                                bist_status(5) <= '1';
                            end if;
                            -- Write pattern to register 7
                            ctrl_registers(7) <= x"0000FFFFFFFF0000";

                        when 38 =>
                            -- Verify register 7
                            readback_value := ctrl_registers(7);
                            if readback_value /= x"0000FFFFFFFF0000" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"07";
                                bist_status(5) <= '1';
                            end if;
                            -- Write pattern to register 8
                            ctrl_registers(8) <= x"AAAAAAAAAAAAAAAA";

                        when 39 =>
                            -- Verify register 8
                            readback_value := ctrl_registers(8);
                            if readback_value /= x"AAAAAAAAAAAAAAAA" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"08";
                                bist_status(5) <= '1';
                            end if;
                            -- Write pattern to register 9
                            ctrl_registers(9) <= x"5555555555555555";

                        when 40 =>
                            -- Verify register 9 and finalize test
                            readback_value := ctrl_registers(9);
                            if readback_value /= x"5555555555555555" then
                                register_test_result := '0';
                                bist_error_count <= bist_error_count + 1;
                                bist_failed_addr <= x"09";
                                bist_status(5) <= '1';
                            end if;
                            -- Set register test result
                            bist_status(4) <= register_test_result;

                        when 50 =>
                            -- Restore original register values
                            for i in 0 to 9 loop
                                ctrl_registers(i) <= saved_reg_values(i);
                            end loop;

                        when 60 =>
                            -- Complete BIST
                            bist_status(0) <= '0';  -- Clear running flag
                            -- Overall pass if all enabled tests passed
                            if ((bist_control(1) = '0' or bist_status(2) = '1') and
                                (bist_control(2) = '0' or bist_status(3) = '1') and
                                (bist_control(3) = '0' or bist_status(4) = '1')) then
                                bist_status(1) <= '1';  -- Overall pass
                            end if;
                            bist_running <= '0';

                        when others =>
                            bist_status(0) <= '1';  -- Set running flag
                    end case;
                end if;
            end if;
        end if;
    end process;

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

                -- Programmable timeout watchdog counter
                if state = IDLE then
                    timeout_counter <= 0;
                    timeout_error <= '0';
                    -- Update timeout cycles from register 0x0A (in milliseconds)
                    -- Convert ms to cycles: timeout_ms * (CLK_FREQ / 1000)
                    -- Note: Calculation must prevent integer overflow (saturate at MAX_TIMEOUT_CYCLES)
                    if ctrl_registers(10)(15 downto 0) /= x"0000" then
                        -- Use programmed timeout (register 0x0A, lower 16 bits = timeout in ms)
                        -- Saturate at MAX_TIMEOUT_CYCLES to prevent overflow
                        -- Max valid timeout: MAX_TIMEOUT_CYCLES / (CLK_FREQ/1000) = 10M / 100k = 100ms
                        if to_integer(unsigned(ctrl_registers(10)(15 downto 0))) > (MAX_TIMEOUT_CYCLES / (CLK_FREQ / 1000)) then
                            timeout_cycles <= MAX_TIMEOUT_CYCLES;  -- Saturate (values >100ms clamp to 100ms)
                        else
                            timeout_cycles <= to_integer(unsigned(ctrl_registers(10)(15 downto 0))) * (CLK_FREQ / 1000);
                        end if;
                    else
                        -- Timeout disabled when set to 0
                        timeout_cycles <= MAX_TIMEOUT_CYCLES;
                    end if;
                else
                    if timeout_counter = timeout_cycles - 1 and timeout_cycles /= MAX_TIMEOUT_CYCLES then
                        -- Timeout occurred - force return to IDLE
                        timeout_error <= '1';
                        timeout_count <= timeout_count + 1;
                        last_error_code <= x"03"; -- Timeout error code
                        irq_status_bits(1) <= '1'; -- Latch timeout error interrupt
                        state <= IDLE;
                        timeout_counter <= 0;
                    else
                        timeout_counter <= timeout_counter + 1;
                    end if;
                end if;

                -- Only process commands if not in timeout
                if timeout_counter /= timeout_cycles - 1 or timeout_cycles = MAX_TIMEOUT_CYCLES then
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
                            crc_error_count <= crc_error_count + 1;
                            last_error_code <= x"01"; -- CRC error code
                            irq_status_bits(0) <= '1'; -- Latch CRC error interrupt
                            state <= IDLE;
                        else
                            addr_int := to_integer(unsigned(addr_byte));
                            cmd_valid_int <= '1';
                            packet_rx_count <= packet_rx_count + 1;  -- Increment RX packet counter
                            
                            case cmd_byte is
                                when x"01" => -- Write Control Register
                                    if addr_int >= 0 and addr_int <= 15 then  -- 0x00-0x0F (includes GPIO + watchdog + IRQ + BIST + GPIO edge + history)
                                        -- Block writes to ctrl_registers during BIST to prevent corruption
                                        if addr_int <= 12 and bist_running = '0' then
                                            ctrl_registers(addr_int) <= data_word;
                                        end if;
                                        -- Strobe system/I2C/SPI registers (0-5) - block during BIST
                                        if addr_int <= 5 and bist_running = '0' then
                                            ctrl_write_strobe_int(addr_int) <= '1';
                                        -- Strobe GPIO registers (6-9) - block during BIST
                                        elsif addr_int >= 6 and addr_int <= 9 and bist_running = '0' then
                                            gpio_write_strobe_int(addr_int - 6) <= '1';
                                        -- Register 10 (0x0A) is watchdog config - no strobe needed
                                        -- Register 11 (0x0B) is IRQ enable mask
                                        elsif addr_int = 11 then
                                            irq_enable_mask <= data_word(7 downto 0);
                                        -- Register 12 (0x0C) is BIST control
                                        elsif addr_int = 12 then
                                            bist_control <= data_word(7 downto 0);
                                        -- Register 13 (0x0D) is GPIO edge detection enable
                                        elsif addr_int = 13 then
                                            gpio_edge_enable <= data_word;
                                        -- Register 14 (0x0E) is GPIO edge type configuration
                                        elsif addr_int = 14 then
                                            gpio_edge_config <= data_word;
                                        -- Register 15 (0x0F) is transaction history control
                                        elsif addr_int = 15 then
                                            if data_word(0) = '1' then
                                                history_clear <= '1';  -- Clear history buffer
                                            end if;
                                        end if;
                                        state <= IDLE;
                                    -- Write to IRQ status register 0x1B (27) to clear interrupts (write-1-to-clear)
                                    elsif addr_int = 27 then
                                        -- Clear bits 0-6 directly (they're only set by main FSM)
                                        irq_status_bits(6 downto 0) <= irq_status_bits(6 downto 0) and not data_word(6 downto 0);
                                        -- Request clear for bit 7 (set by GPIO process, so use clear signal to avoid multiple drivers)
                                        irq_status_clear(7) <= data_word(7);
                                        state <= IDLE;
                                    -- Write to GPIO edge status register 0x1F (31) to clear edge flags (write-1-to-clear)
                                    elsif addr_int = 31 then
                                        -- Request clear (handled by GPIO edge detection process to avoid multiple drivers)
                                        gpio_edge_clear <= data_word;
                                        state <= IDLE;
                                    else
                                        cmd_error_int <= '1';
                                        cmd_error_count <= cmd_error_count + 1;
                                        last_error_code <= x"02"; -- Invalid address error
                                        irq_status_bits(2) <= '1'; -- Latch command error interrupt
                                        state <= IDLE;
                                    end if;

                                when x"02" => -- Read Register (Control or Status)
                                    -- Extended to support control register read-back (0x00-0x0F) and diagnostics (0x1A-0x21)
                                    if (addr_int >= 0 and addr_int <= 15) or (addr_int >= 16 and addr_int <= 33) then
                                        -- Control register read-back (0x00-0x0C including watchdog, IRQ, BIST)
                                        if addr_int >= 0 and addr_int <= 12 then
                                            response_data <= ctrl_registers(addr_int);
                                        -- GPIO edge detection control registers (0x0D-0x0E)
                                        elsif addr_int = 13 then
                                            response_data <= gpio_edge_enable;
                                        elsif addr_int = 14 then
                                            response_data <= gpio_edge_config;
                                        -- Transaction history control register (0x0F)
                                        elsif addr_int = 15 then
                                            -- Return entry count
                                            response_data <= (63 downto 16 => '0') &
                                                            std_logic_vector(to_unsigned(history_count, 8)) &  -- [15:8] Entry count
                                                            (7 downto 0 => '0');  -- [7:0] Reserved
                                        -- System/I2C/SPI status registers (0x10-0x15)
                                        elsif addr_int >= 16 and addr_int <= 21 then
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
                                        -- GPIO input registers (0x16-0x19) - synchronized values
                                        elsif addr_int >= 22 and addr_int <= 25 then
                                            case addr_int is
                                                when 22 => response_data <= gpio_in0_sync2;
                                                when 23 => response_data <= gpio_in1_sync2;
                                                when 24 => response_data <= gpio_in2_sync2;
                                                when 25 => response_data <= gpio_in3_sync2;
                                                when others => response_data <= (others => '0');
                                            end case;
                                            gpio_read_strobe_int(addr_int - 22) <= '1';
                                        -- Diagnostics register (0x1A = 26)
                                        elsif addr_int = 26 then
                                            -- Pack diagnostic counters into 64-bit response
                                            response_data <= std_logic_vector(packet_rx_count) &      -- [63:48] RX count
                                                            std_logic_vector(packet_tx_count) &       -- [47:32] TX count
                                                            std_logic_vector(crc_error_count) &       -- [31:16] CRC errors
                                                            last_error_code &                         -- [15:8] Last error
                                                            std_logic_vector(timeout_count(7 downto 0));  -- [7:0] Timeout count (lower 8 bits)
                                        -- IRQ status register (0x1B = 27)
                                        elsif addr_int = 27 then
                                            -- Return current IRQ status bits (read-only, write-1-to-clear)
                                            response_data <= (63 downto 8 => '0') & irq_status_bits;  -- [7:0] IRQ status
                                        -- Timestamp register (0x1C = 28)
                                        elsif addr_int = 28 then
                                            -- Return current timestamp (free-running 64-bit counter)
                                            response_data <= std_logic_vector(timestamp_counter);
                                        -- BIST status register (0x1D = 29)
                                        elsif addr_int = 29 then
                                            -- Return BIST status
                                            response_data <= (63 downto 8 => '0') & bist_status;
                                        -- BIST diagnostics register (0x1E = 30)
                                        elsif addr_int = 30 then
                                            -- Return BIST error details
                                            response_data <= (63 downto 24 => '0') &       -- Reserved
                                                            bist_failed_addr &              -- [23:16] Last failed register address
                                                            std_logic_vector(bist_error_count) &  -- [15:8] Mismatch count
                                                            bist_status;                    -- [7:0] BIST status (duplicate for convenience)
                                        -- GPIO edge status register (0x1F = 31)
                                        elsif addr_int = 31 then
                                            -- Return GPIO edge detection status (write-1-to-clear)
                                            response_data <= gpio_edge_status;  -- [63:32] Bank1, [31:0] Bank0
                                        -- Transaction history data register (0x20 = 32)
                                        elsif addr_int = 32 then
                                            -- Return oldest transaction entry and auto-increment read pointer
                                            if history_count > 0 then
                                                response_data <= history_buffer(history_rd_ptr);
                                                -- Auto-increment read pointer for next read
                                                if history_rd_ptr = HISTORY_DEPTH-1 then
                                                    history_rd_ptr <= 0;
                                                else
                                                    history_rd_ptr <= history_rd_ptr + 1;
                                                end if;
                                                -- Decrement count
                                                history_count <= history_count - 1;
                                            else
                                                -- No history available
                                                response_data <= (others => '0');
                                            end if;
                                        -- Performance metrics register (0x21 = 33)
                                        elsif addr_int = 33 then
                                            -- Return pre-calculated performance statistics
                                            -- [63:48] Min latency, [47:32] Max latency, [31:16] Avg latency, [15:0] Count
                                            response_data <= std_logic_vector(perf_min_latency) &                                  -- [63:48] Min
                                                            std_logic_vector(perf_max_latency) &                                   -- [47:32] Max
                                                            std_logic_vector(perf_avg_latency) &                                   -- [31:16] Avg (pre-calculated, no division here!)
                                                            std_logic_vector(perf_count);                                          -- [15:0]  Count
                                        end if;
                                        -- Start CRC calculation for response
                                        tx_crc_calc <= crc8_update(x"00", x"02"); -- Response header
                                        state <= TX_RESPONSE;
                                    else
                                        cmd_error_int <= '1';
                                        irq_status_bits(2) <= '1'; -- Latch command error interrupt
                                        state <= IDLE;
                                    end if;

                                when others =>
                                    cmd_error_int <= '1';
                                    irq_status_bits(2) <= '1'; -- Latch command error interrupt
                                    state <= IDLE;
                            end case;
                        end if;
                    
                    when TX_RESPONSE =>
                        if tx_busy = '0' then
                            tx_data <= x"02"; -- Response header
                            tx_send <= '1';
                            packet_tx_count <= packet_tx_count + 1;  -- Increment TX packet counter
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

    -- Interrupt latching for I2C/SPI completion
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Bits 0-2 are error interrupts (handled in main FSM)
                -- Only clear peripheral completion interrupts on reset
                irq_status_bits(3) <= '0';
                irq_status_bits(4) <= '0';
                irq_status_bits(5) <= '0';
                irq_status_bits(6) <= '0';
            else
                -- I2C0 transaction complete or ACK error
                if i2c0_data_valid = '1' or i2c0_ack_error = '1' then
                    irq_status_bits(3) <= '1';
                end if;

                -- I2C1 transaction complete or ACK error
                if i2c1_data_valid = '1' or i2c1_ack_error = '1' then
                    irq_status_bits(4) <= '1';
                end if;

                -- SPI0 transaction complete
                if spi0_data_valid = '1' then
                    irq_status_bits(5) <= '1';
                end if;

                -- SPI1 transaction complete
                if spi1_data_valid = '1' then
                    irq_status_bits(6) <= '1';
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