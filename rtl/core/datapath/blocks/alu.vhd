library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tydeus16_pkg.all;

entity alu is
    port (
        a_i      : in data_t;
        b_i      : in data_t;
        result_o : out data_t;

        op_i     : in alu_op_t;

        flags_o  : out flags_t
    );
end entity alu;

architecture rtl of alu is
    
begin
    op_p : process (all)
        variable tmp_v : unsigned(DATA_WIDTH downto 0);
        variable res_v : data_t;
        variable flags_v : flags_t;

    begin
        res_v   := (others => '0');
        flags_v := (others => '0');

        case op_i is
            when ALU_ADD =>
                tmp_v := ('0' & unsigned(a_i)) + ('0' & unsigned(b_i));
                res_v := std_logic_vector(tmp_v(DATA_WIDTH-1 downto 0));

                -- C flag
                flags_v(FLAG_C) := tmp_v(DATA_WIDTH);

                -- V flag
                flags_v(FLAG_V) :=
                    (a_i(DATA_WIDTH-1) and b_i(DATA_WIDTH-1) and not res_v(DATA_WIDTH-1)) or
                    ((not a_i(DATA_WIDTH-1)) and (not b_i(DATA_WIDTH-1)) and res_v(DATA_WIDTH-1));
                            
            when ALU_SUB =>
                tmp_v := ('0' & unsigned(a_i)) - ('0' & unsigned(b_i));
                res_v := std_logic_vector(tmp_v(DATA_WIDTH-1 downto 0));

                -- C flag
                flags_v(FLAG_C) := not tmp_v(DATA_WIDTH);
                
                -- V flag
                flags_v(FLAG_V) :=
                    (a_i(DATA_WIDTH-1) xor b_i(DATA_WIDTH-1)) and
                    (a_i(DATA_WIDTH-1) xor res_v(DATA_WIDTH-1));

            when ALU_AND =>
                res_v := a_i and b_i;

            when ALU_OR =>
                res_v := a_i or b_i;

            when ALU_XOR =>
                res_v := a_i xor b_i;

            when ALU_NOT =>
                res_v := not b_i;

            when ALU_SLL =>
                res_v := std_logic_vector(shift_left(unsigned(a_i), to_integer(unsigned(b_i))));

            when ALU_SRL =>
                res_v := std_logic_vector(shift_right(unsigned(a_i), to_integer(unsigned(b_i))));

            when ALU_SRA =>
                res_v := std_logic_vector(shift_right(signed(a_i), to_integer(unsigned(b_i))));

            when ALU_PASS_B =>
                res_v := b_i;

            when others =>
                null;
        end case;

        -- Z flag
        if unsigned(res_v) = 0 then
            flags_v(FLAG_Z) := '1';
        end if;

        -- N flag
        flags_v(FLAG_N) := res_v(DATA_WIDTH-1);

        result_o <= res_v;
        flags_o <= flags_v;

    end process;

end architecture rtl;