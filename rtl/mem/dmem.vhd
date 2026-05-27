library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tydeus16_pkg.all;

entity dmem is
    port (
        clk_i   : in  std_logic;

        addr_i  : in  data_addr_t;
        rdata_o : out data_t;
        wdata_i : in data_t;
        we_i    : in std_logic
    );
end entity;

architecture rtl of dmem is
    type dmem_t is array (0 to DATA_MEM_SIZE-1) of data_t;

    signal dmem : dmem_t := (others => (others => '0'));

    attribute ram_style : string;
    attribute ram_style of dmem : signal is "block";

begin
    dmem_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            rdata_o <= dmem(to_integer(unsigned(addr_i)));

            if (we_i = '1') then
                dmem(to_integer(unsigned(addr_i))) <= wdata_i;
            end if;
        end if;
        
    end process;

end architecture rtl;