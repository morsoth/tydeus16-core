library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tydeus16_pkg.all;

entity datapath is
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;

        -- Instruction memory interface
        imem_addr_o  : out instr_addr_t;
        imem_rdata_i : in instr_t;

        -- Data memory interface
        dmem_addr_o  : out data_addr_t;
        dmem_rdata_i : in data_t;
        dmem_wdata_o : out data_t;

        -- Control unit interface
        ctrl_i             : in ctrl_signals_t;
        fetch_to_decode_o  : out fetch_to_decode_t;
        decode_to_exe_o    : out decode_to_exe_t;
        exe_to_mem_o       : out exe_to_mem_t;
        mem_to_writeback_o : out mem_to_writeback_t
    );
end entity datapath;

architecture rtl of datapath is
    -- Inter-stage regiters
    signal fetch_to_decode_d, fetch_to_decode_q   : fetch_to_decode_t;
    signal decode_to_exe_d, decode_to_exe_q       : decode_to_exe_t;
    signal exe_to_mem_d, exe_to_mem_q             : exe_to_mem_t;
    signal mem_to_writeback_d, mem_to_writeback_q : mem_to_writeback_t;

    -- Global architectural registers
    signal pc_reg_d, pc_reg_q       : instr_addr_t;
    signal sp_reg_d, sp_reg_q       : data_addr_t;
    signal flags_reg_d, flags_reg_q : flags_t;

    -- Decoder
    signal dec_instr : decoded_instr_t;

    -- Regfile
    signal rf_rdata_a : data_t;
    signal rf_rdata_b : data_t;

    -- ALU
    signal alu_a      : data_t;
    signal alu_b      : data_t;
    signal alu_result : data_t;
    signal alu_flags  : flags_t;

