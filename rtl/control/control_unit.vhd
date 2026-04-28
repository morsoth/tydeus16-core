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
        mem_to_writeback_i : in mem_to_writeback_t;

        dec_instr_i        : in decoded_instr_t;
        flags_i            : in flags_t
    );
end entity control_unit;

architecture rtl of control_unit is
    signal state_d, state_q : state_t;

    function branch_taken(kind : instr_kind_t; flags : flags_t) return std_logic is
        variable z : std_logic;
        variable n : std_logic;
        variable v : std_logic;
    begin
        z := flags(FLAG_Z);
        n := flags(FLAG_N);
        v := flags(FLAG_V);

        case kind is
            when IK_BEQ => return z;
            when IK_BNE => return not z;
            when IK_BLT => return n xor v;
            when IK_BGT => return (not z) and (not (n xor v));
            when IK_BLE => return z or (n xor v);
            when IK_BGE => return not (n xor v);
            when others => return '0';
        end case;
    end function;

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
            when ST_FETCH =>
                state_d <= ST_DECODE;

            when ST_DECODE =>
                case dec_instr_i.kind is
                    when IK_NOP =>
                        state_d <= ST_FETCH;

                    when IK_JMP =>
                        state_d <= ST_FETCH;
                        
                    when others =>
                        state_d <= ST_EXECUTE;
                end case;

            when ST_EXECUTE =>
                case decode_to_exe_i.dec_instr.kind is
                    when IK_CMP | IK_CMPI =>
                        state_d <= ST_FETCH;

                    when IK_BEQ | IK_BNE | IK_BLT | IK_BGT | IK_BLE | IK_BGE =>
                        state_d <= ST_FETCH;

                    when IK_LOAD | IK_STORE | IK_CALL | IK_RET =>
                        state_d <= ST_MEMORY;

                    when others =>
                        state_d <= ST_WRITEBACK;
                end case;

            when ST_MEMORY =>
                case exe_to_mem_i.dec_instr.kind is
                    when IK_STORE | IK_CALL | IK_RET =>
                        state_d <= ST_FETCH;

                    when others =>
                        state_d <= ST_WRITEBACK;
                end case;

            when ST_WRITEBACK =>
                state_d <= ST_FETCH;

            when others =>
                state_d <= ST_FETCH;

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

                case dec_instr_i.kind is
                    -- NOP
                    when IK_NOP =>
                        ctrl_o.decode_to_exe_we <= '0';

                    -- JMP
                    when IK_JMP =>
                        ctrl_o.decode_to_exe_we <= '0';

                        ctrl_o.pc_we  <= '1';
                        ctrl_o.pc_sel <= PC_SEL_JMP_ADDR;

                    when others => null;
                end case;

            when ST_EXECUTE =>
                ctrl_o.exe_to_mem_we <= '1';

                ctrl_o.alu_op           <= ALU_NOP;
                ctrl_o.alu_a_sel        <= ALU_A_REGA;
                ctrl_o.alu_b_sel        <= ALU_B_REGB;
                ctrl_o.flags_we         <= '0';

                case decode_to_exe_i.dec_instr.kind is
                    -- Arithmetic
                    when IK_MOV =>
                        ctrl_o.alu_op   <= ALU_PASS_B;

                    when IK_ADD =>
                        ctrl_o.alu_op   <= ALU_ADD;
                        ctrl_o.flags_we <= '1';

                    when IK_SUB =>
                        ctrl_o.alu_op   <= ALU_SUB;
                        ctrl_o.flags_we <= '1';

                    when IK_CMP =>
                        ctrl_o.exe_to_mem_we <= '0';

                        ctrl_o.alu_op   <= ALU_SUB;
                        ctrl_o.flags_we <= '1';

                    -- Arithmetic with immediates
                    when IK_ADDI =>
                        ctrl_o.alu_op    <= ALU_ADD;
                        ctrl_o.alu_b_sel <= ALU_B_IMM8_ZEXT;
                        ctrl_o.flags_we  <= '1';

                    when IK_SUBI =>
                        ctrl_o.alu_op    <= ALU_SUB;
                        ctrl_o.alu_b_sel <= ALU_B_IMM8_ZEXT;
                        ctrl_o.flags_we  <= '1';
                        
                    when IK_CMPI =>
                        ctrl_o.exe_to_mem_we <= '0';

                        ctrl_o.alu_op    <= ALU_SUB;
                        ctrl_o.alu_b_sel <= ALU_B_IMM8_ZEXT;
                        ctrl_o.flags_we  <= '1';

                    -- Logic
                    when IK_AND =>
                        ctrl_o.alu_op  <= ALU_AND;
                        ctrl_o.flags_we <= '1';

                    when IK_OR =>
                        ctrl_o.alu_op  <= ALU_OR;
                        ctrl_o.flags_we <= '1';

                    when IK_XOR =>
                        ctrl_o.alu_op  <= ALU_XOR;
                        ctrl_o.flags_we <= '1';

                    when IK_NOT =>
                        ctrl_o.alu_op  <= ALU_NOT;
                        ctrl_o.flags_we <= '1';

                    -- Shifts
                    when IK_SLL =>
                        ctrl_o.alu_op    <= ALU_SLL;
                        ctrl_o.alu_b_sel <= ALU_B_IMM4_ZEXT;
                        ctrl_o.flags_we  <= '1';

                    when IK_SRL =>
                        ctrl_o.alu_op    <= ALU_SRL;
                        ctrl_o.alu_b_sel <= ALU_B_IMM4_ZEXT;
                        ctrl_o.flags_we  <= '1';

                    when IK_SRA =>
                        ctrl_o.alu_op    <= ALU_SRA;
                        ctrl_o.alu_b_sel <= ALU_B_IMM4_ZEXT;
                        ctrl_o.flags_we  <= '1';

                    -- Branchs
                    when IK_BEQ | IK_BNE | IK_BLT | IK_BGT | IK_BLE | IK_BGE =>
                        ctrl_o.exe_to_mem_we <= '0';

                        ctrl_o.alu_op    <= ALU_ADD;
                        ctrl_o.alu_a_sel <= ALU_A_PC_PLUS_1;
                        ctrl_o.alu_b_sel <= ALU_B_OFF11_SEXT;
                        
                        if branch_taken(decode_to_exe_i.dec_instr.kind, flags_i) = '1' then
                            ctrl_o.pc_we  <= '1';
                            ctrl_o.pc_sel <= PC_SEL_B_ADDR;
                        end if;

                    -- CALL
                    when IK_CALL =>
                        ctrl_o.alu_op    <= ALU_SUB;
                        ctrl_o.alu_a_sel <= ALU_A_SP;
                        ctrl_o.alu_b_sel <= ALU_B_CONST_1;

                        ctrl_o.sp_we  <= '1';
                        ctrl_o.sp_sel <= SP_SEL_EXE_ADDR;

                    -- RET
                    when IK_RET =>
                        ctrl_o.alu_op    <= ALU_ADD;
                        ctrl_o.alu_a_sel <= ALU_A_SP;
                        ctrl_o.alu_b_sel <= ALU_B_CONST_1;

                        ctrl_o.sp_we  <= '1';
                        ctrl_o.sp_sel <= SP_SEL_EXE_ADDR;

                    -- Memory
                    when IK_LOAD | IK_STORE =>
                        ctrl_o.alu_op    <= ALU_ADD;
                        ctrl_o.alu_a_sel <= ALU_A_REGA;
                        ctrl_o.alu_b_sel <= ALU_B_OFF5_SEXT;

                    when others => null;
                end case;

            when ST_MEMORY =>
                ctrl_o.mem_to_writeback_we <= '1';

                case exe_to_mem_i.dec_instr.kind is
                    when IK_CALL =>
                        ctrl_o.mem_to_writeback_we <= '0';

                        ctrl_o.dmem_wdata_sel <= DMEM_WDATA_PC;
                        ctrl_o.dmem_we        <= '1';

                        ctrl_o.pc_we  <= '1';
                        ctrl_o.pc_sel <= PC_SEL_CALL_ADDR;

                    when IK_RET =>
                        ctrl_o.mem_to_writeback_we <= '0';

                        ctrl_o.dmem_wdata_sel <= DMEM_WDATA_PC;
                        ctrl_o.dmem_we        <= '0';

                        ctrl_o.pc_we  <= '1';
                        ctrl_o.pc_sel <= PC_SEL_RET_ADDR;

                    when IK_LOAD =>
                        ctrl_o.dmem_wdata_sel <= DMEM_WDATA_REGB;
                        ctrl_o.dmem_we        <= '0';

                    when IK_STORE =>
                        ctrl_o.mem_to_writeback_we <= '0';

                        ctrl_o.dmem_wdata_sel <= DMEM_WDATA_REGB;
                        ctrl_o.dmem_we        <= '1';

                    when others => null;
                end case;

            when ST_WRITEBACK =>
                ctrl_o.regfile_we <= '0';

                case mem_to_writeback_i.dec_instr.kind is
                    when IK_MOV | IK_ADD | IK_SUB | IK_ADDI | IK_SUBI |
                         IK_AND | IK_OR  | IK_XOR | IK_NOT |
                         IK_LI  | IK_LIH | IK_SLL | IK_SRL | IK_SRA =>
                        ctrl_o.regfile_we <= '1';
                        ctrl_o.wb_sel     <= WB_SEL_EXE;

                    when IK_LOAD =>
                        ctrl_o.regfile_we <= '1';
                        ctrl_o.wb_sel     <= WB_SEL_MEM;

                    when others => null;
                end case;

            when others => null;

        end case;

    end process;

end architecture rtl;