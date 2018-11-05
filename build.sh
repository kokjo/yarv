#!/bin/sh
riscv32-unknown-elf-gcc -o firmware.o -c firmware.s
riscv32-unknown-elf-ld -o firmware.elf firmware.o
riscv32-unknown-elf-objcopy -O binary firmware.elf firmware.bin
python generate_rom.py firmware.bin > rom.v
iverilog testbench.v ram.v rom.v fetch.v decode.v execute.v cache.v arb.v core.v && ./a.out
