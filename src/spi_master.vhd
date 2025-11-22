-- SPI Master Controller
-- Supports all 4 SPI modes (CPOL/CPHA combinations)
-- Configurable word length (5-32 bits) and clock divider
-- Features: 4 chip selects, programmable clock polarity and phase
-- Author: RF Test Automation Engineering
-- Date: 2025-11-22

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master is
    generic (
        CLK_FREQ    : integer := 100_000_000   -- System clock frequency in Hz
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- SPI bus signals
        sclk        : out std_logic;
        mosi        : out std_logic;
        miso        : in  std_logic;
        cs          : out std_logic_vector(3 downto 0);

        -- Configuration interface
        cpol        : in  std_logic;           -- Clock polarity (0=idle low, 1=idle high)
        cpha        : in  std_logic;           -- Clock phase (0=leading edge, 1=trailing edge)
        word_len    : in  std_logic_vector(4 downto 0);  -- Word length-1 (4 to 31 -> 5 to 32 bits)
        clk_div     : in  std_logic_vector(15 downto 0); -- Clock divider
        chip_sel    : in  std_logic_vector(3 downto 0);  -- Chip select (one-hot)

        -- Control interface
        start       : in  std_logic;           -- Start transaction (single pulse)
        data_in     : in  std_logic_vector(31 downto 0);  -- Data to transmit
        data_out    : out std_logic_vector(31 downto 0);  -- Data received
        data_valid  : out std_logic;           -- Data valid (single pulse)
        busy        : out std_logic;           -- Transaction in progress
        done        : out std_logic            -- Transaction complete (single pulse)
    );
end spi_master;

architecture behavioral of spi_master is

    -- State machine
    type state_type is (IDLE, CS_SETUP, TRANSFER, CS_HOLD);
    signal state : state_type := IDLE;

    -- Internal registers
    signal clk_counter   : unsigned(15 downto 0) := (others => '0');
    signal bit_counter   : integer range 0 to 31 := 0;
    signal shift_out     : std_logic_vector(31 downto 0) := (others => '0');
    signal shift_in      : std_logic_vector(31 downto 0) := (others => '0');
    signal sclk_int      : std_logic := '0';
    signal mosi_int      : std_logic := '0';
    signal cs_int        : std_logic_vector(3 downto 0) := (others => '1');
    signal busy_int      : std_logic := '0';
    signal data_valid_int: std_logic := '0';
    signal done_int      : std_logic := '0';

    -- Configuration latched at start
    signal cpol_latch    : std_logic := '0';
    signal cpha_latch    : std_logic := '0';
    signal word_len_latch: integer range 0 to 31 := 0;
    signal clk_div_latch : unsigned(15 downto 0) := (others => '0');
    signal chip_sel_latch: std_logic_vector(3 downto 0) := (others => '1');

    -- Edge detection
    signal sclk_edge     : std_logic := '0';  -- Clock edge for sampling/shifting
    signal half_period   : std_logic := '0';  -- Half period tick

    -- Transfer control
    signal bits_to_send  : integer range 0 to 32 := 0;
    signal edge_count    : integer range 0 to 63 := 0;

