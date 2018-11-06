CC=riscv32-unknown-elf-gcc
LD=riscv32-unknown-elf-ld
OBJCOPY=riscv32-unknown-elf-objcopy
IVERILOG=iverilog
HARDWARE=hardware.v soc.v spimemio.v
SOURCES=ram.v rom.v fetch.v decode.v execute.v cache.v arb.v core.v mem_gpio.v
TESTBENCH=testbench.v

all: hardware.asc testbench.vcd hardware.bin

testbench.vcd: testbench
	./testbench

testbench: $(TESTBENCH) $(SOURCES)
	iverilog -o testbench $(TESTBENCH) $(SOURCES)

rom.v: firmware.bin generate_rom.py
	python generate_rom.py firmware.bin > rom.v

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

firmware.elf: sections.lds firmware.c start.S
	$(CC) -march=rv32i -nostartfiles -Wl,-Bstatic,-T,sections.lds,--strip-debug,-Map=firmware.map,--cref -ffreestanding -nostdlib -o firmware.elf start.S firmware.c

hardware.blif: $(SOURCES)
	yosys -p 'synth_ice40 -top hardware -blif hardware.blif' $(HARDWARE) $(SOURCES) 

hardware.asc: hardware.blif
	arachne-pnr -d 8k -P cm81 -o hardware.asc -p hardware.pcf hardware.blif

hardware.bin: hardware.asc
	icetime -d hx8k -c 16 -mtr hardware.rpt hardware.asc
	icepack hardware.asc hardware.bin

clean:
	rm -rf *.vcd *.bin *.elf *.o *.asc *.blif *.rpt testbench rom.v
