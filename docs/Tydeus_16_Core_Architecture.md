# Tydeus-16 Core Architecture

###### Version: 0.1

Tydeus-16 is a 16-bit VHDL processor core that implements AthenISA.
The core uses a multicycle, non-pipelined microarchitecture with separate instruction and data
memories.

This document describes implementation details of the Tydeus-16 core. Programmer-visible
architecture details such as registers, instructions, opcodes, and memory semantics are defined
in the AthenISA specification.

## 1. Goal
???

## 2. Specifications

- Data width: 16 bits
- Instruction width: 16 bits
- General-purpose registers: 7
- Multi-cycle
- Separeted instruction and data memories
- Single clock
- No interrupts

## 3. Architectural State Implemented by the Core

Tydeus-16 implements the architectural state defined by AthenISA:

- `R0`, a constant zero register
- `R1` through `R7`, seven 16-bit general-purpose registers
- `PC`, an 11-bit program counter
- `SP`, a 16-bit stack pointer
- `FLAGS`, a 4-bit status register containing `Z`, `C`, `N`, and `V`

The architectural meaning of these registers is defined in the AthenISA specification.
This document focuses on how the core uses them internally during instruction execution.

## 4. Memory System

Tydeus-16 uses a Harvard-style memory organization with separate instruction and data memories.
Both memories are word-addressed and use 16-bit words.

### 4.1 Instruction Memory Interface

Instruction memory stores the program code executed by the processor.

| Property | Value |
| --- | --- |
| Address width | 11 bits |
| Number of words | 2048 |
| Word width | 16 bits |
| Total size | 4 KB |
| Core access | Read during Fetch |
| ISA write access | None |

During the Fetch stage, the core reads the instruction located at the current `PC` value.

### 4.2 Data Memory Interface

Data memory stores program data and stack contents.

| Property | Value |
| --- | --- |
| Address width | 16 bits |
| Number of words | 65536 |
| Word width | 16 bits |
| Total size | 128 KB |
| Core access | Read/write during Memory stage |

The current ISA accesses data memory using base-plus-offset addressing for `LOAD` and `STORE`.
The stack also resides in data memory and is accessed by `CALL` and `RET`.

### 4.3 Memory Latency Assumption

The current design assumes one-cycle memory latency for both instruction and data memories.
This simplifies the multicycle control unit and avoids structural hazards between instruction
fetches and data accesses.

### 4.4 Stack Implementation

The stack resides in the upper region of data memory and grows toward lower addresses.
The `SP` register points to the element currently located at the top of the stack.

The core implements subroutine calls and returns as follows:

```text
CALL:
  SP      <- SP - 1
  MEM[SP] <- PC + 1
  PC      <- addr(11)

RET:
  PC <- MEM[SP]
  SP <- SP + 1
```

## 5. Multicycle Datapath

Tydeus-16 is not pipelined. Each instruction advances through a subset of logical execution
stages across multiple clock cycles.

The core defines the following logical stages:

- Fetch (`F`)
- Decode (`D`)
- Execute (`E`)
- Memory (`M`)
- Write-back (`W`)

Not all instructions use all stages. Each instruction only traverses the stages required for its
execution. This keeps simple instructions short while still allowing memory, stack, and
control-flow instructions to use additional cycles when needed.

## 6. Stage Descriptions

### 6.1 Fetch Stage

The Fetch stage obtains the current instruction from instruction memory.

Main tasks:

- read the instruction located at `PC`
- latch the fetched instruction into the fetch-to-decode stage register
- prepare the sequential next value of `PC`, corresponding to `PC + 1`

Typical outputs:

- fetched instruction
- current `PC`
- optional `PC + 1` value for later stages

### 6.2 Decode Stage

The Decode stage interprets the instruction and gathers source operands.

Main tasks:

- decode the opcode and instruction format
- extract instruction fields such as `rd`, `rs`, `rs1`, `rs2`, `rb`, immediates, offsets, or addresses
- determine which source registers must be read from the register file
- read the register file when required
- latch decoded instruction information and source operands into the decode-to-execute stage register

Typical outputs:

- decoded instruction metadata
- source register values
- destination register indexes
- immediate or offset fields

### 6.3 Execute Stage

The Execute stage performs computations required by the instruction.

Main tasks:

- select ALU operands
- execute arithmetic and logic operations
- evaluate branch conditions
- compute effective addresses for memory operations
- compute stack pointer updates such as `SP - 1` or `SP + 1`
- generate candidate status flags when applicable

Typical outputs:

- ALU result
- branch condition result
- effective memory address
- stack pointer update candidate
- flags candidate

### 6.4 Memory Stage

The Memory stage performs data memory accesses.

Main tasks:

- read data memory for `LOAD`
- write data memory for `STORE`
- store the return address on the stack for `CALL`
- read the return address from the stack for `RET`

Typical outputs:

- memory read data
- committed memory writes
- return addresses loaded from the stack

### 6.5 Write-Back Stage

The Write-back stage writes instruction results into architectural state.

Main tasks:

- write results into the register file
- commit final ALU results
- commit status flags when applicable

Write-back is used only by instructions that produce a register result or require a final
register-file update. Program counter and stack pointer updates for control-flow and stack
instructions are committed in their corresponding final stage.

## 7. Instruction Stage Usage

The following table summarizes the stage path used by each instruction group.

