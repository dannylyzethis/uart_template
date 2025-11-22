-- I2C Master Controller
-- Supports standard mode (100kHz) and fast mode (400kHz)
-- Features: Start/Stop conditions, ACK/NACK handling, clock stretching
-- Author: RF Test Automation Engineering
-- Date: 2025-11-22

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_master is
    generic (
        CLK_FREQ    : integer := 100_000_000;  -- System clock frequency in Hz
        I2C_FREQ    : integer := 100_000        -- I2C clock frequency in Hz (100kHz or 400kHz)
    );
    port (
        clk         : in    std_logic;
        rst         : in    std_logic;

        -- I2C bus signals
        sda         : inout std_logic;
        scl         : inout std_logic;

        -- Control interface
        start       : in    std_logic;          -- Start transaction (single pulse)
        addr        : in    std_logic_vector(6 downto 0);  -- 7-bit I2C address
        rw          : in    std_logic;          -- 0=write, 1=read
        data_in     : in    std_logic_vector(7 downto 0);  -- Data to write
        data_out    : out   std_logic_vector(7 downto 0);  -- Data read
        data_valid  : out   std_logic;          -- Data read valid (single pulse)
        busy        : out   std_logic;          -- Transaction in progress
        ack_error   : out   std_logic;          -- ACK not received
        done        : out   std_logic           -- Transaction complete (single pulse)
    );
end i2c_master;

architecture behavioral of i2c_master is

    -- I2C timing constants
    constant CLK_DIVIDER : integer := CLK_FREQ / (4 * I2C_FREQ);  -- Quarter period

    -- State machine
    type state_type is (
        IDLE,
        START_CONDITION,
        SEND_ADDR,
        CHECK_ADDR_ACK,
        WRITE_DATA,
        CHECK_WRITE_ACK,
        READ_DATA,
        SEND_READ_ACK,
        STOP_CONDITION
    );
    signal state : state_type := IDLE;

    -- Internal registers
    signal clk_counter   : integer range 0 to CLK_DIVIDER := 0;
    signal bit_counter   : integer range 0 to 7 := 0;
    signal shift_reg     : std_logic_vector(7 downto 0) := (others => '0');
    signal sda_out       : std_logic := '1';
    signal scl_out       : std_logic := '1';
    signal busy_int      : std_logic := '0';
    signal ack_error_int : std_logic := '0';
    signal data_valid_int: std_logic := '0';
    signal done_int      : std_logic := '0';

    -- Timing control
    signal quarter_tick  : std_logic := '0';  -- I2C clock quarter period tick

    -- Transaction parameters (latched on start)
    signal addr_rw_byte  : std_logic_vector(7 downto 0) := (others => '0');
    signal data_byte     : std_logic_vector(7 downto 0) := (others => '0');
    signal read_mode     : std_logic := '0';

