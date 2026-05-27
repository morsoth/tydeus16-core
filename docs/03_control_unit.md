# Tydeus-16 Control Unit

The control unit is implemented in [`rtl/control/control_unit.vhd`](../rtl/control/control_unit.vhd).
It is a multicycle FSM that drives the datapath through Fetch, Decode, Execute, Memory, and
Write-back.

## Inputs And Outputs

Inputs:

- current stage records from the datapath
- current decoded instruction
- committed flags register
- clock and reset

Output:

- `ctrl_signals_t`, the full control bundle consumed by the datapath

## FSM States

| State | Purpose |
| --- | --- |
| `ST_FETCH` | Issue instruction memory read and advance `PC` for sequential execution. |
| `ST_DECODE` | Consume instruction memory read data and latch decoded operands. |
| `ST_EXECUTE` | Run ALU work, compute addresses, evaluate branches, and update flags. |
| `ST_MEMORY` | Issue data memory access or transfer execute result metadata. |
| `ST_WRITEBACK` | Commit register results or consume data memory read data. |

## Next-State Behavior

High-level transitions:

```text
FETCH -> DECODE

DECODE:
  NOP, JMP -> FETCH
  others   -> EXECUTE

EXECUTE:
  CMP, CMPI             -> FETCH
  conditional branches  -> FETCH
  others                -> MEMORY

MEMORY:
  STORE, CALL -> FETCH
  others      -> WRITEBACK

WRITEBACK -> FETCH
```

`RET` goes through Write-back because the return address is read from synchronous data memory
and is not available in the same cycle as the Memory-stage read address.

## Fetch Control

In `ST_FETCH`:

- `fetch_to_decode_we = 1`
- `pc_we = 1`
- `pc_sel = PC_SEL_PLUS_1`

The datapath drives `imem_addr_o` from the old `PC`. The instruction memory returns the
instruction in time for `ST_DECODE`.

## Decode Control

In `ST_DECODE`:

- `decode_to_exe_we = 1` for most instructions.
- `NOP` does not latch into Execute.
- `JMP` updates `PC` directly from the decoded absolute address and does not enter Execute.

`JMP` is resolved in Decode because the target address is encoded directly in the instruction.

## Execute Control

Execute selects the ALU operation, ALU operands, execute result source, and flag write enable.

Examples:

| Instruction | Main control behavior |
| --- | --- |
| `MOV` | `ALU_PASS_B`. |
| `ADD`, `ADDI` | `ALU_ADD`, flags enabled. |
| `SUB`, `SUBI`, `CMP`, `CMPI` | `ALU_SUB`, flags enabled. |
| `AND`, `OR`, `XOR`, `NOT` | Logic ALU operation, flags enabled. |
| `LI` | `EXE_RESULT_LI`. |
| `LIH` | `EXE_RESULT_LIH`. |
| `SLL`, `SRL`, `SRA` | Shift ALU operation with `IMM4` as operand B. |
| branches | ALU computes `PC + 1 + sext(off11)` when branch condition is true. |
| `CALL` | ALU computes `SP - 1`. |
| `RET` | ALU computes `SP + 1`. |
| `LOAD`, `STORE` | ALU computes `base + sext(off5)`. |

Comparisons and conditional branches do not write a register, so they skip Memory and
Write-back.

## Branch Conditions

The control unit evaluates signed branch conditions using flags:

| Branch | Condition |
| --- | --- |
| `BEQ` | `Z = 1` |
| `BNE` | `Z = 0` |
| `BLT` | `N xor V = 1` |
| `BGT` | `Z = 0 and (N xor V) = 0` |
| `BLE` | `Z = 1 or (N xor V) = 1` |
| `BGE` | `N xor V = 0` |

## Memory Control

In `ST_MEMORY`:

| Instruction | Behavior |
| --- | --- |
| `LOAD` | Drive effective address, no write. |
| `STORE` | Drive effective address, write register B data. |
| `CALL` | Write return address to `SP - 1`, update `SP`, update `PC`. |
| `RET` | Drive old `SP` as read address, no write. |
| ALU/shift/immediate ops | Transfer execute result metadata toward Write-back. |

`STORE` and `CALL` finish in Memory. `LOAD`, `RET`, and register-producing instructions enter
Write-back.

## Write-Back Control

In `ST_WRITEBACK`:

| Instruction | Behavior |
| --- | --- |
| ALU, logic, shift, `LI`, `LIH` | Write execute result to register file. |
| `LOAD` | Write `dmem_rdata_i` to register file. |
| `RET` | Load `PC` from `dmem_rdata_i` and commit `SP + 1`. |

No data memory write is issued in Write-back.