| Instruction group | Stages |
| --- | --- |
| Arithmetic / Logic | `F -> D -> E -> W` |
| Comparisons | `F -> D -> E` |
| NOP | `F -> D` |
| Shifts | `F -> D -> E -> W` |
| LI / LIH | `F -> D -> E -> W` |
| JMP | `F -> D` |
| Conditional branches | `F -> D -> E` |
| CALL | `F -> D -> E -> M` |
| RET | `F -> D -> E -> M` |
| LOAD | `F -> D -> E -> M -> W` |
| STORE | `F -> D -> E -> M` |

Note: the original draft contained an inconsistency between the summary table and the
per-instruction descriptions for arithmetic, logic, shift, and immediate instructions. This
version uses the per-instruction behavior: instructions that do not access memory skip the
Memory stage.

## 8. Per-Instruction-Group Behavior

### 8.1 Arithmetic and Logic Instructions

Includes:

- `MOV`
- `ADD`
- `ADDI`
- `SUB`
- `SUBI`
- `AND`
- `OR`
- `XOR`
- `NOT`

Stage path:

```text
F -> D -> E -> W
```

Behavior:

- Fetch reads the instruction from instruction memory.
- Decode decodes the instruction, reads required source registers, and prepares immediates when needed.
- Execute performs the selected ALU operation and computes flags when applicable.
- Write-back writes the result to the destination register and commits updated flags when applicable.

### 8.2 Comparison Instructions

Includes:

- `CMP`
- `CMPI`

Stage path:

```text
F -> D -> E
```

Comparison instructions behave like subtraction operations, but do not write the subtraction
result back to the register file. Their purpose is to update `FLAGS` so that later conditional
branch instructions can test the result.

### 8.3 NOP

Stage path:

```text
F -> D
```

During Decode, the instruction is identified as `NOP`.
No operands are read, no ALU operation is performed, and no architectural state is modified.

### 8.4 Shift Instructions

Includes:

- `SLL`
- `SRL`
- `SRA`

Stage path:

```text
F -> D -> E -> W
```

Behavior:

- Decode reads the source register and extracts the 4-bit shift amount.
- Execute performs the selected shift operation.
- Write-back writes the shifted result to the destination register.

### 8.5 Immediate Construction Instructions

Includes:

- `LI`
- `LIH`

Stage path:

```text
F -> D -> E -> W
```

Behavior:

- Decode extracts the destination register and 8-bit immediate.
- For `LIH`, the previous value of the destination register may be read so that the lower byte can be preserved.
- Execute constructs the value to be written.
- Write-back writes the constructed value into the destination register.

### 8.6 JMP

Stage path:

```text
F -> D
```

During Decode, the absolute 11-bit target address is extracted and the program counter is
updated to the jump target.

`JMP` does not require an explicit Execute or Write-back stage because the jump target is
encoded directly in the instruction and can be committed during Decode.

### 8.7 Conditional Branches

Includes:

- `BEQ`
- `BNE`
- `BLT`
- `BGT`
- `BLE`
- `BGE`

Stage path:

```text
F -> D -> E
```

Behavior:

- Decode extracts the signed 11-bit offset and branch type.
- Execute evaluates the branch condition using the current `FLAGS` value.
- If the condition is true, the branch target is computed as `PC + 1 + sext(off(11))`.
- If the condition is false, execution continues with the sequential instruction.

### 8.8 CALL

Stage path:

```text
F -> D -> E -> M
```

Behavior:

- Decode extracts the absolute 11-bit target address.
- Execute computes the updated stack pointer value `SP - 1` and prepares the return address `PC + 1`.
- Memory writes the return address to the stack, updates `SP`, and sets `PC` to the call target.

Final state update:

```text
SP      <- SP - 1
MEM[SP] <- PC + 1
PC      <- addr(11)
```

### 8.9 RET

Stage path:

```text
F -> D -> E -> M
```

Behavior:

- Decode identifies the instruction as a return.
- Execute prepares the current stack address and computes `SP + 1`.
- Memory reads the return address from the stack, restores `PC`, and updates `SP`.

Final state update:

```text
PC <- MEM[SP]
SP <- SP + 1
```

### 8.10 LOAD

Stage path:

```text
F -> D -> E -> M -> W
```

Behavior:

- Decode reads the base register and extracts the signed 5-bit offset.
- Execute computes the effective address as `rb + sext(off(5))`.
- Memory reads data memory at the effective address.
- Write-back writes the loaded word into the destination register.

### 8.11 STORE

Stage path:

```text
F -> D -> E -> M
```

Behavior:

- Decode reads the base register and the source data register.
- Execute computes the effective address as `rb + sext(off(5))`.
- Memory writes the source data to data memory at the computed effective address.

## 9. Stage Philosophy

The design does not force all instructions to pass through all stages.
Each instruction uses only the stages that are actually required.

- Execute is the general computation stage. It is used for ALU operations, address calculations,
  stack pointer arithmetic, and branch condition evaluation.
- Memory is used only by instructions that access data memory or stack memory.
- Write-back is used by instructions that produce a final register-file result, such as arithmetic,
  logic, shift, immediate construction, and load instructions.

## 10. Control Unit Notes

The current design uses a multicycle control unit.
A future version of this document should define:

- FSM states
- transitions between stages
- control signals per state
- ALU operation selection
- register file read/write enables
- memory read/write enables
- flags write enable
- `PC` update control
- `SP` update control

## 11. Open Core Decisions

The following implementation-level decisions remain open:

- exact behavior on data memory out-of-range accesses
- stack overflow and underflow handling
- whether stack regions should be protected or reserved
- whether memory-mapped I/O will be introduced
- whether an interrupt controller will be added in a future version
- whether reserved ISA opcodes should trap, stall, NOP, or remain undefined at the core level
- whether debug or trace signals should be exposed
