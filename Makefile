# RISC-V CPU Makefile

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Include path for defines.vh
INC = -Isrc/core

SRC = src/core/defines.vh \
      src/core/ALU.v \
      src/core/Hazard_Unit.v \
      src/core/Trap_Unit.v \
      src/core/DMA_Controller.v \
      src/core/IO_Controller.v \
      src/pipeline/if_stage.v \
      src/pipeline/id_stage.v \
      src/pipeline/ex_stage.v \
      src/pipeline/mem_stage.v \
      src/pipeline/wb_stage.v \
      src/pipeline/regfile.v \
      src/memory/inst_bram.v \
      src/memory/data_bram.v \
      src/riscv_cpu_top.v \
      sim/tb_riscv_cpu.v

OUTPUT = sim/sim.vvp

.PHONY: all compile sim clean

all: compile sim

compile:
	$(IVERILOG) -g2012 $(INC) -o $(OUTPUT) $(SRC)

sim: compile
	cd sim && $(VVP) sim.vvp

clean:
	rm -f $(OUTPUT) sim/*.vcd
