# Tydeus-16 Datapath

The datapath is implemented in [`rtl/datapath/datapath.vhd`](../rtl/datapath/datapath.vhd).
It contains the architectural registers, stage registers, decoder, register file, ALU, muxes,
and external memory interfaces.

## External Interfaces

Instruction memory:

| Signal | Direction | Meaning |
| --- | --- | --- |
| `imem_addr_o` | out | Instruction memory address, driven from `PC`. |
| `imem_rdata_i` | in | Instruction read data consumed during Decode. |

Data memory:

| Signal | Direction | Meaning |
| --- | --- | --- |
| `dmem_addr_o` | out | Data memory address selected in Memory stage. |
| `dmem_rdata_i` | in | Data memory read data consumed during Write-back. |
| `dmem_wdata_o` | out | Data memory write data. |
| `dmem_we_o` | out | Data memory write enable. |

Control interface:

| Signal | Direction | Meaning |
| --- | --- | --- |
| `ctrl_i` | in | Complete control signal bundle. |
| `*_o` stage records | out | Current stage-register contents for the control unit. |
| `dec_instr_o` | out | Current decoded instruction from `imem_rdata_i`. |
| `flags_o` | out | Current committed flags register. |

## Architectural Registers

The datapath owns:

- `PC`: instruction memory address for Fetch.
- `SP`: stack pointer used by `CALL` and `RET`.
- `FLAGS`: committed status flags.

The register file owns `R0` through `R7`. `R0` is hardwired to zero by the register file.

## Decode Path

The decoder consumes `imem_rdata_i` directly. This is intentional for the synchronous
instruction memory contract:

```text
Fetch  -> issue IMEM address
Decode -> consume IMEM read data
```

The Decode stage latches:

- decoded instruction metadata
- `PC + 1`
- current `SP`
- source register values
- destination register index

## Execute Path

The ALU input muxes select:

Operand A:

- register A
- `PC + 1`
- `SP`

Operand B:

- register B
- zero-extended 8-bit immediate
- zero-extended 4-bit immediate
- sign-extended 5-bit offset
- sign-extended 11-bit offset
- constant `1`

The execute result mux selects between:

- ALU result
- `LI` constructed value
- `LIH` constructed value

Flags are produced by the ALU and committed only when `flags_we` is asserted.

## Memory Path

The Memory stage drives the data memory interface.

Address sources:

- `DMEM_ADDR_EXE`: effective address or updated stack address from Execute.
- `DMEM_ADDR_RET`: old `SP` captured before Execute, used to read return address.

Write data sources:

- `DMEM_WDATA_REGB`: store data from the register file.
- `DMEM_WDATA_PC`: return address `PC + 1` for `CALL`.

For `LOAD` and `RET`, Memory only issues the read address. The returned data is consumed in
Write-back.

## Write-Back Path

The register file write address comes from `mem_to_writeback_q.rf_dest`.

Write data sources:

- `WB_SEL_EXE`: execute result carried through `mem_to_writeback_q`.
- `WB_SEL_MEM`: data memory read data `dmem_rdata_i`.

`RET` does not write the register file. Instead, Write-back uses `dmem_rdata_i` as the next
`PC` and commits the `SP + 1` value computed in Execute.

## Stage Register Enables

The control unit decides which stage registers update each cycle:

- `fetch_to_decode_we`
- `decode_to_exe_we`
- `exe_to_mem_we`
- `mem_to_writeback_we`

These enables allow short instructions such as `NOP`, `JMP`, comparisons, and branches to skip
unneeded later stages.
