// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

.section .text
.global reset
.global do_rdcycle
.global do_rdinstret
.global exception_handler

reset:
	/* zero-initialize all registers */

	li ra, 0
	li sp, 8192
    
    csrrw x1, mscratch, sp
    la x1, exception_handler
    csrrw x1, mtvec, x1
    ecall

    call main
loop:
    j loop

do_rdcycle:
    csrrw a0, cycle, a0
    ret

do_rdinstret:
    csrrw a0, instret, a0
    ret

exception_handler:
    csrrw x1, mscratch, x1
    csrrw x1, mepc, x1
    addi x1, x1, 4
    csrrw x1, mepc, x1
    csrrw x1, mscratch, x1
    mret
