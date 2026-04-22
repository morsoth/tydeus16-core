library ieee;
use ieee.std_logic_1164.all;

use work.tydeus16_pkg.all;

entity control_unit is
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;

        ctrl_o  : out ctrl_signals_t;

        fetch_to_decode_i  : in fetch_to_decode_t;
        decode_to_exe_i    : in decode_to_exe_t;
        exe_to_mem_i       : in exe_to_mem_t;
        mem_to_writeback_i : in mem_to_writeback_t
    );
end entity control_unit;

architecture rtl of control_unit is
    signal state_d, state_q : state_t;
begin
    process(clk_i, rst_i)
    begin

    end process;

end architecture rtl;