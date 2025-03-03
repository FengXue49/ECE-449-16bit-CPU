library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ALU is
    generic (
        N : integer := 16  -- Fixed for 16-bit Format A
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        alu_mode : in  std_logic_vector(2 downto 0);
        in1      : in  std_logic_vector(N-1 downto 0);
        in2      : in  std_logic_vector(N-1 downto 0);
        result   : out std_logic_vector(N-1 downto 0);
        z_flag   : out std_logic;
        n_flag   : out std_logic
    );
end ALU;

architecture Behavioral of ALU is
--    signal reg_result : std_logic_vector(N-1 downto 0) := (others => '0');
--    signal reg_z_flag : std_logic := '0';
--    signal reg_n_flag : std_logic := '0';
    constant ZERO_VECT: std_logic_vector(N-1 downto 0) := (others => '0');
begin
--    result <= result;
--    z_flag <= z_flag;
--    n_flag <= reg_n_flag;

    process(clk, rst, alu_mode, in1, in2)
        variable temp_result : std_logic_vector(N-1 downto 0);
        variable mul_result  : std_logic_vector(2*N-1 downto 0);  -- Declared here
    begin
    if rising_edge(clk) then
        if rst = '1' then

            result <= (others => '0');
            z_flag <= '0';
            n_flag <= '0';
            temp_result := (others => '0');
        end if;
--        elsif rising_edge(clk) then
            case alu_mode is
                when "000" =>  -- NOP (No Operation)
                    temp_result := temp_result;  -- Clear output

                when "001" =>  -- ADD
                    temp_result := std_logic_vector(signed(in1) + signed(in2));

                when "010" =>  -- SUB
                    temp_result := std_logic_vector(signed(in1) - signed(in2));

                when "011" =>  -- MUL
                    mul_result := std_logic_vector(signed(in1) * signed(in2));
                    temp_result := mul_result(N-1 downto 0);

                when "100" =>  -- NAND
                    temp_result := std_logic_vector(unsigned(in1) * unsigned(in2));


                when "101" =>  -- SHL (Arithmetic Left Shift)
                    temp_result := std_logic_vector(shift_left(signed(in1), to_integer(unsigned(in2))));

                when "110" =>  -- SHR (Arithmetic Right Shift)
                    temp_result := std_logic_vector(shift_right(signed(in1), to_integer(unsigned(in2))));

                when "111" =>  -- TEST (No operation, preserve flags)
                    temp_result := in1 and in2;
                    if (temp_result = ZERO_VECT) then
                        z_flag <= '1';
                    else
                        z_flag <= '0';
                    end if;
                n_flag <= temp_result(N-1);
                temp_result := temp_result; 

                when others =>
                    temp_result := (others => '0');
            end case;

            -- Update registers only for non-TEST operations
--            if alu_mode /= "111" then
                result <= temp_result;
                
                if (temp_result = ZERO_VECT) then
                    z_flag <= '1';
                else
                    z_flag <= '0';
                
                n_flag <= temp_result(N-1);
                end if;
            end if;

    end process;
end Behavioral;