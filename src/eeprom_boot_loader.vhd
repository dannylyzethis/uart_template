-- EEPROM Boot Loader
-- Automatically loads LUTs from I2C EEPROM on power-up
-- Supports multiple LUT types for calibration, correction, and configuration
-- Author: RF Test Automation Engineering
-- Date: 2025-11-22

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity eeprom_boot_loader is
    generic (
        CLK_FREQ        : integer := 100_000_000;   -- System clock frequency
        EEPROM_ADDR     : std_logic_vector(6 downto 0) := "1010000"  -- I2C address (0x50 for 24LC256)
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;

        -- I2C master interface
        i2c_start       : out std_logic;
        i2c_addr        : out std_logic_vector(6 downto 0);
        i2c_rw          : out std_logic;  -- 0=write, 1=read
        i2c_data_out    : out std_logic_vector(7 downto 0);
        i2c_data_in     : in  std_logic_vector(7 downto 0);
        i2c_data_valid  : in  std_logic;
        i2c_busy        : in  std_logic;
        i2c_ack_error   : in  std_logic;
        i2c_done        : in  std_logic;

        -- LUT RAM interfaces (4 LUTs, each 256×32-bit)
        -- LUT0: Calibration data (ADC/DAC offsets, gains)
        lut0_addr       : in  std_logic_vector(7 downto 0);
        lut0_data       : out std_logic_vector(31 downto 0);
        lut0_we         : in  std_logic;
        lut0_din        : in  std_logic_vector(31 downto 0);

        -- LUT1: Correction/linearization table
        lut1_addr       : in  std_logic_vector(7 downto 0);
        lut1_data       : out std_logic_vector(31 downto 0);
        lut1_we         : in  std_logic;
        lut1_din        : in  std_logic_vector(31 downto 0);

        -- LUT2: Temperature compensation coefficients
        lut2_addr       : in  std_logic_vector(7 downto 0);
        lut2_data       : out std_logic_vector(31 downto 0);
        lut2_we         : in  std_logic;
        lut2_din        : in  std_logic_vector(31 downto 0);

        -- LUT3: Waveform/pattern data
        lut3_addr       : in  std_logic_vector(7 downto 0);
        lut3_data       : out std_logic_vector(31 downto 0);
        lut3_we         : in  std_logic;
        lut3_din        : in  std_logic_vector(31 downto 0);

        -- Control interface
        boot_start      : in  std_logic;  -- Manual boot trigger
        boot_busy       : out std_logic;
        boot_done       : out std_logic;
        boot_error      : out std_logic;
        boot_error_code : out std_logic_vector(7 downto 0);

        -- Status outputs
        lut0_valid      : out std_logic;  -- LUT0 loaded successfully
        lut1_valid      : out std_logic;
        lut2_valid      : out std_logic;
        lut3_valid      : out std_logic;
        boot_progress   : out std_logic_vector(7 downto 0)  -- Current boot step
    );
end eeprom_boot_loader;

