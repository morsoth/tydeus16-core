# Tydeus-16 Memory Timing

Tydeus-16 uses separate instruction and data memory interfaces. The current core assumes
synchronous memories with one-cycle read latency.

This document describes the timing contract expected by the datapath and control unit.

## Instruction Memory

Instruction memory is read-only from the ISA point of view.

| Property | Value |
| --- | --- |
| Address width | 11 bits |
| Depth | 2048 words |
| Word width | 16 bits |
| Read timing | Synchronous, one-cycle latency |
| Write support from core | None |

Timing:

```text
Cycle N, Fetch:
  imem_addr_o = PC
  PC          = PC + 1 at clock edge

Cycle N+1, Decode:
  imem_rdata_i contains instruction fetched from old PC
  decoder consumes imem_rdata_i
```

The instruction memory may update its output on every clock, but the core only treats
`imem_rdata_i` as the current instruction during Decode immediately after Fetch.

## Data Memory

Data memory stores program data and stack contents.

| Property | Value |
| --- | --- |
| Address width | 16 bits |
| Depth | 65536 words |
| Word width | 16 bits |
| Read timing | Synchronous, one-cycle latency |
| Write timing | Synchronous write in Memory stage |

### LOAD Timing

```text
Execute:
  effective address = base + sext(off5)

Memory:
  dmem_addr_o = effective address
  dmem_we_o   = 0

Write-back:
  register destination <- dmem_rdata_i
```

### STORE Timing

```text
Execute:
  effective address = base + sext(off5)

Memory:
  dmem_addr_o  = effective address
  dmem_wdata_o = source register data
  dmem_we_o    = 1
```

`STORE` finishes in Memory.

### CALL Timing

```text
Execute:
  new SP = SP - 1

Memory:
  dmem_addr_o  = new SP
  dmem_wdata_o = PC + 1
  dmem_we_o    = 1
  SP           = new SP
  PC           = call target
```

`CALL` finishes in Memory.

### RET Timing

```text
Execute:
  new SP = SP + 1

Memory:
  dmem_addr_o = old SP
  dmem_we_o   = 0

Write-back:
  PC = dmem_rdata_i
  SP = new SP
```

`RET` uses Write-back because the return address is not available until one cycle after the
Memory-stage read address is issued.

If `RET` is decoded while `SP = SP_RESET`, the control unit raises `EX_STACK_UNDERFLOW` in Decode
and enters `ST_TRAP`. In that case no data memory read is issued.

## Why This Model

This model is friendlier to FPGA block RAM inference than zero-cycle combinational memories.
It keeps the FSM compact by using existing Decode and Write-back stages as the memory response
cycles.
