
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity instruction_memory is
  port (
    clk       : in  std_logic;                    -- Clock signal
    address   : in  std_logic_vector(15 downto 0); -- Memory address 
    data_out  : out std_logic_vector(15 downto 0)  -- Output instruction
  );
end instruction_memory;

architecture Behavioral of instruction_memory is
  -- ROM definition: 1KB memory (1024 x 16-bit)
  type rom_type is array (0 to 1023) of std_logic_vector(15 downto 0);
  
  -- Preloaded instructions (A0-A3 formats)
  signal rom : rom_type := (
      16#210# => b"0100001001000011",  -- IN r1, 03
      16#211# => b"0100001010000101",  -- IN r2, 05
      16#212# => b"0000000000000000",  -- NOP
      16#213# => b"0000000000000000",  -- NOP
      16#214# => b"0000000000000000",  -- NOP
      16#215# => b"0000000000000000",  -- NOP
      16#216# => b"0000001011010001",  -- ADD r3, r2, r1; r3 = 8
      16#217# => b"0000000000000000",  -- NOP
      16#218# => b"0000000000000000",  -- NOP
      16#219# => b"0000000000000000",  -- NOP
      16#21A# => b"0000000000000000",  -- NOP
      16#21B# => b"0000101011000010",  -- SHL r3, 2; r3 = 32
      16#21C# => b"0000000000000000",  -- NOP
      16#21D# => b"0000000000000000",  -- NOP
      16#21E# => b"0000000000000000",  -- NOP
      16#21F# => b"0000000000000000",  -- NOP
      16#220# => b"0000011010001011",  -- MUL r2, r1, r3; r2 = 3x32 = 96
      16#221# => b"0000000000000000",  -- NOP
      16#222# => b"0000000000000000",  -- NOP
      16#223# => b"0000000000000000",  -- NOP
      16#224# => b"0000000000000000",  -- NOP
      16#225# => b"0100000010000000",  -- OUT r2
      16#226# => b"0000000000000000",  -- NOP
      others => b"0000000000000000"    -- others NOP
  );

begin
  -- Synchronous read operation
  process(clk)
  begin
    if rising_edge(clk) then
      -- Use lower 10 bits of address
      data_out <= rom(to_integer(unsigned(address(15 downto 0))));
    end if;
  end process;
end Behavioral;