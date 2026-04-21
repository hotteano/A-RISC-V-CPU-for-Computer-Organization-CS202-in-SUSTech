#============================================================================
# Makefile for RISC-V test software
#============================================================================

CROSS_COMPILE = riscv32-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
SIZE    = $(CROSS_COMPILE)size

CFLAGS  = -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -O2 -Wall
LDFLAGS = -T link.ld -Wl,--gc-sections

TARGET  = test
SRC     = test.c

.PHONY: all clean dump hex

all: $(TARGET).bin $(TARGET).hex

$(TARGET).elf: $(SRC) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRC)

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $< $@

dump: $(TARGET).elf
	$(OBJDUMP) -d $<

size: $(TARGET).elf
	$(SIZE) $<

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(TARGET).hex *.o
