library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pipelined_cpu is
  port (
    clk: in  std_logic;
    rst: in  std_logic;
    in_port: in  std_logic_vector(15 downto 0);
    out_port: out std_logic_vector(15 downto 0)
  );
end pipelined_cpu;


architecture Behavioral of pipelined_cpu is
  -- Pipeline registers
  ------------------------------------------------------------------------
  -- IF/ID stage
  ------------------------------------------------------------------------
  signal IF_ID_instr: std_logic_vector(15 downto 0):= (others => '0');
  signal IF_ID_pc: std_logic_vector(15 downto 0):= (others => '0');

  ------------------------------------------------------------------------
  -- ID/EX stage
  ------------------------------------------------------------------------

  signal ID_EX_opcode: std_logic_vector(6 downto 0):= (others => '0');
  signal ID_EX_ra: std_logic_vector(2 downto 0):= (others => '0');
  signal ID_EX_rb: std_logic_vector(2 downto 0):= (others => '0');
  signal ID_EX_rc: std_logic_vector(2 downto 0):= (others => '0');

  -- immediate value
  signal ID_EX_c1: std_logic_vector(2 downto 0):= (others => '0');

  signal ID_EX_ALUOp: std_logic_vector(2 downto 0):= (others => '0');
  signal ID_EX_IO_Op: std_logic_vector(1 downto 0):= (others => '0');
  signal ID_EX_RegWrite: std_logic := '0'; -- write to register or not

  ------------------------------------------------------------------------
  -- EX/MEM stage
  ------------------------------------------------------------------------

  signal EX_MEM_alu_result: std_logic_vector(15 downto 0):= (others => '0'); -- the 16-bit ALU result
  signal EX_MEM_io_data: std_logic_vector(15 downto 0):= (others => '0'); -- data for I/O operation
  signal EX_MEM_ra: std_logic_vector(2 downto 0):= (others => '0'); -- target register ra
  signal EX_MEM_RegWrite: std_logic := '0'; -- write to register or not
  signal EX_MEM_IO_Op: std_logic_vector(1 downto 0):= (others => '0'); -- Input or output signal

  ------------------------------------------------------------------------
  -- MEM/WB stage
  ------------------------------------------------------------------------

  signal MEM_WB_result: std_logic_vector(15 downto 0):= (others => '0'); -- the 16-bit data that needed to be written back to register
  signal MEM_WB_ra: std_logic_vector(2 downto 0):= (others => '0'); -- final target register address
  signal MEM_WB_RegWrite: std_logic:= '0'; -- write to register or not
  signal MEM_WB_IO_Op: std_logic_vector(1 downto 0):= (others => '0'); -- Input or output signal

  ------------------------------------------------------------------------
  -- register file component -- separate file
  ------------------------------------------------------------------------

  component register_file
    port (
      clk: in  std_logic;
      rst: in  std_logic;
      rd_index1: in  std_logic_vector(2 downto 0);
      rd_index2: in  std_logic_vector(2 downto 0);
      rd_data1: out std_logic_vector(15 downto 0);
      rd_data2: out std_logic_vector(15 downto 0);
      wr_index: in  std_logic_vector(2 downto 0);
      wr_data: in  std_logic_vector(15 downto 0);
      wr_enable: in  std_logic
    );
  end component;

  ------------------------------------------------------------------------
  -- ALU component -- separate file
  ------------------------------------------------------------------------

  component alu
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      in1: in  std_logic_vector(15 downto 0);
      in2: in  std_logic_vector(15 downto 0);
      alu_mode: in  std_logic_vector(2 downto 0);
      result: out std_logic_vector(15 downto 0);
      z_flag: out std_logic;
      n_flag: out std_logic
    );
  end component;

  ------------------------------------------------------------------------
  -- Instruction memory component
  ------------------------------------------------------------------------

  component instruction_memory
    port (
      clk: in  std_logic;
      address: in  std_logic_vector(15 downto 0);
      data_out: out std_logic_vector(15 downto 0)
    );
  end component;

  ------------------------------------------------------------------------
  -- Hazard unit component -- separate file
  ------------------------------------------------------------------------

  component hazard_unit
    port (
      ID_EX_RegWrite: in  std_logic;
      ID_EX_ra: in  std_logic_vector(2 downto 0);
      EX_MEM_RegWrite: in  std_logic;
      EX_MEM_ra: in  std_logic_vector(2 downto 0);
      IF_ID_rs1: in  std_logic_vector(2 downto 0);
      IF_ID_rs2: in  std_logic_vector(2 downto 0);
      stall: out std_logic;
      forward_a: out std_logic_vector(1 downto 0);
      forward_b: out std_logic_vector(1 downto 0)
    );
  end component;

  ------------------------------------------------------------------------
  -- Internal signals
  ------------------------------------------------------------------------

  signal pc: std_logic_vector(15 downto 0) := (others => '0');
  signal instruction: std_logic_vector(15 downto 0);
  signal stall: std_logic;
  signal forward_a: std_logic_vector(1 downto 0);
  signal forward_b: std_logic_vector(1 downto 0);
  signal alu_in1: std_logic_vector(15 downto 0);
  signal alu_in2: std_logic_vector(15 downto 0);
  signal alu_result: std_logic_vector(15 downto 0);
  signal reg_data1: std_logic_vector(15 downto 0);
  signal reg_data2: std_logic_vector(15 downto 0);
  signal control_RegWrite : std_logic := '0';
  signal control_ALUOp    : std_logic_vector(2 downto 0) := (others => '0');
  signal control_IO_Op    : std_logic_vector(1 downto 0) := (others => '0');

  ------------------------------------------------------------------------
  -- Instruction extraction
  ------------------------------------------------------------------------

  signal opcode: std_logic_vector(6 downto 0);
  signal ra: std_logic_vector(2 downto 0);
  signal rb: std_logic_vector(2 downto 0);
  signal rc: std_logic_vector(2 downto 0);
  signal c1: std_logic_vector(2 downto 0);
  signal is_A0: boolean;
  signal is_A1: boolean;
  signal is_A2: boolean;
  signal is_A3: boolean;

  ------------------------------------------------------------------------
  ------------------------------------------------------------------------

