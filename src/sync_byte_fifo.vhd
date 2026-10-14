-- Single-clock byte FIFO with a registered, first-word-visible output.
-- A full FIFO accepts a write when a read occurs on the same edge.
-- An empty simultaneous read/write queues the byte and reports underflow.
library ieee;
use ieee.std_logic_1164.all;
entity sync_byte_fifo is
    generic (DEPTH : positive := 64);
    port (clk, rst : in std_logic;
          push, pop : in std_logic;
          data_in : in std_logic_vector(7 downto 0);
          data_out : out std_logic_vector(7 downto 0);
          empty, full : out std_logic;
          level : out natural range 0 to DEPTH;
          overflow, underflow : out std_logic);
end entity;
architecture rtl of sync_byte_fifo is
    type memory_type is array (0 to DEPTH-1) of std_logic_vector(7 downto 0);
    signal memory : memory_type;
    attribute ramstyle : string;
    attribute ramstyle of memory : signal is "M9K";
    signal read_ptr, write_ptr : natural range 0 to DEPTH-1 := 0;
    signal count : natural range 0 to DEPTH := 0;
    signal ram_head, bypass_data : std_logic_vector(7 downto 0);
    signal bypass_valid : boolean := false;
    signal read_ok, write_ok : boolean;
    signal next_read : natural range 0 to DEPTH-1;
    function advance(pointer : natural) return natural is
    begin
        if pointer = DEPTH-1 then return 0; else return pointer+1; end if;
    end function;
begin
    empty <= '1' when count = 0 else '0';
    full <= '1' when count = DEPTH else '0';
    level <= count;
    data_out <= (others => '0') when count = 0 else
                bypass_data when bypass_valid else ram_head;
    read_ok <= pop = '1' and count /= 0 and rst = '0';
    write_ok <= push = '1' and (count /= DEPTH or read_ok) and rst = '0';
    next_read <= advance(read_ptr) when read_ok else read_ptr;

    -- Keep the synchronous RAM read register free of reset and bypass muxes.
    -- Forward collisions outside the RAM so Quartus can infer an M9K block.
    process(clk)
    begin
        if rising_edge(clk) then
            if write_ok then memory(write_ptr) <= data_in; end if;
            ram_head <= memory(next_read);
            bypass_data <= data_in;
            bypass_valid <= write_ok and (count = 0 or (count = 1 and read_ok));
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            overflow <= '0'; underflow <= '0';
            if rst = '1' then
                read_ptr <= 0; write_ptr <= 0; count <= 0;
            else
                if push = '1' and not write_ok then overflow <= '1'; end if;
                if pop = '1' and not read_ok then underflow <= '1'; end if;
                read_ptr <= next_read;
                if write_ok then
                    write_ptr <= advance(write_ptr);
                end if;
                if write_ok and not read_ok then count <= count + 1;
                elsif read_ok and not write_ok then count <= count - 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
