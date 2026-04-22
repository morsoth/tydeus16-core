library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tydeus16_pkg is
    -- Global widths and sizes
    constant DATA_WIDTH       : natural := 16;
    constant INSTR_WIDTH      : natural := 16;

    constant INSTR_ADDR_WIDTH : natural := 11;
    constant DATA_ADDR_WIDTH  : natural := 16;

    constant REG_COUNT        : natural := 8;
    constant REG_IDX_WIDTH    : natural := 3;

    constant FLAGS_WIDTH      : natural := 4;

    constant INSTR_MEM_SIZE   : natural := 2048;
    constant DATA_MEM_SIZE    : natural := 65536;

    constant IMM8_WIDTH       : natural := 8;
    constant IMM4_WIDTH       : natural := 4;
    constant OFF5_WIDTH       : natural := 5;
    constant OFF11_WIDTH      : natural := 11;

    constant OPCODE_WIDTH     : natural := 5;
    constant FUNC_WIDTH       : natural := 2;

    -- Common subtypes
    subtype data_t       is std_logic_vector(DATA_WIDTH-1 downto 0);
    subtype instr_t      is std_logic_vector(INSTR_WIDTH-1 downto 0);

    subtype instr_addr_t is std_logic_vector(INSTR_ADDR_WIDTH-1 downto 0);
    subtype data_addr_t  is std_logic_vector(DATA_ADDR_WIDTH-1 downto 0);

    subtype reg_idx_t    is std_logic_vector(REG_IDX_WIDTH-1 downto 0);

    subtype imm8_t       is std_logic_vector(IMM8_WIDTH-1 downto 0);
    subtype imm4_t       is std_logic_vector(IMM4_WIDTH-1 downto 0);
    subtype off5_t       is std_logic_vector(OFF5_WIDTH-1 downto 0);
    subtype off11_t      is std_logic_vector(OFF11_WIDTH-1 downto 0);

    subtype opcode_t     is std_logic_vector(OPCODE_WIDTH-1 downto 0);
    subtype func_t       is std_logic_vector(FUNC_WIDTH-1 downto 0);

    subtype flags_t      is std_logic_vector(FLAGS_WIDTH-1 downto 0);

    -- Flags indices
    constant FLAG_Z : natural := 0;
    constant FLAG_C : natural := 1;
    constant FLAG_N : natural := 2;
    constant FLAG_V : natural := 3;

    -- Opcodes
    constant OP_NOP   : opcode_t := "00000";
    constant OP_ARITM : opcode_t := "00001";
    constant OP_LOGIC : opcode_t := "00010";
    constant OP_LI    : opcode_t := "00011";
    constant OP_LIH   : opcode_t := "00100";
    constant OP_SLL   : opcode_t := "00101";
    constant OP_SRL   : opcode_t := "00110";
    constant OP_SRA   : opcode_t := "00111";
    constant OP_JMP   : opcode_t := "01000";
    constant OP_BEQ   : opcode_t := "01001";
    constant OP_BNE   : opcode_t := "01010";
    constant OP_BLT   : opcode_t := "01011";
    constant OP_BGT   : opcode_t := "01100";
    constant OP_BLE   : opcode_t := "01101";
    constant OP_BGE   : opcode_t := "01110";
    constant OP_CALL  : opcode_t := "01111";
    constant OP_RET   : opcode_t := "10000";
    constant OP_LOAD  : opcode_t := "10010";
    constant OP_STORE : opcode_t := "10011";
    constant OP_ADDI  : opcode_t := "10100";
    constant OP_SUBI  : opcode_t := "10101";
    constant OP_CMPI  : opcode_t := "10110";

    -- Function fields
    constant FUNC_MOV : func_t := "00";
    constant FUNC_ADD : func_t := "01";
    constant FUNC_SUB : func_t := "10";
    constant FUNC_CMP : func_t := "11";

    constant FUNC_AND : func_t := "00";
    constant FUNC_OR  : func_t := "01";
    constant FUNC_XOR : func_t := "10";
    constant FUNC_NOT : func_t := "11";

    -- Instruction format kind
    type instr_format_t is (
        NOOP_TYPE,
        RRR_TYPE,
        RR_TYPE,
        RI_TYPE,
        RRI_TYPE,
        JUMP_TYPE,
        BRANCH_TYPE,
        LOAD_TYPE,
        STORE_TYPE,
        UNKNOWN_TYPE
    );

    -- Instruction semantic kind
    type instr_kind_t is (
        IK_NOP,
        IK_MOV, IK_ADD, IK_SUB, IK_CMP,
        IK_AND, IK_OR, IK_XOR, IK_NOT,
        IK_LI, IK_LIH,
        IK_SLL, IK_SRL, IK_SRA,
        IK_JMP,
        IK_BEQ, IK_BNE, IK_BLT, IK_BGT, IK_BLE, IK_BGE,
        IK_CALL, IK_RET,
        IK_LOAD, IK_STORE,
        IK_ADDI, IK_SUBI, IK_CMPI,
        IK_INVALID
    );

    -- ALU operations
    type alu_op_t is (
        ALU_NOP,
        ALU_PASS_B,
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_NOT,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA
    );

    -- ALU input A selection
    type alu_a_sel_t is (
        ALU_A_REGA,
        ALU_A_PC,
        ALU_A_SP
    );

    -- ALU input B selection
    type alu_b_sel_t is (
        ALU_B_REGB,
        ALU_B_IMM8_ZEXT,
        ALU_B_IMM8_SEXT,
        ALU_B_IMM4_ZEXT,
        ALU_B_OFF5_SEXT,
        ALU_B_OFF11_SEXT,
        ALU_B_CONST_1
    );

    -- Stages
    type state_t is (
        ST_FETCH,
        ST_DECODE,
        ST_EXECUTE,
        ST_MEMORY,
        ST_WRITEBACK
    );

    -- Decoded instruction
    type decoded_instr_t is record
        raw    : instr_t;
        kind   : instr_kind_t;
        format : instr_format_t;

        opcode : opcode_t;
        func   : func_t;

        dest   : reg_idx_t;
        src_a  : reg_idx_t;
        src_b  : reg_idx_t;

        use_src_a : std_logic;
        use_src_b : std_logic;

        imm8   : imm8_t;
        imm4   : imm4_t;
        off5   : off5_t;
        off11  : off11_t;
        addr11 : instr_addr_t;
    end record;

    -- Inter-stage struct
    type fetch_to_decode_t is record
        instr    : instr_t;
    end record;

    type decode_to_exe_t is record
        dec_instr : decoded_instr_t;
        reg_a     : data_t;
        reg_b     : data_t;
        dest      : reg_idx_t;
        alu_op    : alu_op_t;
    end record;

    type exe_to_mem_t is record
        dec_instr    : decoded_instr_t;
        alu_result   : data_t;
        dest         : reg_idx_t;
    end record;

    type mem_to_writeback_t is record
        dec_instr : decoded_instr_t;
        result    : data_t;
        dest      : reg_idx_t;
    end record;

    -- Control unit signals
    type ctrl_signals_t is record
        
    end record;

    -- Zero-extension function
    function zext(x : std_logic_vector; size : natural) return std_logic_vector;
    -- Sign-extension function
    function sext(x : std_logic_vector; size : natural) return std_logic_vector;

end package;

package body tydeus16_pkg is

    function zext(x : std_logic_vector; size : natural) return std_logic_vector is
    begin
        assert size >= x'length
            report "zext: target size smaller than input size"
            severity failure;

        return std_logic_vector(resize(unsigned(x), size));
    end function;

    function sext(x : std_logic_vector; size : natural) return std_logic_vector is
    begin
        assert size >= x'length
            report "sext: target size smaller than input size"
            severity failure;

        return std_logic_vector(resize(signed(x), size));
    end function;

end package body;