-- File: hazard_unit.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hazard_unit is
  port (
    -- Pipeline stage signals
    ID_EX_RegWrite : in  std_logic;               -- Register write enable (ID/EX)
    ID_EX_ra       : in  std_logic_vector(2 downto 0); -- Destination register (ID/EX)
    
    EX_MEM_RegWrite : in  std_logic;              -- Register write enable (EX/MEM)
    EX_MEM_ra       : in  std_logic_vector(2 downto 0); -- Destination register (EX/MEM)
    
    -- Source registers from IF/ID stage
    IF_ID_rs1      : in  std_logic_vector(2 downto 0); -- Source register 1
    IF_ID_rs2      : in  std_logic_vector(2 downto 0); -- Source register 2
    
    -- Control outputs
    stall          : out std_logic;               -- Pipeline stall signal
    forward_a      : out std_logic_vector(1 downto 0); -- Forwarding for ALU input A
    forward_b      : out std_logic_vector(1 downto 0)  -- Forwarding for ALU input B
  );
end hazard_unit;

architecture Behavioral of hazard_unit is
begin
  process(ID_EX_RegWrite, ID_EX_ra, EX_MEM_RegWrite, EX_MEM_ra, IF_ID_rs1, IF_ID_rs2)
  begin
    -- Default values: no forwarding/stall
    stall     <= '0';
    forward_a <= "00"; -- 00=no forward, 01=EX forward, 10=MEM forward
    forward_b <= "00";

    --=======================================
    -- Data Hazard Detection (RAW hazards)
    --=======================================
    
    -- Forwarding for ALU input A (rs1 dependency)
    if (ID_EX_RegWrite = '1' and ID_EX_ra = IF_ID_rs1) then
      forward_a <= "01"; -- Forward from EX stage
    elsif (EX_MEM_RegWrite = '1' and EX_MEM_ra = IF_ID_rs1) then
      forward_a <= "10"; -- Forward from MEM stage
    end if;

    -- Forwarding for ALU input B (rs2 dependency)
    if (ID_EX_RegWrite = '1' and ID_EX_ra = IF_ID_rs2) then
      forward_b <= "01"; -- Forward from EX stage
    elsif (EX_MEM_RegWrite = '1' and EX_MEM_ra = IF_ID_rs2) then
      forward_b <= "10"; -- Forward from MEM stage
    end if;

    --=======================================
    -- Load-Use Hazard Detection
    --=======================================
    -- (Example: Insert stall if load instruction followed by dependent operation)
    -- Modify according to actual instruction set
    if (ID_EX_RegWrite = '1' and (ID_EX_ra = IF_ID_rs1 or ID_EX_ra = IF_ID_rs2)) then
      stall <= '1'; -- Insert pipeline bubble
    end if;
  end process;
end Behavioral;