begin
  -- Store instruction address into IF_ID register
  IMEM: instruction_memory
  port map (
    clk => clk,
    address => pc,
    data_out => instruction
  );

  HAZARD: hazard_unit
  port map (
    ID_EX_RegWrite => ID_EX_RegWrite,
    ID_EX_ra => ID_EX_ra,
    EX_MEM_RegWrite => EX_MEM_RegWrite,
    EX_MEM_ra => EX_MEM_ra,
    IF_ID_rs1 => IF_ID_instr(8 downto 6),
    IF_ID_rs2  => IF_ID_instr(5 downto 3),
    stall => stall,
    forward_a  => forward_a,
    forward_b => forward_b
  );

  RF: register_file
  port map (
    clk => clk,
    rst => rst,
    rd_index1 => ID_EX_ra,
    rd_index2 => ID_EX_rb,
    wr_index => MEM_WB_ra,
    wr_data => MEM_WB_result,
    wr_enable => MEM_WB_RegWrite,
    rd_data1 => reg_data1,
    rd_data2 => reg_data2
  );

  ALU_UNIT: alu
  port map (
    clk      => clk,
    rst      => rst, 
    in1 => alu_in1,
    in2 => alu_in2,
    alu_mode => ID_EX_ALUOp,
    result => alu_result,
    z_flag   => open,
    n_flag   => open  
  );

  ------------------------------------------------------------------------
  -- Instruction decode
  ------------------------------------------------------------------------

  opcode <= IF_ID_instr(15 downto 9);
  ra <= IF_ID_instr(8 downto 6);
  rb <= IF_ID_instr(5 downto 3);
  rc <= IF_ID_instr(2 downto 0);
  c1 <= IF_ID_instr(2 downto 0);
  
  is_A0 <= (opcode = "0000000");
  is_A1 <= (unsigned(opcode) >= 1 and unsigned(opcode) <= 4);
  is_A2 <= (unsigned(opcode) >= 5 and unsigned(opcode) <= 6);
  is_A3 <= (opcode = "0000111" or opcode = "0100000" or opcode = "0100001");

  ------------------------------------------------------------------------
  -- Control logic
  ------------------------------------------------------------------------

  process(opcode)
  begin
--    ID_EX_ALUOp <= "000";
--    ID_EX_IO_Op <= "00";
--    ID_EX_RegWrite <= '0';
    control_ALUOp <= "000";
    control_IO_Op <= "00";
    control_RegWrite <= '0';
  -- ALU opcode
    case opcode is
      when "0000000" => null; -- NOP
      when "0000001" => control_ALUOp <= "001"; -- 1 ADD -- ID_EX_ALUOp
      when "0000010" => control_ALUOp <= "010"; -- 2 SUB
      when "0000011" => control_ALUOp <= "011"; -- 3 MUL
      when "0000100" => control_ALUOp <= "100"; -- 4 NAND
      when "0000101" => control_ALUOp <= "101"; -- 5 SHL
      when "0000110" => control_ALUOp <= "110"; -- 6 SHR
      when "0000111" => control_ALUOp <= "111"; -- 7 TEST
      when "0100000" => control_IO_Op <= "10"; -- 32 OUT
      when "0100001" => control_IO_Op <= "11"; -- 33 IN
      when others    => null;
    end case;

    if is_A1 or is_A2 or (is_A3 and opcode = "0100001") then
      control_RegWrite <= '1';
    end if;
  end process;