architecture behavioral of eeprom_boot_loader is

    -- EEPROM memory map (24LC256 = 32KB = 256 pages × 128 bytes)
    -- Address 0x0000-0x000F: Header (16 bytes)
    --   0x0000-0x0003: Magic number "LFPG" (LUT FPGA)
    --   0x0004: Format version
    --   0x0005: Number of LUTs (1-4)
    --   0x0006-0x0007: Total data size (bytes)
    --   0x0008-0x000B: Header CRC32
    --   0x000C-0x000F: Reserved
    -- Address 0x0010-0x002F: LUT descriptors (4 × 8 bytes = 32 bytes)
    --   Each descriptor:
    --     [0-1]: LUT size (entries, 0-256)
    --     [2]: Entry width (bytes: 1, 2, 4)
    --     [3]: LUT type (0=cal, 1=corr, 2=temp, 3=wave)
    --     [4-7]: LUT CRC32
    -- Address 0x0030+: LUT data
    --   LUT0: 256 entries × 4 bytes = 1024 bytes @ 0x0030
    --   LUT1: 256 entries × 4 bytes = 1024 bytes @ 0x0430
    --   LUT2: 256 entries × 4 bytes = 1024 bytes @ 0x0830
    --   LUT3: 256 entries × 4 bytes = 1024 bytes @ 0x0C30

    constant MAGIC_NUMBER : std_logic_vector(31 downto 0) := x"4C465047";  -- "LFPG"
    constant FORMAT_VERSION : std_logic_vector(7 downto 0) := x"01";

    -- Boot state machine
    type boot_state_type is (
        BOOT_IDLE,
        BOOT_WAIT_STABLE,       -- Wait for I2C bus to stabilize
        BOOT_READ_MAGIC_0,      -- Read magic number byte 0
        BOOT_READ_MAGIC_1,
        BOOT_READ_MAGIC_2,
        BOOT_READ_MAGIC_3,
        BOOT_CHECK_MAGIC,       -- Verify magic number
        BOOT_READ_VERSION,
        BOOT_READ_NUM_LUTS,
        BOOT_READ_SIZE_H,
        BOOT_READ_SIZE_L,
        BOOT_READ_LUT_DESC,     -- Read LUT descriptors
        BOOT_LOAD_LUT0,         -- Load LUT data
        BOOT_LOAD_LUT1,
        BOOT_LOAD_LUT2,
        BOOT_LOAD_LUT3,
        BOOT_VERIFY_CRC,        -- Verify each LUT CRC
        BOOT_COMPLETE,
        BOOT_ERROR
    );
    signal boot_state : boot_state_type := BOOT_IDLE;

    -- I2C transaction state
    type i2c_state_type is (I2C_IDLE, I2C_SET_ADDR, I2C_WRITE_ADDR_H, I2C_WRITE_ADDR_L,
                            I2C_READ_DATA, I2C_WAIT_DONE);
    signal i2c_state : i2c_state_type := I2C_IDLE;

    -- Boot control signals
    signal boot_busy_int    : std_logic := '0';
    signal boot_done_int    : std_logic := '0';
    signal boot_error_int   : std_logic := '0';
    signal error_code       : std_logic_vector(7 downto 0) := (others => '0');
    signal auto_boot_done   : std_logic := '0';  -- Auto-boot completed flag

    -- EEPROM read address
    signal eeprom_addr_ptr  : unsigned(15 downto 0) := (others => '0');

    -- Header data
    signal magic_number_buf : std_logic_vector(31 downto 0) := (others => '0');
    signal format_version_buf : std_logic_vector(7 downto 0) := (others => '0');
    signal num_luts_buf     : unsigned(7 downto 0) := (others => '0');
    signal total_size_buf   : unsigned(15 downto 0) := (others => '0');

    -- LUT descriptors
    type lut_desc_type is record
        size        : unsigned(15 downto 0);  -- Number of entries
        width       : unsigned(7 downto 0);   -- Bytes per entry (1, 2, 4)
        lut_type    : unsigned(7 downto 0);   -- LUT type
        crc         : unsigned(31 downto 0);  -- CRC32 of LUT data
    end record;

    type lut_desc_array_type is array (0 to 3) of lut_desc_type;
    signal lut_desc : lut_desc_array_type;

    -- Current LUT being loaded
    signal current_lut      : integer range 0 to 3 := 0;
    signal lut_entry_count  : unsigned(15 downto 0) := (others => '0');
    signal lut_byte_count   : integer range 0 to 3 := 0;
    signal lut_data_buffer  : std_logic_vector(31 downto 0) := (others => '0');

    -- LUT valid flags
    signal lut0_valid_int   : std_logic := '0';
    signal lut1_valid_int   : std_logic := '0';
    signal lut2_valid_int   : std_logic := '0';
    signal lut3_valid_int   : std_logic := '0';

    -- Progress counter
    signal progress_count   : unsigned(7 downto 0) := (others => '0');

    -- Startup delay counter (wait for power supply stabilization)
    signal startup_counter  : integer range 0 to CLK_FREQ/10 := CLK_FREQ/10;  -- 100ms delay

    -- I2C byte read result
    signal i2c_byte_ready   : std_logic := '0';
    signal i2c_byte_data    : std_logic_vector(7 downto 0) := (others => '0');

    -- LUT RAM signals (dual-port RAM for each LUT)
    -- Port A: Boot loader write
    -- Port B: User read/write
    signal lut0_ram_we_a    : std_logic := '0';
    signal lut0_ram_addr_a  : std_logic_vector(7 downto 0) := (others => '0');
    signal lut0_ram_din_a   : std_logic_vector(31 downto 0) := (others => '0');

    signal lut1_ram_we_a    : std_logic := '0';
    signal lut1_ram_addr_a  : std_logic_vector(7 downto 0) := (others => '0');
    signal lut1_ram_din_a   : std_logic_vector(31 downto 0) := (others => '0');

    signal lut2_ram_we_a    : std_logic := '0';
    signal lut2_ram_addr_a  : std_logic_vector(7 downto 0) := (others => '0');
    signal lut2_ram_din_a   : std_logic_vector(31 downto 0) := (others => '0');

    signal lut3_ram_we_a    : std_logic := '0';
    signal lut3_ram_addr_a  : std_logic_vector(7 downto 0) := (others => '0');
    signal lut3_ram_din_a   : std_logic_vector(31 downto 0) := (others => '0');

    -- Error codes
    constant ERR_NONE           : std_logic_vector(7 downto 0) := x"00";
    constant ERR_MAGIC_MISMATCH : std_logic_vector(7 downto 0) := x"01";
    constant ERR_VERSION        : std_logic_vector(7 downto 0) := x"02";
    constant ERR_I2C_NACK       : std_logic_vector(7 downto 0) := x"03";
    constant ERR_CRC_FAIL       : std_logic_vector(7 downto 0) := x"04";
    constant ERR_TIMEOUT        : std_logic_vector(7 downto 0) := x"05";