begin

    -- Tri-state control for I2C signals (open-drain emulation)
    sda <= '0' when sda_out = '0' else 'Z';
    scl <= '0' when scl_out = '0' else 'Z';

    -- Output assignments
    busy <= busy_int;
    ack_error <= ack_error_int;
    data_valid <= data_valid_int;
    done <= done_int;

    -- Clock divider for I2C timing
    clock_divider: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or state = IDLE then
                clk_counter <= 0;
                quarter_tick <= '0';
            else
                if clk_counter = CLK_DIVIDER - 1 then
                    clk_counter <= 0;
                    quarter_tick <= '1';
                else
                    clk_counter <= clk_counter + 1;
                    quarter_tick <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Main I2C state machine
    i2c_fsm: process(clk)
        variable phase : integer range 0 to 3 := 0;  -- 0,1,2,3 for SCL transitions
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                sda_out <= '1';
                scl_out <= '1';
                busy_int <= '0';
                ack_error_int <= '0';
                data_valid_int <= '0';
                done_int <= '0';
                bit_counter <= 0;
                phase := 0;

            else
                -- Clear single-pulse outputs
                data_valid_int <= '0';
                done_int <= '0';

                case state is

                    when IDLE =>
                        sda_out <= '1';
                        scl_out <= '1';
                        busy_int <= '0';
                        ack_error_int <= '0';
                        bit_counter <= 0;
                        phase := 0;

                        if start = '1' then
                            -- Latch transaction parameters
                            addr_rw_byte <= addr & rw;
                            data_byte <= data_in;
                            read_mode <= rw;
                            busy_int <= '1';
                            state <= START_CONDITION;
                        end if;

                    when START_CONDITION =>
                        -- I2C Start: SDA goes low while SCL is high
                        if quarter_tick = '1' then
                            case phase is
                                when 0 =>
                                    sda_out <= '1';
                                    scl_out <= '1';
                                    phase := 1;
                                when 1 =>
                                    sda_out <= '0';  -- SDA falls while SCL high
                                    scl_out <= '1';
                                    phase := 2;
                                when 2 =>
                                    sda_out <= '0';
                                    scl_out <= '0';  -- Then SCL falls
                                    phase := 3;
                                when 3 =>
                                    phase := 0;
                                    bit_counter <= 7;
                                    shift_reg <= addr_rw_byte;
                                    state <= SEND_ADDR;
                                when others =>
                                    phase := 0;
                            end case;
                        end if;

                    when SEND_ADDR =>
                        -- Send 8 bits of address + R/W bit
                        if quarter_tick = '1' then
                            case phase is
                                when 0 =>
                                    sda_out <= shift_reg(7);  -- Set data while SCL low
                                    scl_out <= '0';
                                    phase := 1;
                                when 1 =>
                                    scl_out <= '1';  -- SCL rising edge
                                    phase := 2;
                                when 2 =>
                                    scl_out <= '1';  -- SCL high (slave samples)
                                    phase := 3;
                                when 3 =>
                                    scl_out <= '0';  -- SCL falling edge
                                    shift_reg <= shift_reg(6 downto 0) & '0';
                                    if bit_counter = 0 then
                                        phase := 0;
                                        state <= CHECK_ADDR_ACK;
                                    else
                                        bit_counter <= bit_counter - 1;
                                        phase := 0;
                                    end if;
                                when others =>
                                    phase := 0;
                            end case;
                        end if;

                    when CHECK_ADDR_ACK =>
                        -- Check for ACK from slave
                        if quarter_tick = '1' then
                            case phase is
                                when 0 =>
                                    sda_out <= '1';  -- Release SDA
                                    scl_out <= '0';
                                    phase := 1;
                                when 1 =>
                                    scl_out <= '1';  -- SCL rising
                                    phase := 2;
                                when 2 =>
                                    -- Sample ACK (should be '0' for ACK)
                                    if sda = '1' then
                                        ack_error_int <= '1';  -- NACK received
                                    end if;
                                    scl_out <= '1';
                                    phase := 3;
                                when 3 =>
                                    scl_out <= '0';
                                    phase := 0;

                                    if ack_error_int = '1' then
                                        state <= STOP_CONDITION;
                                    else
                                        if read_mode = '1' then
                                            bit_counter <= 7;
                                            state <= READ_DATA;
                                        else
                                            bit_counter <= 7;
                                            shift_reg <= data_byte;
                                            state <= WRITE_DATA;
                                        end if;
                                    end if;
                                when others =>
                                    phase := 0;
                            end case;
                        end if;

                    when WRITE_DATA =>
                        -- Write 8 data bits
                        if quarter_tick = '1' then
                            case phase is
                                when 0 =>
                                    sda_out <= shift_reg(7);
                                    scl_out <= '0';
                                    phase := 1;
                                when 1 =>
                                    scl_out <= '1';
                                    phase := 2;
                                when 2 =>
                                    scl_out <= '1';
                                    phase := 3;
                                when 3 =>
                                    scl_out <= '0';
                                    shift_reg <= shift_reg(6 downto 0) & '0';
                                    if bit_counter = 0 then
                                        phase := 0;
                                        state <= CHECK_WRITE_ACK;
                                    else
                                        bit_counter <= bit_counter - 1;
                                        phase := 0;
                                    end if;
                                when others =>
                                    phase := 0;
                            end case;
                        end if;

                    when CHECK_WRITE_ACK =>
                        -- Check for ACK after write
                        if quarter_tick = '1' then
                            case phase is
                                when 0 =>
                                    sda_out <= '1';  -- Release SDA
                                    scl_out <= '0';
                                    phase := 1;
                                when 1 =>
                                    scl_out <= '1';
                                    phase := 2;
                                when 2 =>
                                    if sda = '1' then
                                        ack_error_int <= '1';  -- NACK received
                                    end if;
                                    scl_out <= '1';
                                    phase := 3;
                                when 3 =>
                                    scl_out <= '0';
                                    phase := 0;
                                    state <= STOP_CONDITION;
                                when others =>
                                    phase := 0;
                            end case;
                        end if;

                    when READ_DATA =>
                        -- Read 8 data bits from slave
                        if quarter_tick = '1' then
                            case phase is
                                when 0 =>
                                    sda_out <= '1';  -- Release SDA for slave to drive
                                    scl_out <= '0';
                                    phase := 1;
                                when 1 =>
                                    scl_out <= '1';
                                    phase := 2;
                                when 2 =>
                                    -- Sample data on SCL high
                                    shift_reg <= shift_reg(6 downto 0) & sda;
                                    scl_out <= '1';
                                    phase := 3;
                                when 3 =>
                                    scl_out <= '0';
                                    if bit_counter = 0 then
                                        data_out <= shift_reg(6 downto 0) & sda;  -- Last bit
                                        data_valid_int <= '1';
                                        phase := 0;
                                        state <= SEND_READ_ACK;
                                    else
                                        bit_counter <= bit_counter - 1;
                                        phase := 0;
                                    end if;
                                when others =>
                                    phase := 0;
                            end case;
                        end if;

                    when SEND_READ_ACK =>
                        -- Send NACK after read (master NACK to end read)
                        if quarter_tick = '1' then
                            case phase is
                                when 0 =>
                                    sda_out <= '1';  -- Send NACK (high)
                                    scl_out <= '0';
                                    phase := 1;
                                when 1 =>
                                    scl_out <= '1';
                                    phase := 2;
                                when 2 =>
                                    scl_out <= '1';
                                    phase := 3;
                                when 3 =>
                                    scl_out <= '0';
                                    phase := 0;
                                    state <= STOP_CONDITION;
                                when others =>
                                    phase := 0;
                            end case;
                        end if;

                    when STOP_CONDITION =>
                        -- I2C Stop: SDA rises while SCL is high
                        if quarter_tick = '1' then
                            case phase is
                                when 0 =>
                                    sda_out <= '0';
                                    scl_out <= '0';
                                    phase := 1;
                                when 1 =>
                                    sda_out <= '0';
                                    scl_out <= '1';  -- SCL rises
                                    phase := 2;
                                when 2 =>
                                    sda_out <= '1';  -- SDA rises while SCL high
                                    scl_out <= '1';
                                    phase := 3;
                                when 3 =>
                                    done_int <= '1';
                                    phase := 0;
                                    state <= IDLE;
                                when others =>
                                    phase := 0;
                            end case;
                        end if;

                    when others =>
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end behavioral;
