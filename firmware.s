.section .text
_start:
li x4, 1
li x5, 0
loop:
    mv x6, x4
    add x4, x4, x5
    mv x5, x6
    sw x4, 0(x0)
    jal x0, loop