begin

    -- Output assignments
    boot_busy <= boot_busy_int;
    boot_done <= boot_done_int;
    boot_error <= boot_error_int;
    boot_error_code <= error_code;
    boot_progress <= std_logic_vector(progress_count);

    lut0_valid <= lut0_valid_int;
    lut1_valid <= lut1_valid_int;
    lut2_valid <= lut2_valid_int;
    lut3_valid <= lut3_valid_int;

    -- Dual-port RAM instantiation for LUT0 (Calibration data)
    lut0_ram: process(clk)
        type ram_type is array (0 to 255) of std_logic_vector(31 downto 0);
        variable ram : ram_type := (others => (others => '0'));
    begin
        if rising_edge(clk) then
            -- Port A: Boot loader write
            if lut0_ram_we_a = '1' then
                ram(to_integer(unsigned(lut0_ram_addr_a))) := lut0_ram_din_a;
            end if;

            -- Port B: User read/write
            if lut0_we = '1' then
                ram(to_integer(unsigned(lut0_addr))) := lut0_din;
            end if;
            lut0_data <= ram(to_integer(unsigned(lut0_addr)));
        end if;
    end process;

    -- Dual-port RAM instantiation for LUT1 (Correction/linearization)
    lut1_ram: process(clk)
        type ram_type is array (0 to 255) of std_logic_vector(31 downto 0);
        variable ram : ram_type := (others => (others => '0'));
    begin
        if rising_edge(clk) then
            if lut1_ram_we_a = '1' then
                ram(to_integer(unsigned(lut1_ram_addr_a))) := lut1_ram_din_a;
            end if;
            if lut1_we = '1' then
                ram(to_integer(unsigned(lut1_addr))) := lut1_din;
            end if;
            lut1_data <= ram(to_integer(unsigned(lut1_addr)));
        end if;
    end process;

    -- Dual-port RAM instantiation for LUT2 (Temperature compensation)
    lut2_ram: process(clk)
        type ram_type is array (0 to 255) of std_logic_vector(31 downto 0);
        variable ram : ram_type := (others => (others => '0'));
    begin
        if rising_edge(clk) then
            if lut2_ram_we_a = '1' then
                ram(to_integer(unsigned(lut2_ram_addr_a))) := lut2_ram_din_a;
            end if;
            if lut2_we = '1' then
                ram(to_integer(unsigned(lut2_addr))) := lut2_din;
            end if;
            lut2_data <= ram(to_integer(unsigned(lut2_addr)));
        end if;
    end process;

    -- Dual-port RAM instantiation for LUT3 (Waveform data)
    lut3_ram: process(clk)
        type ram_type is array (0 to 255) of std_logic_vector(31 downto 0);
        variable ram : ram_type := (others => (others => '0'));
    begin
        if rising_edge(clk) then
            if lut3_ram_we_a = '1' then
                ram(to_integer(unsigned(lut3_ram_addr_a))) := lut3_ram_din_a;
            end if;
            if lut3_we = '1' then
                ram(to_integer(unsigned(lut3_addr))) := lut3_din;
            end if;
            lut3_data <= ram(to_integer(unsigned(lut3_addr)));
        end if;
    end process;

    -- I2C byte read helper process
    -- Reads a single byte from current EEPROM address
    i2c_read_byte: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                i2c_state <= I2C_IDLE;
                i2c_start <= '0';
                i2c_byte_ready <= '0';
            else
                -- Clear byte ready strobe
                i2c_byte_ready <= '0';
                i2c_start <= '0';

                case i2c_state is
                    when I2C_IDLE =>
                        -- Triggered by boot controller
                        null;

                    when I2C_SET_ADDR =>
                        -- Write EEPROM address (16-bit address for 24LC256)
                        i2c_addr <= EEPROM_ADDR;
                        i2c_rw <= '0';  -- Write mode
                        i2c_data_out <= std_logic_vector(eeprom_addr_ptr(15 downto 8));
                        i2c_start <= '1';
                        i2c_state <= I2C_WRITE_ADDR_H;

                    when I2C_WRITE_ADDR_H =>
                        if i2c_done = '1' then
                            if i2c_ack_error = '1' then
                                i2c_state <= I2C_IDLE;  -- Error
                            else
                                -- Write low byte of address
                                i2c_data_out <= std_logic_vector(eeprom_addr_ptr(7 downto 0));
                                i2c_start <= '1';
                                i2c_state <= I2C_WRITE_ADDR_L;
                            end if;
                        end if;

                    when I2C_WRITE_ADDR_L =>
                        if i2c_done = '1' then
                            if i2c_ack_error = '1' then
                                i2c_state <= I2C_IDLE;
                            else
                                -- Now read data byte
                                i2c_rw <= '1';  -- Read mode
                                i2c_start <= '1';
                                i2c_state <= I2C_READ_DATA;
                            end if;
                        end if;

                    when I2C_READ_DATA =>
                        if i2c_data_valid = '1' then
                            i2c_byte_data <= i2c_data_in;
                            i2c_byte_ready <= '1';
                            eeprom_addr_ptr <= eeprom_addr_ptr + 1;  -- Auto-increment
                            i2c_state <= I2C_IDLE;
                        end if;

                    when others =>
                        i2c_state <= I2C_IDLE;
                end case;
            end if;
        end if;
    end process;

    -- Main boot controller
    boot_controller: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                boot_state <= BOOT_IDLE;
                boot_busy_int <= '0';
                boot_done_int <= '0';
                boot_error_int <= '0';
                error_code <= ERR_NONE;
                auto_boot_done <= '0';
                startup_counter <= CLK_FREQ/10;
                progress_count <= (others => '0');
                lut0_valid_int <= '0';
                lut1_valid_int <= '0';
                lut2_valid_int <= '0';
                lut3_valid_int <= '0';
                lut0_ram_we_a <= '0';
                lut1_ram_we_a <= '0';
                lut2_ram_we_a <= '0';
                lut3_ram_we_a <= '0';
            else
                -- Clear RAM write enables
                lut0_ram_we_a <= '0';
                lut1_ram_we_a <= '0';
                lut2_ram_we_a <= '0';
                lut3_ram_we_a <= '0';

                case boot_state is
                    when BOOT_IDLE =>
                        -- Auto-boot on power-up OR manual boot trigger
                        if (auto_boot_done = '0' and startup_counter = 0) or boot_start = '1' then
                            boot_busy_int <= '1';
                            boot_done_int <= '0';
                            boot_error_int <= '0';
                            error_code <= ERR_NONE;
                            eeprom_addr_ptr <= (others => '0');
                            progress_count <= x"00";
                            boot_state <= BOOT_WAIT_STABLE;
                        end if;

                        -- Startup delay countdown
                        if startup_counter > 0 then
                            startup_counter <= startup_counter - 1;
                        end if;

                    when BOOT_WAIT_STABLE =>
                        -- Wait for I2C bus idle
                        if i2c_busy = '0' and i2c_state = I2C_IDLE then
                            progress_count <= x"01";
                            -- Start reading header: magic number
                            eeprom_addr_ptr <= x"0000";
                            i2c_state <= I2C_SET_ADDR;
                            boot_state <= BOOT_READ_MAGIC_0;
                        end if;

                    when BOOT_READ_MAGIC_0 =>
                        if i2c_byte_ready = '1' then
                            magic_number_buf(31 downto 24) <= i2c_byte_data;
                            i2c_state <= I2C_SET_ADDR;
                            boot_state <= BOOT_READ_MAGIC_1;
                        elsif i2c_ack_error = '1' then
                            error_code <= ERR_I2C_NACK;
                            boot_state <= BOOT_ERROR;
                        end if;

                    when BOOT_READ_MAGIC_1 =>
                        if i2c_byte_ready = '1' then
                            magic_number_buf(23 downto 16) <= i2c_byte_data;
                            i2c_state <= I2C_SET_ADDR;
                            boot_state <= BOOT_READ_MAGIC_2;
                        end if;

                    when BOOT_READ_MAGIC_2 =>
                        if i2c_byte_ready = '1' then
                            magic_number_buf(15 downto 8) <= i2c_byte_data;
                            i2c_state <= I2C_SET_ADDR;
                            boot_state <= BOOT_READ_MAGIC_3;
                        end if;

                    when BOOT_READ_MAGIC_3 =>
                        if i2c_byte_ready = '1' then
                            magic_number_buf(7 downto 0) <= i2c_byte_data;
                            boot_state <= BOOT_CHECK_MAGIC;
                        end if;

                    when BOOT_CHECK_MAGIC =>
                        progress_count <= x"02";
                        if magic_number_buf = MAGIC_NUMBER then
                            -- Magic number valid, continue
                            i2c_state <= I2C_SET_ADDR;
                            boot_state <= BOOT_READ_VERSION;
                        else
                            -- Invalid magic number
                            error_code <= ERR_MAGIC_MISMATCH;
                            boot_state <= BOOT_ERROR;
                        end if;

                    when BOOT_READ_VERSION =>
                        if i2c_byte_ready = '1' then
                            format_version_buf <= i2c_byte_data;
                            i2c_state <= I2C_SET_ADDR;
                            boot_state <= BOOT_READ_NUM_LUTS;
                        end if;

                    when BOOT_READ_NUM_LUTS =>
                        if i2c_byte_ready = '1' then
                            num_luts_buf <= unsigned(i2c_byte_data);
                            i2c_state <= I2C_SET_ADDR;
                            boot_state <= BOOT_READ_SIZE_H;
                        end if;

                    when BOOT_READ_SIZE_H =>
                        if i2c_byte_ready = '1' then
                            total_size_buf(15 downto 8) <= unsigned(i2c_byte_data);
                            i2c_state <= I2C_SET_ADDR;
                            boot_state <= BOOT_READ_SIZE_L;
                        end if;

                    when BOOT_READ_SIZE_L =>
                        if i2c_byte_ready = '1' then
                            total_size_buf(7 downto 0) <= unsigned(i2c_byte_data);
                            progress_count <= x"03";
                            -- For now, skip descriptor reading and go straight to LUT loading
                            -- In full implementation, read 32 bytes of descriptors here
                            eeprom_addr_ptr <= x"0030";  -- Start of LUT0 data
                            current_lut <= 0;
                            lut_entry_count <= (others => '0');
                            lut_byte_count <= 0;
                            boot_state <= BOOT_LOAD_LUT0;
                        end if;

                    when BOOT_LOAD_LUT0 =>
                        -- Load 256 entries × 4 bytes = 1024 bytes
                        progress_count <= x"10";
                        if lut_entry_count < 256 then
                            if i2c_byte_ready = '1' then
                                -- Pack 4 bytes into 32-bit word
                                case lut_byte_count is
                                    when 0 => lut_data_buffer(31 downto 24) <= i2c_byte_data;
                                    when 1 => lut_data_buffer(23 downto 16) <= i2c_byte_data;
                                    when 2 => lut_data_buffer(15 downto 8) <= i2c_byte_data;
                                    when 3 =>
                                        lut_data_buffer(7 downto 0) <= i2c_byte_data;
                                        -- Write complete word to LUT0 RAM
                                        lut0_ram_addr_a <= std_logic_vector(lut_entry_count(7 downto 0));
                                        lut0_ram_din_a <= lut_data_buffer(31 downto 8) & i2c_byte_data;
                                        lut0_ram_we_a <= '1';
                                        lut_entry_count <= lut_entry_count + 1;
                                    when others => null;
                                end case;

                                if lut_byte_count = 3 then
                                    lut_byte_count <= 0;
                                    i2c_state <= I2C_SET_ADDR;  -- Trigger next read
                                else
                                    lut_byte_count <= lut_byte_count + 1;
                                    i2c_state <= I2C_SET_ADDR;
                                end if;
                            elsif i2c_state = I2C_IDLE then
                                -- Trigger next byte read
                                i2c_state <= I2C_SET_ADDR;
                            end if;
                        else
                            -- LUT0 complete
                            lut0_valid_int <= '1';
                            lut_entry_count <= (others => '0');
                            lut_byte_count <= 0;
                            boot_state <= BOOT_LOAD_LUT1;
                        end if;

                    when BOOT_LOAD_LUT1 =>
                        progress_count <= x"20";
                        if lut_entry_count < 256 then
                            if i2c_byte_ready = '1' then
                                case lut_byte_count is
                                    when 0 => lut_data_buffer(31 downto 24) <= i2c_byte_data;
                                    when 1 => lut_data_buffer(23 downto 16) <= i2c_byte_data;
                                    when 2 => lut_data_buffer(15 downto 8) <= i2c_byte_data;
                                    when 3 =>
                                        lut1_ram_addr_a <= std_logic_vector(lut_entry_count(7 downto 0));
                                        lut1_ram_din_a <= lut_data_buffer(31 downto 8) & i2c_byte_data;
                                        lut1_ram_we_a <= '1';
                                        lut_entry_count <= lut_entry_count + 1;
                                    when others => null;
                                end case;

                                if lut_byte_count = 3 then
                                    lut_byte_count <= 0;
                                    i2c_state <= I2C_SET_ADDR;
                                else
                                    lut_byte_count <= lut_byte_count + 1;
                                    i2c_state <= I2C_SET_ADDR;
                                end if;
                            elsif i2c_state = I2C_IDLE then
                                i2c_state <= I2C_SET_ADDR;
                            end if;
                        else
                            lut1_valid_int <= '1';
                            lut_entry_count <= (others => '0');
                            lut_byte_count <= 0;
                            boot_state <= BOOT_LOAD_LUT2;
                        end if;

                    when BOOT_LOAD_LUT2 =>
                        progress_count <= x"30";
                        if lut_entry_count < 256 then
                            if i2c_byte_ready = '1' then
                                case lut_byte_count is
                                    when 0 => lut_data_buffer(31 downto 24) <= i2c_byte_data;
                                    when 1 => lut_data_buffer(23 downto 16) <= i2c_byte_data;
                                    when 2 => lut_data_buffer(15 downto 8) <= i2c_byte_data;
                                    when 3 =>
                                        lut2_ram_addr_a <= std_logic_vector(lut_entry_count(7 downto 0));
                                        lut2_ram_din_a <= lut_data_buffer(31 downto 8) & i2c_byte_data;
                                        lut2_ram_we_a <= '1';
                                        lut_entry_count <= lut_entry_count + 1;
                                    when others => null;
                                end case;

                                if lut_byte_count = 3 then
                                    lut_byte_count <= 0;
                                    i2c_state <= I2C_SET_ADDR;
                                else
                                    lut_byte_count <= lut_byte_count + 1;
                                    i2c_state <= I2C_SET_ADDR;
                                end if;
                            elsif i2c_state = I2C_IDLE then
                                i2c_state <= I2C_SET_ADDR;
                            end if;
                        else
                            lut2_valid_int <= '1';
                            lut_entry_count <= (others => '0');
                            lut_byte_count <= 0;
                            boot_state <= BOOT_LOAD_LUT3;
                        end if;

                    when BOOT_LOAD_LUT3 =>
                        progress_count <= x"40";
                        if lut_entry_count < 256 then
                            if i2c_byte_ready = '1' then
                                case lut_byte_count is
                                    when 0 => lut_data_buffer(31 downto 24) <= i2c_byte_data;
                                    when 1 => lut_data_buffer(23 downto 16) <= i2c_byte_data;
                                    when 2 => lut_data_buffer(15 downto 8) <= i2c_byte_data;
                                    when 3 =>
                                        lut3_ram_addr_a <= std_logic_vector(lut_entry_count(7 downto 0));
                                        lut3_ram_din_a <= lut_data_buffer(31 downto 8) & i2c_byte_data;
                                        lut3_ram_we_a <= '1';
                                        lut_entry_count <= lut_entry_count + 1;
                                    when others => null;
                                end case;

                                if lut_byte_count = 3 then
                                    lut_byte_count <= 0;
                                    i2c_state <= I2C_SET_ADDR;
                                else
                                    lut_byte_count <= lut_byte_count + 1;
                                    i2c_state <= I2C_SET_ADDR;
                                end if;
                            elsif i2c_state = I2C_IDLE then
                                i2c_state <= I2C_SET_ADDR;
                            end if;
                        else
                            lut3_valid_int <= '1';
                            boot_state <= BOOT_COMPLETE;
                        end if;

                    when BOOT_COMPLETE =>
                        progress_count <= x"FF";
                        boot_busy_int <= '0';
                        boot_done_int <= '1';
                        auto_boot_done <= '1';
                        boot_state <= BOOT_IDLE;

                    when BOOT_ERROR =>
                        boot_busy_int <= '0';
                        boot_error_int <= '1';
                        auto_boot_done <= '1';  -- Don't retry on error
                        boot_state <= BOOT_IDLE;

                    when others =>
                        boot_state <= BOOT_IDLE;
                end case;
            end if;
        end if;
    end process;

end behavioral;