------------------------------------------------------------------------
-- Forwarding muxes
------------------------------------------------------------------------

  process(forward_a, forward_b, reg_data1, reg_data2, EX_MEM_alu_result, MEM_WB_result)
  begin
    case forward_a is
      when "01" => alu_in1 <= EX_MEM_alu_result;
      when "10" => alu_in1 <= MEM_WB_result;
      when others => alu_in1 <= reg_data1;
    end case;

    case forward_b is
      when "01" => alu_in2 <= EX_MEM_alu_result;
      when "10" => alu_in2 <= MEM_WB_result;
      when others => 
        if is_A2 then
          alu_in2 <= std_logic_vector(resize(unsigned(c1), 16));
        else
          alu_in2 <= reg_data2;
        end if;
    end case;
  end process;

------------------------------------------------------------------------
-- Pipeline registers
------------------------------------------------------------------------

  process(clk, rst)
  begin
    if rst = '1' then
      pc <= (others => '0');
      IF_ID_instr <= (others => '0');
      ID_EX_opcode <= (others => '0');
      ID_EX_ra <= (others => '0');
      ID_EX_rb <= (others => '0');
      ID_EX_rc <= (others => '0');
      ID_EX_c1 <= (others => '0');
      ID_EX_RegWrite <= '0';
      ID_EX_ALUOp <= (others => '0');
      ID_EX_IO_Op <= (others => '0');
    elsif rising_edge(clk) then
      -- PC update
      if stall = '0' then
          pc <= std_logic_vector(unsigned(pc) + 2);-------------------------------------
          IF_ID_pc <= std_logic_vector(unsigned(pc) + 2);
          IF_ID_instr <= instruction;
      end if;

------------------------------------------------------------------------
-- ID/EX stage
------------------------------------------------------------------------

      if stall = '0' then
        ID_EX_ra <= ra;
        ID_EX_rb <= rb;
        ID_EX_rc <= rc;
        ID_EX_c1 <= c1;
        ID_EX_opcode <= opcode;
        ID_EX_RegWrite <= control_RegWrite;
        ID_EX_ALUOp <= control_ALUOp;
         ID_EX_IO_Op <=control_IO_Op;      
--        ID_EX_RegWrite <= ID_EX_RegWrite;
--        ID_EX_ALUOp <= ID_EX_ALUOp;
--        ID_EX_IO_Op <= ID_EX_IO_Op;
      else
        ID_EX_RegWrite <= '0';
        ID_EX_ALUOp <= (others => '0');
        ID_EX_IO_Op <= (others => '0');
      end if;

------------------------------------------------------------------------
-- EX/MEM stage
------------------------------------------------------------------------

      EX_MEM_alu_result <= alu_result;
      EX_MEM_ra <= ID_EX_ra;
      EX_MEM_RegWrite <= ID_EX_RegWrite;
      EX_MEM_IO_Op <= ID_EX_IO_Op;

------------------------------------------------------------------------
-- MEM/WB stage
------------------------------------------------------------------------

      MEM_WB_result <= EX_MEM_alu_result;
      MEM_WB_ra <= EX_MEM_ra;
      MEM_WB_RegWrite <= EX_MEM_RegWrite;
      MEM_WB_IO_Op <= EX_MEM_IO_Op;
    end if;
  end process;

------------------------------------------------------------------------
-- I/O handling
------------------------------------------------------------------------

  out_port <= EX_MEM_io_data when (EX_MEM_IO_Op = "10") else (others => '0');
    
  process(clk)
  begin
    if rising_edge(clk) then
      if EX_MEM_IO_Op = "11" then
        EX_MEM_io_data <= in_port;
      else
        EX_MEM_io_data <= alu_result;
      end if;
    end if;
  end process;

------------------------------------------------------------------------
-- Write-back stage
------------------------------------------------------------------------
    process(clk)
    begin
      if rising_edge(clk) then
        if MEM_WB_RegWrite = '1' then
          if MEM_WB_IO_Op = "11" then
             MEM_WB_result <= EX_MEM_io_data;
          else
             MEM_WB_result <= EX_MEM_alu_result;
          end if;
        end if;
      end if;
    end process;
  
--  process(MEM_WB_RegWrite, MEM_WB_IO_Op, EX_MEM_io_data, MEM_WB_result)
--  begin
--    if MEM_WB_RegWrite = '1' then
--      if MEM_WB_IO_Op = "11" then
--        MEM_WB_result <= EX_MEM_io_data;
--      else
--        MEM_WB_result <= MEM_WB_result;
--      end if;
--    end if;
--  end process;

end Behavioral;