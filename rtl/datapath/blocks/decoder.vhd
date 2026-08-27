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
    decode_p : process (all)
        variable dec_instr : decoded_instr_t;
        
    begin
        dec_instr     := DECODED_INSTR_RESET;
        dec_instr.raw := instr_i;

        dec_instr.opcode := instr_i(INSTR_WIDTH-1 downto 11);
        dec_instr.func   := instr_i(1 downto 0);

        case dec_instr.opcode is
            when OP_NOP =>
                dec_instr.kind   := IK_NOP;
                dec_instr.format := FMT_NOOP;

            when OP_ARITM =>
                case dec_instr.func is
                    when FUNC_MOV =>
                        dec_instr.kind   := IK_MOV;
                        dec_instr.format := FMT_RR;

                    when FUNC_ADD =>
                        dec_instr.kind   := IK_ADD;
                        dec_instr.format := FMT_RRR;

                    when FUNC_SUB =>
                        dec_instr.kind   := IK_SUB;
                        dec_instr.format := FMT_RRR;

                    when FUNC_CMP =>
                        dec_instr.kind   := IK_CMP;
                        dec_instr.format := FMT_RR;

                    when others =>
                        dec_instr.kind   := IK_INVALID;
                        dec_instr.format := FMT_UNKNOWN;

                end case;

            when OP_LOGIC =>
                case dec_instr.func is
                    when FUNC_AND =>
                        dec_instr.kind   := IK_AND;
                        dec_instr.format := FMT_RRR;

                    when FUNC_OR =>
                        dec_instr.kind   := IK_OR;
                        dec_instr.format := FMT_RRR;

                    when FUNC_XOR =>
                        dec_instr.kind   := IK_XOR;
                        dec_instr.format := FMT_RRR;

                    when FUNC_NOT =>
                        dec_instr.kind   := IK_NOT;
                        dec_instr.format := FMT_RR;

                    when others =>
                        dec_instr.kind   := IK_INVALID;
                        dec_instr.format := FMT_UNKNOWN;
                        
                end case;

            when OP_LI =>
                dec_instr.kind   := IK_LI;
                dec_instr.format := FMT_RI;

            when OP_LIH =>
                dec_instr.kind   := IK_LIH;
                dec_instr.format := FMT_RI;

            when OP_SLL =>
                dec_instr.kind   := IK_SLL;
                dec_instr.format := FMT_RRI;

            when OP_SRL =>
                dec_instr.kind   := IK_SRL;
                dec_instr.format := FMT_RRI;

            when OP_SRA =>
                dec_instr.kind   := IK_SRA;
                dec_instr.format := FMT_RRI;

            when OP_JMP =>
                dec_instr.kind   := IK_JMP;
                dec_instr.format := FMT_JUMP;

            when OP_BEQ =>
                dec_instr.kind   := IK_BEQ;
                dec_instr.format := FMT_BRANCH;

            when OP_BNE =>
                dec_instr.kind   := IK_BNE;
                dec_instr.format := FMT_BRANCH;

            when OP_BLT =>
                dec_instr.kind   := IK_BLT;
                dec_instr.format := FMT_BRANCH;

            when OP_BGT =>
                dec_instr.kind   := IK_BGT;
                dec_instr.format := FMT_BRANCH;

            when OP_BLE =>
                dec_instr.kind   := IK_BLE;
                dec_instr.format := FMT_BRANCH;

            when OP_BGE =>
                dec_instr.kind   := IK_BGE;
                dec_instr.format := FMT_BRANCH;

            when OP_CALL =>
                dec_instr.kind   := IK_CALL;
                dec_instr.format := FMT_JUMP;

            when OP_RET =>
                dec_instr.kind   := IK_RET;
                dec_instr.format := FMT_NOOP;

            when OP_LOAD =>
                dec_instr.kind   := IK_LOAD;
                dec_instr.format := FMT_LOAD;

            when OP_STORE =>
                dec_instr.kind   := IK_STORE;
                dec_instr.format := FMT_STORE;

            when OP_ADDI =>
                dec_instr.kind   := IK_ADDI;
                dec_instr.format := FMT_RI;

            when OP_SUBI =>
                dec_instr.kind   := IK_SUBI;
                dec_instr.format := FMT_RI;

            when OP_CMPI =>
                dec_instr.kind   := IK_CMPI;
                dec_instr.format := FMT_RI;

            when others =>
                dec_instr.kind   := IK_INVALID;
                dec_instr.format := FMT_UNKNOWN;

        end case;

        case dec_instr.format is
            when FMT_NOOP =>
                null;

            when FMT_RRR =>
                dec_instr.dest  := instr_i(10 downto 8);
                dec_instr.src_a := instr_i(7 downto 5);
                dec_instr.src_b := instr_i(4 downto 2);

            when FMT_RR =>
                dec_instr.dest  := instr_i(10 downto 8);
                dec_instr.src_a := instr_i(10 downto 8);
                dec_instr.src_b := instr_i(7 downto 5);

            when FMT_RI =>
                dec_instr.dest  := instr_i(10 downto 8);
                dec_instr.src_a := instr_i(10 downto 8);
                dec_instr.imm8  := instr_i(7 downto 0);

            when FMT_RRI =>
                dec_instr.dest  := instr_i(10 downto 8);
                dec_instr.src_a := instr_i(7 downto 5);
                dec_instr.imm4  := instr_i(3 downto 0);

            when FMT_JUMP =>
                dec_instr.addr11 := instr_i(10 downto 0);

            when FMT_BRANCH =>
                dec_instr.off11 := instr_i(10 downto 0);

            when FMT_LOAD =>
                dec_instr.dest  := instr_i(10 downto 8);
                dec_instr.src_a := instr_i(7 downto 5);
                dec_instr.off5  := instr_i(4 downto 0);

            when FMT_STORE =>
                dec_instr.src_b := instr_i(10 downto 8);
                dec_instr.src_a := instr_i(7 downto 5);
                dec_instr.off5  := instr_i(4 downto 0);

            when others =>
                null;

        end case;

        dec_instr_o <= dec_instr;

    end process;

end architecture rtl;
