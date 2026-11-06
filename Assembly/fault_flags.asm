; fault_flags.asm -- hand-written sequence for the "keep the previous result" cases and flag behaviour.
; Divide-by-zero, illegal op codes and NOP all leave the last result on the bus; their flag shows only for that op,
; and the next normal op clears it. The zero flag follows the held result.
.test FAULT_HOLD
ADD  3, 4                         ; 7
DIV  5, 0                         ; divide by zero: flag set, result stays 7
MOD  5, 0                         ; same
NOP                               ; holds 7, no flags
RAW  25, 1, 2                     ; illegal op: flag set, result stays 7
ADD  0, 0                         ; 0, zero flag
DIV  0, 0                         ; divide by zero while the held result is 0: dbz + zero
RAW  31, 0, 0                     ; illegal op, still 0
NOP                               ; still 0, zero flag
SUB  0, 1                         ; -1 (signed) / 0xFFFFFFFF (unsigned, borrow)
DIV  0x80000000, 0xFFFFFFFF       ; signed: overflow case; unsigned: 0x80000000 / 0xFFFFFFFF = 0
NOP
MULT 0xFFFFFFFF, 0xFFFFFFFF      ; signed: 1; unsigned: 0xFFFFFFFE00000001
DIV  7, 0
SLT  1, 2                         ; 1
MOD  0x80000000, 0xFFFFFFFF       ; 0 in both; no overflow flag for MOD
RAW  22, 5, 5
XOR  0xFFFFFFFF, 0xFFFFFFFF       ; 0, zero flag
NOP
ADD  0xFFFFFFFF, 1                ; signed: 0 (no overflow); unsigned: 0 with carry
ADD  0x7FFFFFFF, 1                ; signed overflow, unsigned plain
SUB  5, 7
DIV  0xFFFFFFF9, 2                ; signed -7/2 = -3; unsigned 0x7FFFFFFC
MOD  0xFFFFFFF9, 2                ; signed -1; unsigned 1
MULT 0x80000000, 2
SLL  1, 31
SLR  0x80000000, 31               ; signed arithmetic: -1; unsigned: 1
NOP
