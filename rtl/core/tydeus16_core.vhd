library ieee;
use ieee.std_logic_1164.all;

use work.tydeus16_pkg.all;

entity tydeus16_core is
    port (
        clk_i : in std_logic;
        rst_i : in std_logic;

        -- Instruction memory interface
        imem_addr_o  : out instr_addr_t;
        imem_rdata_i : in  instr_t;

        -- Data memory interface
        dmem_addr_o  : out data_addr_t;
        dmem_rdata_i : in  data_t;
        dmem_wdata_o : out data_t;
        dmem_we_o    : out std_logic;

        -- Exception interface
        exception_o  : out exception_t
    );
end entity;

architecture rtl of tydeus16_core is
    signal ctrl             : ctrl_signals_t;
    signal fetch_to_decode  : fetch_to_decode_t;
    signal decode_to_exe    : decode_to_exe_t;
    signal exe_to_mem       : exe_to_mem_t;
    signal mem_to_writeback : mem_to_writeback_t;
    signal dec_instr        : decoded_instr_t;
    signal flags            : flags_t;
    signal sp_empty         : std_logic;

begin
    u_datapath : entity work.datapath
        port map (
            clk_i              => clk_i,
            rst_i              => rst_i,

            imem_addr_o        => imem_addr_o,
            imem_rdata_i       => imem_rdata_i,

            dmem_addr_o        => dmem_addr_o,
            dmem_rdata_i       => dmem_rdata_i,
            dmem_wdata_o       => dmem_wdata_o,
            dmem_we_o          => dmem_we_o,

            ctrl_i             => ctrl,
            fetch_to_decode_o  => fetch_to_decode,
            decode_to_exe_o    => decode_to_exe,
            exe_to_mem_o       => exe_to_mem,
            mem_to_writeback_o => mem_to_writeback,
            dec_instr_o        => dec_instr,
            flags_o            => flags,
            sp_empty_o         => sp_empty
        );

    u_control_unit : entity work.control_unit
        port map (
            clk_i              => clk_i,
            rst_i              => rst_i,

            ctrl_o             => ctrl,

            fetch_to_decode_i  => fetch_to_decode,
            decode_to_exe_i    => decode_to_exe,
            exe_to_mem_i       => exe_to_mem,
            mem_to_writeback_i => mem_to_writeback,

            dec_instr_i        => dec_instr,
            flags_i            => flags,
            sp_empty_i         => sp_empty,

            exception_o        => exception_o
        );

end architecture;
