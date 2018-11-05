CC=riscv32-unknown-elf-gcc
LD=riscv32-unknown-elf-ld
OBJCOPY=riscv32-unknown-elf-objcopy
IVERILOG=iverilog

SOURCES=ram.v rom.v fetch.v decode.v execute.v cache.v arb.v core.v
TESTBENCH=testbench.v

testbench.vcd: testbench
	./testbench

testbench: $(TESTBENCH) $(SOURCES)
	iverilog -o testbench $(TESTBENCH) $(SOURCES)

rom.v: firmware.bin generate_rom.py
	python generate_rom.py firmware.bin > rom.v

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

firmware.elf: firmware.o
	$(LD) -o firmware.elf firmware.o

firmware.o: firmware.s
	$(CC) -o firmware.o -c firmware.s
