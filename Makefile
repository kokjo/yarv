CC=riscv32-unknown-elf-gcc
LD=riscv32-unknown-elf-ld
OBJCOPY=riscv32-unknown-elf-objcopy
IVERILOG=iverilog
HARDWARE=hardware.v soc.v spimemio.v simpleuart.v
SOURCES=ram.v fetch.v decode.v execute.v cache.v arb.v core.v mem_gpio.v
TESTBENCH=testbench.v rom.v

all: hardware.asc testbench.vcd hardware.bin hardware.rpt

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

firmware.hex: firmware.elf
	riscv32-unknown-elf-objcopy -O verilog firmware.elf firmware.hex

hardware.blif: $(HARDWARE) $(SOURCES)
	yosys -p 'synth_ice40 -top hardware -blif hardware.blif -json hardware.json' $(HARDWARE) $(SOURCES) 

hardware.asc: hardware.blif
	arachne-pnr -r -d 8k -P cm81 -o hardware.asc -p hardware.pcf hardware.blif

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d hx8k -c 16 -mtr $@ $<

hardware_tb: $(SOURCES) $(HARDWARE) hardware_tb.v spiflash.v #firmware.hex
	iverilog -s hardware_tb -o $@ $^ `yosys-config --datdir/ice40/cells_sim.v`

hardware_tb.vcd: hardware_tb firmware.hex
	./hardware_tb

program: hardware.bin firmware.bin
	tinyprog -p hardware.bin -u firmware.bin

clean:
	rm -rf *.vcd *.bin *.elf *.o *.asc *.blif *.rpt *.hex hardware_tb testbench rom.v

.PHONY: program clean
