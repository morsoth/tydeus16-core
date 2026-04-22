library ieee;
use ieee.std_logic_1164.all;

use work.tydeus16_pkg.all;

entity decoder is
    port (
        instr_i     : in instr_t;
        dec_instr_o : out decoded_instr_t
    );
end entity decoder;

architecture rtl of decoder is
    
begin
    

end architecture rtl;