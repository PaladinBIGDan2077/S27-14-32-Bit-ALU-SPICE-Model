# 32-bit ALU (unsigned) in SystemVerilog

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

A pulse-triggered 32-bit unsigned ALU written in SystemVerilog (module `alu_32bit`). It performs
22 operations (arithmetic, logic, compare, shift, multiply, divide, modulo) and returns a 64-bit
result with a 5-bit status word. Operands are captured when a one-shot trigger fires, the
operation runs over the next clock edges, and `complete` goes high when the result and flags
are valid.

> **Status:** work in progress. Simulation and synthesis results are not yet documented here
> (see [Roadmap](#roadmap)).
>
> **Coming soon:** a signed ALU, a signed multiplier unit and a signed divider unit
> (see [Coming soon](#coming-soon)).

---

## Contents

- [Features](#features)
- [Repository layout](#repository-layout)
- [Interface](#interface)
- [Operation protocol and timing](#operation-protocol-and-timing)
- [Opcode table](#opcode-table)
- [Status register](#status-register)
- [Instantiation example](#instantiation-example)
- [Design notes and limitations](#design-notes-and-limitations)
- [Coming soon](#coming-soon)
- [Roadmap](#roadmap)
- [License](#license)

---

## Features

- 32-bit unsigned operands, **64-bit result**
- 22 operations: ADD, SUB, NOTA, NOTB, AND, NAND, OR, NOR, XOR, XNOR,
  six compares (SLT, SGT, SLTE, SGTE, SEQU, SNEQ), logical shifts (SLR, SLL), NOP,
  MULT, DIV, MOD
- Single trigger input (`enable`) conditioned by an edge-based one-shot
- Divide-by-zero and illegal-opcode detection (the operation is converted to a `NOP`
  and the matching flag is raised)
- Carry / borrow, zero and completion flags, all aligned with the result
- Asynchronous active-low reset

## Repository layout

```
.
├── top_module_alu_32b.sv        # top-level module
├── tb_alu_32b.sv                # testbench
├── timingfile.sdc               # timing constraints (SDC)
├── unsigned/
│   └── alu_32bit_unsigned.sv    # module alu_32bit (unsigned ALU) and module input_one_shot
├── signed/
│   ├── alu_32bit_signed.sv      # module alu_32bit_signed        - placeholder, not functional yet
│   ├── multiplier_unit.sv       # module multiplier_unit_signed  - placeholder, not functional yet
│   └── divider_unit.sv          # module divider_unit_signed     - placeholder, not functional yet
├── LICENSE                      # GPL-3.0
└── README.md
```

Of the files in `signed/` and `unsigned/`, only `unsigned/alu_32bit_unsigned.sv` contains
working RTL today. The three files in `signed/` are skeletons for the work described in
[Coming soon](#coming-soon).

## Interface

### `alu_32bit`

| Port | Dir | Width | Description |
|---|---|---|---|
| `vector_a` | in | 32 | Operand A |
| `vector_b` | in | 32 | Operand B (also the shift amount: `vector_b[4:0]`) |
| `op_code` | in | 5 | Operation select (see [Opcode table](#opcode-table)) |
| `clock` | in | 1 | Rising-edge clock |
| `reset_active_low` | in | 1 | Asynchronous reset, active low |
| `enable` | in | 1 | Trigger. The operation starts when `enable` is **released** (see below) |
| `status_reg` | out | 5 | `{carry_out, divide_by_zero, illegal_op, zero_out, complete}` |
| `vector_result` | out | 64 | Operation result |

### `input_one_shot`

| Port | Dir | Description |
|---|---|---|
| `momentary_in` | in | Level input (connected to `enable`) |
| `clock` | in | Rising-edge clock |
| `reset_active_low` | in | Asynchronous reset, active low |
| `one_shot_out` | out | One clock-wide pulse after `momentary_in` goes high and then low |

## Operation protocol and timing

1. Drive `vector_a`, `vector_b` and `op_code`.
2. Assert `enable` for at least one rising clock edge, then **release** it.
3. Keep `vector_a`, `vector_b` and `op_code` stable until the one-shot pulse has been
   consumed (two rising edges after `enable` falls).
4. Wait for `status_reg[0]` (`complete`) to go high, then read `vector_result` and
   the flags.
5. Do not start another operation until `complete` is high.

The one-shot fires one clock after the first rising edge that sees `enable` low, so the
trigger is on the **falling** edge of `enable`. Counting from the edge on which `one_shot_out`
is sampled high (`P0`):

| Edge | What happens |
|---|---|
| `P0` | Operands and opcode are captured. Divide-by-zero and illegal-opcode flags are decoded. `complete` is cleared. |
| `P1` | The selected operation is computed into the internal 65-bit result register. |
| `P2` | `vector_result`, `zero_out`, `carry_out` and `complete` update together. |

`status_reg` is gated by `complete`, so it reads `5'b00000` while an operation is in
flight and is only meaningful when `complete = 1`.

## Opcode table

`op_code` is the position of the name in the enum (`operation_codes`). If you add, remove
or reorder entries, the numbers below change. Opcodes `22`-`31` are illegal.

| Code | Name | `vector_result` |
|---|---|---|
| 0 | `ADD` | `a + b`, 33-bit sum (carry in bit 32) |
| 1 | `SUB` | `{32'b0, a - b}`, wrapped to 32 bits |
| 2 | `NOTA` | `~a` (32-bit) |
| 3 | `NOTB` | `~b` (32-bit) |
| 4 | `AND` | `a & b` |
| 5 | `NAND` | `~(a & b)` (32-bit) |
| 6 | `OR` | `a \| b` |
| 7 | `NOR` | `~(a \| b)` (32-bit) |
| 8 | `XOR` | `a ^ b` |
| 9 | `XNOR` | `~(a ^ b)` (32-bit) |
| 10 | `SLT` | `a < b` (0 or 1) |
| 11 | `SGT` | `a > b` (0 or 1) |
| 12 | `SLTE` | `a <= b` (0 or 1) |
| 13 | `SGTE` | `a >= b` (0 or 1) |
| 14 | `SEQU` | `a == b` (0 or 1) |
| 15 | `SNEQ` | `a != b` (0 or 1) |
| 16 | `SLR` | `a >> b[4:0]` (logical shift right) |
| 17 | `SLL` | `a << b[4:0]`, truncated to 32 bits |
| 18 | `NOP` | Holds the previous `vector_result` |
| 19 | `MULT` | `a * b`, full 64-bit unsigned product |
| 20 | `DIV` | `a / b`, unsigned quotient |
| 21 | `MOD` | `a % b`, unsigned remainder |
| 22-31 | illegal | Treated as `NOP`; `illegal_op` is raised |

All compares are unsigned. `DIV` or `MOD` with `b = 0` is treated as `NOP` and raises
`divide_by_zero`.

## Status register

`status_reg = {carry_out, divide_by_zero, illegal_op, zero_out, complete}`

| Bit | Name | Meaning (valid when `complete = 1`) |
|---|---|---|
| 4 | `carry_out` | `ADD`: carry out of the 32-bit sum (bit 32 of the result). `SUB`: borrow, set when `b > a`. 0 for every other operation. |
| 3 | `divide_by_zero` | `DIV` or `MOD` was requested with `b = 0` |
| 2 | `illegal_op` | `op_code` was 22 or higher |
| 1 | `zero_out` | `vector_result[63:0]` is all zeros |
| 0 | `complete` | The result and flags are valid |

When `divide_by_zero` or `illegal_op` is set, `vector_result` keeps its previous value
(the operation became a `NOP`) and `zero_out` describes that held value.

## Instantiation example

```systemverilog
alu_32bit u_alu (
    .vector_a         (operand_a),
    .vector_b         (operand_b),
    .op_code          (opcode),
    .clock            (clk),
    .reset_active_low (rst_n),
    .enable           (start),
    .status_reg       (alu_status),
    .vector_result    (alu_result)
);
```

`input_one_shot` is instantiated inside the ALU, so it does not need to be wired up
separately, but it must be compiled together with the ALU (it lives in the same file).

## Design notes and limitations

- **Unsigned only.** There are no signed compares, arithmetic shifts or signed
  overflow flag. See [Coming soon](#coming-soon).
- **Single-cycle `*`, `/` and `%`.** Multiply, divide and modulo are combinational
  operators that must finish in one clock cycle. Expect a long critical path and a
  large area (a full 32-bit divider) when synthesized.
- **No input synchronizer.** `enable` goes directly into the one-shot and reset release is
  not synchronized. Add two-flip-flop synchronizers if either signal comes from outside
  the clock domain.
- **No back-to-back operations.** Issue the next operation only after `complete` is high.
- **Operand hold.** Inputs must stay stable until the capture edge (`P0`).
- **Opcode numbering is positional.** Pin the values in the enum if other code drives
  `op_code` with raw numbers.

## Coming soon

The signed side of the design is being built out. The skeleton files are already in the
repository but contain no working logic yet, and their ports are placeholders that may
change.

| Block | File | Module | State |
|---|---|---|---|
| Signed ALU | `signed/alu_32bit_signed.sv` | `alu_32bit_signed` | Planned, header only |
| Signed multiplier | `signed/multiplier_unit.sv` | `multiplier_unit_signed` | Planned, skeleton only |
| Signed divider | `signed/divider_unit.sv` | `divider_unit_signed` | Planned, skeleton only |

Planned scope (subject to change): a signed counterpart to this ALU, plus standalone signed
multiply and signed divide units, along with the rest of the items in the
[Roadmap](#roadmap) below.

## Roadmap

- [ ] Signed ALU (`alu_32bit_signed`)
- [ ] Signed multiplier unit (`multiplier_unit_signed`)
- [ ] Signed divider unit (`divider_unit_signed`)
- [ ] Testbench coverage (`tb_alu_32b.sv`): all 22 opcodes, corner cases, divide-by-zero,
      illegal opcodes and flag alignment, checked against a reference model
- [ ] Document simulation results, then run a lint and synthesis pass (for example Yosys)
      and record area and timing against `timingfile.sdc`
- [ ] Sequential radix-4 Booth multiplier and sequential divider to replace the
      combinational `*`, `/` and `%`
- [ ] Input and reset synchronizers
- [ ] Pin opcode values in the enum

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the
[`LICENSE`](LICENSE) file for the full text.