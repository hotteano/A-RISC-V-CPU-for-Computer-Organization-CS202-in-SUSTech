################################################################################
# Makefile for RISC-V Software
# Target: RV32I (no compressed instructions)
################################################################################

# Toolchain (RISC-V GNU Toolchain)
PREFIX = riscv32-unknown-elf
CC = $(PREFIX)-gcc
AS = $(PREFIX)-as
LD = $(PREFIX)-ld
OBJCOPY = $(PREFIX)-objcopy
OBJDUMP = $(PREFIX)-objdump
SIZE = $(PREFIX)-size

# Flags
CFLAGS = -march=rv32i -mabi=ilp32 -O2 -Wall -nostdlib -ffreestanding
ASFLAGS = -march=rv32i -mabi=ilp32
LDFLAGS = -T linker.ld -nostdlib

# Source files
C_SOURCES = $(wildcard *.c)
ASM_SOURCES = $(wildcard *.s)
OBJECTS = $(C_SOURCES:.c=.o) $(ASM_SOURCES:.s=.o)

# Default target
all: test_basic.hex test_c.hex

# Assembly test
test_basic.elf: test_basic.s linker.ld
	$(AS) $(ASFLAGS) -o test_basic.o $<
	$(LD) $(LDFLAGS) -o $@ test_basic.o

# C test
test_c.elf: test_c.c crt0.s linker.ld
	$(CC) $(CFLAGS) -c test_c.c -o test_c.o
	$(AS) $(ASFLAGS) crt0.s -o crt0.o
	$(LD) $(LDFLAGS) -o $@ test_c.o crt0.o

# Generate hex file for FPGA BRAM initialization
%.hex: %.elf
	$(OBJCOPY) -O verilog $< $@
	$(OBJDUMP) -d $< > $*.lst
	$(SIZE) $<

# Generate binary file
%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

# Disassembly
%.lst: %.elf
	$(OBJDUMP) -d $< > $@

# Clean
clean:
	rm -f *.o *.elf *.hex *.bin *.lst

.PHONY: all clean
