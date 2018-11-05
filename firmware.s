.section .text
_start:
li x1, 0x01000000
loop:
    mv x4, x0
    lw x4, 0(x1)
    addi x4, x4, 1
    sw x4, 0(x1)
    jal x0, loop
