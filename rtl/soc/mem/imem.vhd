library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tydeus16_pkg.all;

entity imem is
    port (
        clk_i   : in  std_logic;

        addr_i  : in  instr_addr_t;
        rdata_o : out instr_t;

        load_addr_i : in instr_addr_t;
        load_data_i : in instr_t;
        load_we_i   : in std_logic
    );
end entity;

architecture rtl of imem is
    type imem_t is array (0 to INSTR_MEM_SIZE-1) of instr_t;

    signal imem : imem_t := (others => (others => '0'));

    attribute ram_style : string;
    attribute ram_style of imem : signal is "block";

begin
    imem_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            rdata_o <= imem(to_integer(unsigned(addr_i)));

            if load_we_i = '1' then
                imem(to_integer(unsigned(load_addr_i))) <= load_data_i;
            end if;
        end if;

    end process;

end architecture rtl;