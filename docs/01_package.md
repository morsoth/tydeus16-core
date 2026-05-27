# Tydeus-16 Core Package

The RTL package is implemented in [`rtl/pkg/tydeus16_pkg.vhd`](../rtl/pkg/tydeus16_pkg.vhd).
It is the shared contract between the decoder, datapath, control unit, and future top-level
integration code.

## Widths And Sizes

| Constant | Meaning |
| --- | --- |
| `INSTR_WIDTH` | Instruction word width, 16 bits. |
| `DATA_WIDTH` | Data word width, 16 bits. |
| `INSTR_ADDR_WIDTH` | Instruction address width, 11 bits. |
| `DATA_ADDR_WIDTH` | Data address width, 16 bits. |
| `REG_COUNT` | Register file entries, including `R0`. |
| `REG_IDX_WIDTH` | Register index width, 3 bits. |
| `FLAGS_WIDTH` | Status flag register width, 4 bits. |
| `INSTR_MEM_SIZE` | Instruction memory depth, 2048 words. |
| `DATA_MEM_SIZE` | Data memory depth, 65536 words. |

The instruction address width is 11 bits because absolute `JMP` and `CALL` targets are encoded
in the lower 11 instruction bits.

## Common Subtypes

The package defines named subtypes for all architectural fields:

- `instr_t`, `data_t`
- `instr_addr_t`, `data_addr_t`
- `reg_idx_t`
- `imm8_t`, `imm4_t`
- `off5_t`, `off11_t`
- `opcode_t`, `func_t`
- `flags_t`

These subtypes keep port declarations readable and make field slicing intent clearer.

## Flags

The flag bit positions are:

| Constant | Meaning |
| --- | --- |
| `FLAG_Z` | Zero flag. |
| `FLAG_C` | Carry flag. |
| `FLAG_N` | Negative flag. |
| `FLAG_V` | Signed overflow flag. |

The ALU computes candidate flags. The datapath only commits them when the control unit asserts
`flags_we`.

## Instruction Classification

The decoder produces a `decoded_instr_t` record containing:

- raw instruction word
- semantic instruction kind
- instruction format
- opcode and function fields
- destination and source register indexes
- immediate, offset, and absolute address fields

`instr_kind_t` is used by the control unit to choose state transitions and control signals.
`instr_format_t` is used by the decoder to extract fields consistently.

## ALU And Mux Enums

The package defines the internal datapath control enums:

- `alu_op_t`: ALU operation selection.
- `alu_a_sel_t`: ALU operand A mux.
- `alu_b_sel_t`: ALU operand B mux.
- `exe_result_sel_t`: execute result mux for ALU, `LI`, and `LIH`.
- `pc_sel_t`: next `PC` source.
- `sp_sel_t`: next `SP` source.
- `dmem_addr_sel_t`: data memory address source.
- `dmem_wdata_sel_t`: data memory write data source.
- `wb_sel_t`: register file write-back data source.

Keeping these as enums avoids magic control vectors and makes the control unit easier to read.

## Stage Records

The multicycle core passes state through records:

| Record | Purpose |
| --- | --- |
| `fetch_to_decode_t` | Carries `PC + 1` from Fetch to Decode. |
| `decode_to_exe_t` | Carries decoded instruction, source operands, destination, `PC + 1`, and `SP`. |
| `exe_to_mem_t` | Carries execute result, store data, destination, instruction metadata, and stack context. |
| `mem_to_writeback_t` | Carries instruction metadata, destination, and execute result into Write-back. |

Data memory read data is not stored in `mem_to_writeback_t` in the current synchronous memory
model. `LOAD` and `RET` consume `dmem_rdata_i` directly in Write-back.

## Control Record

`ctrl_signals_t` is the complete control bundle driven by the control unit and consumed by the
datapath. It includes register enables, mux selections, ALU operation, memory controls, and
write-back selection.

`CTRL_SIGNALS_RESET` is the safe default: no architectural writes, `PC` held, `SP` held, no data
memory write, ALU NOP, and write-back defaulting to execute result.

## Helper Functions

The package provides:

- `zext(x, size)`: zero-extend a vector.
- `sext(x, size)`: sign-extend a vector.

Both functions assert that the target size is not smaller than the input size.
