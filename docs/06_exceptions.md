# Tydeus-16 Exceptions

This document describes the current exception protocol implemented by the Tydeus-16 core.

Exceptions are internal error conditions detected by the control unit. In the current RTL they do
not vector to a handler routine. Instead, the core enters a trap state and remains halted until
reset.

## Exception Record

Exception information is represented by `exception_t` from
[`rtl/pkg/tydeus16_pkg.vhd`](../rtl/pkg/tydeus16_pkg.vhd):

| Field | Meaning |
| --- | --- |
| `valid` | Asserted when an exception has been taken. |
| `origin` | Instruction address that caused the exception. |
| `cause` | Encoded exception cause. |

The current exception causes are:

| Cause | Meaning |
| --- | --- |
| `EX_NONE` | No exception. |
| `EX_ILLEGAL_INSTR` | The decoder produced `IK_INVALID`. |
| `EX_STACK_UNDERFLOW` | A `RET` was decoded while the stack was empty. |

## Trap State

When an exception is detected, the control unit enters `ST_TRAP`.

In `ST_TRAP`:

- `exception_o.valid` remains asserted.
- `exception_o.cause` keeps the first recorded cause.
- `exception_o.origin` keeps the PC of the faulting instruction.
- all control signals remain at `CTRL_SIGNALS_RESET`.
- no architectural state is written.
- no data memory write is issued.

The exception is sticky. It remains visible until `rst_i` resets the control unit.

## Detection Points

Exceptions currently detected in Decode:

| Condition | Detection state | Result |
| --- | --- | --- |
| `dec_instr_i.kind = IK_INVALID` | `ST_DECODE` | `EX_ILLEGAL_INSTR` |
| `dec_instr_i.kind = IK_RET` and `sp_empty_i = 1` | `ST_DECODE` | `EX_STACK_UNDERFLOW` |

Both exceptions are detected before Execute. This prevents the invalid instruction from entering
later stage registers and prevents an empty-stack `RET` from issuing a data memory read.

## Exception Origin

The instruction memory is synchronous:

```text
Fetch  -> issue IMEM address and increment PC
Decode -> consume fetched instruction
```

Because `PC` has already advanced by Decode, the datapath carries the original fetch PC in
`fetch_to_decode_t.pc`. The control unit uses that value as `exception_o.origin`.

This means:

```text
exception_o.origin = address of the instruction that caused the exception
current PC         = usually origin + 1 when the trap is taken
```

The current PC is held once the core enters `ST_TRAP`.

## Stack Underflow Rule

The stack pointer reset value is `SP_RESET = 0x0000`. With the current descending stack convention:

```text
CALL: SP <- SP - 1 ; MEM[SP] <- return address
RET:  PC <- MEM[SP] ; SP <- SP + 1
```

An empty stack is represented by:

```text
SP = SP_RESET
```

Therefore, a `RET` with `SP = SP_RESET` raises `EX_STACK_UNDERFLOW`.

## Current Limitations

The current exception mechanism is intentionally simple:

- no trap vector is implemented.
- no exception handler routine is executed.
- no exception return instruction exists.
- stack overflow is not detected.
- data memory protection is not implemented.

Future versions may replace `ST_TRAP` halt behavior with a vectored trap flow such as:

```text
exception detected -> save context -> PC <- TRAP_VECTOR
```

