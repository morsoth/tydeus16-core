# Tydeus-16 Instruction Flow

This document summarizes how each AthenISA instruction group moves through the current
Tydeus-16 multicycle core.

Stage names:

| Abbrev | State |
| --- | --- |
| `F` | `ST_FETCH` |
| `D` | `ST_DECODE` |
| `E` | `ST_EXECUTE` |
| `M` | `ST_MEMORY` |
| `W` | `ST_WRITEBACK` |

## Stage Usage Table

| Instruction group | Stages |
| --- | --- |
| `NOP` | `F -> D` |
| `JMP` | `F -> D` |
| `CMP`, `CMPI` | `F -> D -> E` |
| Conditional branches | `F -> D -> E` |
| `STORE` | `F -> D -> E -> M` |
| `CALL` | `F -> D -> E -> M` |
| `RET` | `F -> D -> E -> M -> W` |
| `LOAD` | `F -> D -> E -> M -> W` |
| Arithmetic and logic writes | `F -> D -> E -> M -> W` |
| Shifts | `F -> D -> E -> M -> W` |
| `LI`, `LIH` | `F -> D -> E -> M -> W` |

Instructions that write a register generally use Write-back. Instructions that only update
flags or `PC` can finish earlier.

## Fetch And Decode

All instructions begin with Fetch and Decode:

```text
F:
  issue IMEM address = PC
  PC = PC + 1

D:
  consume IMEM read data
  decode instruction
  read source registers
```

`JMP` is resolved in Decode because its target is encoded directly in the instruction.

## Execute

Execute is used for:

- ALU operations
- address calculations
- stack pointer update candidates
- branch target calculations
- flag generation

`CMP` and `CMPI` finish in Execute after updating flags. Conditional branches also finish in
Execute after optionally updating `PC`.

## Memory

Memory is used in two ways:

- as a real data memory request stage for `LOAD`, `STORE`, `CALL`, and `RET`
- as a transfer stage before Write-back for register-producing instructions

No data memory access is issued for ALU, logic, shift, `LI`, or `LIH` instructions.

## Write-Back

Write-back commits final architectural updates:

- register file write for arithmetic, logic, shifts, `LI`, `LIH`, and `LOAD`
- `PC` and `SP` update for `RET`

`LOAD` and `RET` consume `dmem_rdata_i` in Write-back because data memory reads have one-cycle
latency.

## Per-Instruction Notes

### Arithmetic And Logic

Path:

```text
F -> D -> E -> M -> W
```

Execute computes the result and candidate flags. Memory carries result metadata forward.
Write-back writes the destination register. Flags are committed in Execute when `flags_we` is
asserted.

### LI And LIH

Path:

```text
F -> D -> E -> M -> W
```

`LI` constructs a zero-extended immediate value. `LIH` combines the immediate byte with the old
low byte of the destination register.

### LOAD

Path:

```text
F -> D -> E -> M -> W
```

Execute computes the effective data address. Memory issues the read. Write-back writes
`dmem_rdata_i` into the destination register.

### STORE

Path:

```text
F -> D -> E -> M
```

Execute computes the effective data address. Memory writes the source register data.

### CALL

Path:

```text
F -> D -> E -> M
```

Execute computes `SP - 1`. Memory stores `PC + 1` at the new stack address, updates `SP`, and
loads `PC` with the call target.

### RET

Path:

```text
F -> D -> E -> M -> W
```

Execute computes `SP + 1`. Memory issues a read from the old stack address. Write-back loads
`PC` from `dmem_rdata_i` and commits the new `SP`.
