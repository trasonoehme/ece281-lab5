----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 02:50:18 PM
-- Design Name: 
-- Module Name: ALU - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
 
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
 
entity ALU is
    Port ( i_A : in STD_LOGIC_VECTOR (7 downto 0);
           i_B : in STD_LOGIC_VECTOR (7 downto 0);
           i_op : in STD_LOGIC_VECTOR (2 downto 0);
           o_result : out STD_LOGIC_VECTOR (7 downto 0);
           o_flags : out STD_LOGIC_VECTOR (3 downto 0));  -- N Z C V
end ALU;
 
architecture Behavioral of ALU is
begin
    process (i_A, i_B, i_op)
        variable result : std_logic_vector(7 downto 0);
        variable flags  : std_logic_vector(3 downto 0);  -- N Z C V
        variable temp_sum : unsigned(8 downto 0);  -- 9-bit to catch carry
        variable carry  : std_logic;
    begin
        -- Default outputs
        result := (others => '0');
        flags  := (others => '0');
        carry  := '0';
 
        case i_op is
            when "000" =>  -- ADD: A + B
                temp_sum := unsigned('0' & i_A) + unsigned('0' & i_B);
                result := std_logic_vector(temp_sum(7 downto 0));
                carry := temp_sum(8);
 
                -- Overflow: same sign inputs, different sign result
                if (i_A(7) = i_B(7) and result(7) /= i_A(7)) then
                    flags(0) := '1';  -- V
                end if;
 
            when "001" =>  -- SUB: A - B
                -- Subtract with borrow detection
                temp_sum := unsigned('0' & i_A) - unsigned('0' & i_B);
                result := std_logic_vector(temp_sum(7 downto 0));
                if unsigned(i_A) < unsigned(i_B) then
                    carry := '0';  -- Borrow occurred → no carry
                else
                    carry := '1';  -- No borrow → carry = 1
                end if;
 
                -- Overflow: A and B different sign, result sign differs from A
                if (i_A(7) /= i_B(7) and result(7) /= i_A(7)) then
                    flags(0) := '1';  -- V
                end if;
 
            when "010" =>  -- AND
                result := i_A and i_B;
 
            when "011" =>  -- OR
                result := i_A or i_B;
 
            when others =>
                result := (others => '0');
                flags := (others => '0');
        end case;
 
        -- Set flags
        flags(3) := result(7);                       -- N
        if result = "00000000" then
            flags(2) := '1';                         -- Z
        end if;
        flags(1) := carry;                           -- C
        -- V flag already set in ADD and SUB cases
 
        -- Assign outputs
        o_result <= result;
        o_flags <= flags;
    end process;
end Behavioral;