begin
    -- Decoder
    u_decoder : entity work.decoder
        port map (
            instr_i     => fetch_to_decode_q.instr,
            dec_instr_o => dec_instr
        );

    -- Regfile
    u_regfile : entity work.regfile
        port map (
            clk_i      => clk_i,
            rst_i      => rst_i,

            raddr_a_i  => dec_instr.src_a,
            rdata_a_o  => rf_rdata_a,
            
            raddr_b_i  => dec_instr.src_b,
            rdata_b_o  => rf_rdata_b,

            waddr_d_i  => mem_to_writeback_q.dest,
            wdata_d_i  => mem_to_writeback_q.result,
            we_i       => ctrl_i.regfile_we
        );

    -- ALU
    u_alu : entity work.alu
        port map (
            a_i       => alu_a,
            b_i       => alu_b,
            result_o  => alu_result,
            op_i      => decode_to_exe_q.alu_op,
            flags_o   => alu_flags
        );

    -- Default Outputs
    imem_addr_o  <= pc_reg_q;
    dmem_addr_o  <= (others => '0');
    dmem_wdata_o <= (others => '0');

    -- Fetch Stage
    fetch_stage_p : process (all)
    begin
        fetch_to_decode_d       <= FETCH_TO_DECODE_RESET;
        fetch_to_decode_d.instr <= imem_rdata_i;

    end process;

    -- Decode Stage
    decode_stage_p : process (all)
    begin
        decode_to_exe_d           <= DECODE_TO_EXE_RESET;
        decode_to_exe_d.dec_instr <= dec_instr;
        decode_to_exe_d.reg_a     <= rf_rdata_a;
        decode_to_exe_d.reg_b     <= rf_rdata_b;
        decode_to_exe_d.dest      <= dec_instr.dest;
        decode_to_exe_d.alu_op    <= ctrl_i.alu_op;

    end process;

    -- Execute Stage
    exe_stage_p : process (all)
    begin
        exe_to_mem_d            <= EXE_TO_MEM_RESET;
        exe_to_mem_d.dec_instr  <= decode_to_exe_q.dec_instr;
        exe_to_mem_d.alu_result <= alu_result;
        exe_to_mem_d.dest       <= decode_to_exe_q.dest;

        flags_reg_d <= alu_flags;

    end process;

    alu_mux_p : process (all)
    begin
        case ctrl_i.alu_a_sel is
            when ALU_A_REGA =>  alu_a <= decode_to_exe_q.reg_a;
            when ALU_A_PC =>    alu_a <= zext(pc_reg_q, DATA_WIDTH);
            when ALU_A_SP =>    alu_a <= sp_reg_q;
            when others =>      alu_a <= (others => '0');
        end case;

        case ctrl_i.alu_b_sel is
            when ALU_B_REGB =>        alu_b <= decode_to_exe_q.reg_b;
            when ALU_B_IMM8_ZEXT =>   alu_b <= zext(decode_to_exe_q.dec_instr.imm8, DATA_WIDTH);
            when ALU_B_IMM8_SEXT =>   alu_b <= sext(decode_to_exe_q.dec_instr.imm8, DATA_WIDTH);
            when ALU_B_IMM4_ZEXT =>   alu_b <= zext(decode_to_exe_q.dec_instr.imm4, DATA_WIDTH);
            when ALU_B_OFF5_SEXT =>   alu_b <= sext(decode_to_exe_q.dec_instr.off5, DATA_WIDTH);
            when ALU_B_OFF11_SEXT =>  alu_b <= sext(decode_to_exe_q.dec_instr.off11, DATA_WIDTH);
            when ALU_B_CONST_1 =>     alu_b <= zext("1", DATA_WIDTH);
            when others =>            alu_b <= (others => '0');
        end case;

    end process;

    -- Memory Stage
    mem_stage_p : process (all)
    begin
        mem_to_writeback_d           <= MEM_TO_WRITEBACK_RESET;
        mem_to_writeback_d.dec_instr <= exe_to_mem_q.dec_instr;
        mem_to_writeback_d.result    <= exe_to_mem_q.alu_result;
        mem_to_writeback_d.dest      <= exe_to_mem_q.dest;

    end process;

    -- Write-back Stage
    writeback_stage_p : process (all)
    begin

    end process;

    -- PC Register
    pc_p : process(all)
    begin
        pc_reg_d <= pc_reg_q;

        case ctrl_i.pc_sel is
            when PC_SEL_PLUS_1 =>  pc_reg_d <= std_logic_vector(unsigned(pc_reg_q) + 1);
            when others =>         pc_reg_d <= pc_reg_q;
        end case;
        
    end process;

    -- SP Register
    sp_p : process(all)
    begin
        sp_reg_d <= sp_reg_q;
        
    end process;

    -- Sequential Registers
    seq_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                pc_reg_q            <= (others => '0');
                sp_reg_q            <= (others => '0');
                flags_reg_q         <= (others => '0');

                fetch_to_decode_q   <= FETCH_TO_DECODE_RESET;
                decode_to_exe_q     <= DECODE_TO_EXE_RESET;
                exe_to_mem_q        <= EXE_TO_MEM_RESET;
                mem_to_writeback_q  <= MEM_TO_WRITEBACK_RESET;
                
            else
                if ctrl_i.pc_we = '1' then
                    pc_reg_q <= pc_reg_d;
                end if;

                if ctrl_i.flags_we = '1' then
                    flags_reg_q <= flags_reg_d;
                end if;

                if ctrl_i.fetch_to_decode_we = '1' then
                    fetch_to_decode_q <= fetch_to_decode_d;
                end if;

                if ctrl_i.decode_to_exe_we = '1' then
                    decode_to_exe_q <= decode_to_exe_d;
                end if;

                if ctrl_i.exe_to_mem_we = '1' then
                    exe_to_mem_q <= exe_to_mem_d;
                end if;

                if ctrl_i.mem_to_writeback_we = '1' then
                    mem_to_writeback_q <= mem_to_writeback_d;
                end if;
            end if;
        end if;
    end process;

    -- Outputs
    fetch_to_decode_o  <= fetch_to_decode_q;
    decode_to_exe_o    <= decode_to_exe_q;
    exe_to_mem_o       <= exe_to_mem_q;
    mem_to_writeback_o <= mem_to_writeback_q;

end architecture rtl;