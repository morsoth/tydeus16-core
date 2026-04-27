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
    -- State register
    state_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_q <= ST_FETCH;
            else
                state_q <= state_d;
            end if;
        end if;

    end process;

    -- Next-state logic
    next_state_p : process(all)
    begin
        state_d <= state_q;

        case state_q is
            when ST_FETCH =>      state_d <= ST_DECODE;
            when ST_DECODE =>     state_d <= ST_EXECUTE;
            when ST_EXECUTE =>    state_d <= ST_MEMORY;
            when ST_MEMORY =>     state_d <= ST_WRITEBACK;
            when ST_WRITEBACK =>  state_d <= ST_FETCH;
            when others =>        state_d <= ST_FETCH;
        end case;
    end process;

    -- Output control
    ctrl_p : process(all)
    begin
        ctrl_o <= CTRL_SIGNALS_RESET;

        case state_q is
            when ST_FETCH =>
                ctrl_o.fetch_to_decode_we <= '1';
                ctrl_o.pc_we              <= '1';
                ctrl_o.pc_sel             <= PC_SEL_PLUS_1;

            when ST_DECODE =>
                ctrl_o.decode_to_exe_we <= '1';
                ctrl_o.alu_op           <= alu_op_from_instr(fetch_to_decode_i.instr);
                ctrl_o.alu_a_sel        <= ALU_A_REGA;
                ctrl_o.alu_b_sel        <= alu_b_sel_from_instr(fetch_to_decode_i.instr);

            when ST_EXECUTE =>
                ctrl_o.exe_to_mem_we <= '1';
                ctrl_o.alu_op        <= decode_to_exe_i.alu_op;
                ctrl_o.alu_a_sel     <= ALU_A_REGA;
                ctrl_o.alu_b_sel     <= alu_b_sel_from_instr(decode_to_exe_i.dec_instr.raw);
                ctrl_o.flags_we      <= writes_flags(decode_to_exe_i.dec_instr.kind);

            when ST_MEMORY =>
                ctrl_o.mem_to_writeback_we <= '1';

            when ST_WRITEBACK =>
                ctrl_o.regfile_we <= writes_reg(mem_to_writeback_i.dec_instr.kind);

            when others => null;

        end case;

    end process;

end architecture rtl;