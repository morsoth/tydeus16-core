# Tydeus-16 Core Overview

Version: 0.1

Tydeus-16 is a 16-bit VHDL processor core that implements AthenISA. The core uses a
multicycle, non-pipelined microarchitecture with separate instruction and data memories.

This document is the entry point for the core implementation documentation. Programmer-visible
ISA behavior is defined by the AthenISA specification; these documents describe how the current
RTL implements that behavior.

## Documentation Map

- [Core package](01_package.md): shared widths, types, decoded instruction records, stage
  records, control records, reset constants, and helper functions.
- [Datapath](02_datapath.md): architectural registers, register file, decoder, ALU, muxes,
  stage registers, and memory interfaces.
- [Control unit](03_control_unit.md): FSM state transitions and control signal behavior.
- [Memory timing](04_memory_timing.md): synchronous instruction/data memory contract and how each
  stage consumes memory data.
- [Instruction flow](05_instruction_flow.md): per-instruction stage paths and high-level execution
  behavior.
- [Exceptions](06_exceptions.md): trap state behavior, exception causes, and stack-underflow
  detection.

## Implementation Summary

| Property | Value |
| --- | --- |
| Data width | 16 bits |
| Instruction width | 16 bits |
| General-purpose registers | 7 plus `R0` zero register |
| Program counter width | 11 bits |
| Stack pointer width | 16 bits |
| Flags | `Z`, `C`, `N`, `V` |
| Microarchitecture | Multicycle, non-pipelined |
| Memory organization | Harvard, separate instruction and data memories |
| Memory read timing | Synchronous, one-cycle read latency |
| Exception support | Illegal instruction and stack-underflow halt traps |
| Interrupt support | None in v0.1 |

## Core State

The core implements the architectural state defined by AthenISA:

- `R0`, a constant zero register.
- `R1` through `R7`, seven 16-bit general-purpose registers.
- `PC`, an 11-bit program counter.
- `SP`, a 16-bit stack pointer.
- `FLAGS`, a 4-bit status register containing `Z`, `C`, `N`, and `V`.

## Stage Model

The current control unit uses six logical states:

| Stage | Role |
| --- | --- |
| `ST_FETCH` | Issue instruction memory address and advance `PC` for sequential execution. |
| `ST_DECODE` | Consume instruction memory read data, decode, and read source registers. |
| `ST_EXECUTE` | Run ALU work, compute addresses, update flags, and evaluate branches. |
| `ST_MEMORY` | Issue data memory access or transfer execute results toward Write-back. |
| `ST_WRITEBACK` | Commit register results or consume data memory read data for `LOAD`/`RET`. |
| `ST_TRAP` | Hold the core after an exception with all architectural writes disabled. |

The names are logical stage names. `ST_MEMORY` is used both for real data memory accesses and
as an internal transfer stage before Write-back for non-memory instructions that produce a
register result.

## Memory Contract

The core expects synchronous memories with one-cycle read latency:

```text
Instruction read:
  Fetch  -> drive IMEM address
  Decode -> consume IMEM read data

Data read:
  Memory     -> drive DMEM address
  Write-back -> consume DMEM read data
```

For details, see [Memory timing](04_memory_timing.md).

## Current Open Decisions

- Behavior on data memory out-of-range accesses.
- Stack overflow handling.
- Whether stack regions should be protected or reserved.
- Whether memory-mapped I/O will be introduced.
- Whether exceptions should remain halt-only or become vectored traps.
- Whether debug or trace signals should be exposed.
