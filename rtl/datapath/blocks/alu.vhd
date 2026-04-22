library ieee;
use ieee.std_logic_1164.all;

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
    

end architecture rtl;