begin

    -- Output assignments
    sclk <= sclk_int;
    mosi <= mosi_int;
    cs <= cs_int;
    busy <= busy_int;
    data_valid <= data_valid_int;
    done <= done_int;

    -- Clock divider
    clock_divider: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or state = IDLE then
                clk_counter <= (others => '0');
                half_period <= '0';
            else
                if clk_counter >= clk_div_latch then
                    clk_counter <= (others => '0');
                    half_period <= '1';
                else
                    clk_counter <= clk_counter + 1;
                    half_period <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Edge generation based on CPOL/CPHA
    -- CPHA=0: Sample on first edge, shift on second edge
    -- CPHA=1: Shift on first edge, sample on second edge
    edge_detection: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or state = IDLE then
                sclk_edge <= '0';
            else
                if half_period = '1' and state = TRANSFER then
                    sclk_edge <= '1';
                else
                    sclk_edge <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Main SPI state machine
    spi_fsm: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                sclk_int <= '0';
                mosi_int <= '0';
                cs_int <= (others => '1');
                busy_int <= '0';
                data_valid_int <= '0';
                done_int <= '0';
                bit_counter <= 0;
                edge_count <= 0;

            else
                -- Clear single-pulse outputs
                data_valid_int <= '0';
                done_int <= '0';

                case state is

                    when IDLE =>
                        cs_int <= (others => '1');
                        mosi_int <= '0';
                        sclk_int <= cpol;  -- Idle state depends on CPOL
                        busy_int <= '0';

                        if start = '1' then
                            -- Latch configuration
                            cpol_latch <= cpol;
                            cpha_latch <= cpha;
                            word_len_latch <= to_integer(unsigned(word_len));
                            clk_div_latch <= unsigned(clk_div);
                            chip_sel_latch <= chip_sel;
                            shift_out <= data_in;
                            shift_in <= (others => '0');

                            bits_to_send <= to_integer(unsigned(word_len)) + 1;
                            bit_counter <= to_integer(unsigned(word_len));
                            edge_count <= 0;

                            busy_int <= '1';
                            sclk_int <= cpol;
                            state <= CS_SETUP;
                        end if;

                    when CS_SETUP =>
                        -- Assert chip select
                        cs_int <= not chip_sel_latch;  -- Active low CS

                        -- For CPHA=0, set first data bit before first clock edge
                        if cpha_latch = '0' then
                            mosi_int <= shift_out(bit_counter);
                        end if;

                        if half_period = '1' then
                            state <= TRANSFER;
                        end if;

                    when TRANSFER =>
                        -- SPI data transfer with configurable CPOL/CPHA
                        if half_period = '1' then
                            -- Toggle SCLK
                            sclk_int <= not sclk_int;
                            edge_count <= edge_count + 1;

                            -- Determine if this is a sample edge or shift edge
                            -- CPHA=0: Sample on odd edges (1,3,5...), Shift on even edges (2,4,6...)
                            -- CPHA=1: Shift on odd edges (1,3,5...), Sample on even edges (2,4,6...)

                            if cpha_latch = '0' then
                                -- CPHA=0 mode
                                if (edge_count mod 2) = 0 then
                                    -- Even edges: sample MISO
                                    shift_in <= shift_in(30 downto 0) & miso;

                                    if bit_counter = 0 then
                                        -- Last bit sampled
                                        data_out <= shift_in(30 downto 0) & miso;
                                        data_valid_int <= '1';
                                        state <= CS_HOLD;
                                    else
                                        bit_counter <= bit_counter - 1;
                                    end if;
                                else
                                    -- Odd edges: shift out next bit
                                    if bit_counter > 0 then
                                        mosi_int <= shift_out(bit_counter - 1);
                                    end if;
                                end if;
                            else
                                -- CPHA=1 mode
                                if (edge_count mod 2) = 1 then
                                    -- Odd edges: shift out data
                                    mosi_int <= shift_out(bit_counter);
                                else
                                    -- Even edges: sample MISO
                                    shift_in <= shift_in(30 downto 0) & miso;

                                    if bit_counter = 0 then
                                        -- Last bit sampled
                                        data_out <= shift_in(30 downto 0) & miso;
                                        data_valid_int <= '1';
                                        state <= CS_HOLD;
                                    else
                                        bit_counter <= bit_counter - 1;
                                    end if;
                                end if;
                            end if;
                        end if;

                    when CS_HOLD =>
                        -- Hold CS for half period, then deassert
                        if half_period = '1' then
                            cs_int <= (others => '1');
                            sclk_int <= cpol_latch;  -- Return to idle state
                            done_int <= '1';
                            state <= IDLE;
                        end if;

                    when others =>
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end behavioral;
