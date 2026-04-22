library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tydeus16_pkg.all;

entity regfile is
    port (
        clk_i     : in  std_logic;
        rst_i     : in  std_logic;

        -- Read
        raddr_a_i : in  reg_idx_t;
        raddr_b_i : in  reg_idx_t;

        rdata_a_o : out data_t;
        rdata_b_o : out data_t;

        -- Write
        waddr_d_i : in  reg_idx_t;
        wdata_d_i : in  data_t;
        we_i      : in  std_logic
    );
end entity regfile;

architecture rtl of regfile is
    -- Regfile array (R0 .. R7)
    type regfile_array_t is array (0 to REG_COUNT-1) of data_t;
    signal regs : regfile_array_t := (others => (others => '0'));

begin
    -- RegA readings
    rdata_a_o <= (others => '0') when unsigned(raddr_a_i) = 0
                else regs(to_integer(unsigned(raddr_a_i)));

    -- RegB readings
    rdata_b_o <= (others => '0') when unsigned(raddr_b_i) = 0
                else regs(to_integer(unsigned(raddr_b_i)));

    process(clk_i, rst_i)
    begin
        if rising_edge(clk_i) then
            -- Reset
            if rst_i = '1' then
                for i in 0 to REG_COUNT-1 loop
                    regs(i) <= (others => '0');
                end loop;

            -- RegD writtings
            elsif we_i = '1' then
                if unsigned(waddr_d_i) /= 0 then
                    regs(to_integer(unsigned(waddr_d_i))) <= wdata_d_i;
                end if;
            end if;

        end if;

    end process;

end architecture rtl;