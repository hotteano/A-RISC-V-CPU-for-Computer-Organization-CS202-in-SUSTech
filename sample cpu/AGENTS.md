# RISC-V CPU - Agent Guide

This guide provides essential information for AI agents working on this RISC-V CPU project.

## Project Overview

This is a complete 5-stage pipelined RISC-V CPU implementation in Verilog, targeting the EGO1 FPGA development board (Xilinx Artix-7 XC7A35TCSG324-1).

### Key Specifications
- **ISA**: RV32I + RV32M (Base Integer + Multiply)
- **Pipeline**: 5 stages (IF, ID, EX, MEM, WB)
- **Clock**: 50 MHz (on EGO1 board)
- **Memory**: 16KB Instruction BRAM + 16KB Data BRAM
- **Advanced Features**:
  - Tournament branch predictor (Local + Gshare) + BTB + RAS
  - Sv32 MMU with virtual memory support
  - PMP (Physical Memory Protection) with 4 regions
  - Full M-mode CSR support
  - 1KB I-Cache + 1KB D-Cache
  - 4-channel DMA controller

## Project Structure

```
├── src/
│   ├── core/              # Core modules
│   │   ├── defines.vh     # Global constants/macros
│   │   ├── ALU.v          # Arithmetic Logic Unit
│   │   ├── control_unit.v # Instruction decode & control
│   │   ├── hazard_unit.v  # Hazard detection & forwarding
│   │   ├── Trap_Unit.v    # Exception/interrupt handling
│   │   ├── DMA_Controller.v
│   │   └── IO_Controller.v
│   │
│   ├── pipeline/          # 5 Pipeline Stages
│   │   ├── if_stage.v           # Instruction Fetch
│   │   ├── if_stage_bp.v        # IF with Branch Prediction
│   │   ├── id_stage.v           # Instruction Decode
│   │   ├── ex_stage.v           # Execute
│   │   ├── mem_stage.v          # Memory Access
│   │   ├── wb_stage.v           # Write Back
│   │   └── regfile.v            # Register File (32 x 32-bit)
│   │
│   ├── memory/            # Memory modules
│   │   ├── inst_bram.v    # Instruction BRAM (16KB)
│   │   └── data_bram.v    # Data BRAM (16KB)
│   │
│   ├── utils/             # Utility modules
│   │   ├── csr_reg.v              # CSR Register Unit
│   │   ├── mmu.v                  # Memory Management Unit (Sv32)
│   │   ├── pmp.v                  # Physical Memory Protection
│   │   ├── branch_predictor.v     # Basic Branch Predictor
│   │   ├── gshare_predictor.v     # Gshare Global Predictor
│   │   ├── tournament_predictor.v # Tournament Predictor
│   │   ├── return_address_stack.v # Return Address Stack
│   │   └── advanced_branch_predictor.v
│   │
│   ├── bus/               # Bus architecture
│   │   ├── bus_arbiter.v  # Bus arbiter (round-robin)
│   │   ├── bus_decoder.v  # Address decoder
│   │   ├── bus_mux.v      # Bus multiplexer
│   │   └── dma_controller.v
│   │
│   ├── cache/             # Cache modules
│   │   ├── icache.v       # Instruction Cache (1KB)
│   │   └── dcache.v       # Data Cache (1KB, write-back)
│   │
│   ├── peripherals/       # IO peripherals
│   │   ├── ps2_controller.v   # PS/2 Keyboard/Mouse
│   │   ├── vga_controller.v   # VGA display controller
│   │   ├── uart_controller.v  # UART serial port
│   │   └── led_controller.v   # LED/GPIO controller
│   │
│   └── riscv_cpu_top.v    # Top-level module
│
├── constraints/
│   └── ego1.xdc           # EGO1 FPGA pin constraints
│
├── sim/                   # Simulation testbenches
│   ├── tb_riscv_cpu.v           # Main CPU testbench
│   ├── tb_riscv_cpu_simple.v    # Simple CPU tests
│   ├── tb_riscv_cpu_full.v      # Comprehensive tests
│   ├── tb_riscv_cpu_system.v    # System integration tests
│   ├── tb_csr_reg.v             # CSR module tests
│   ├── tb_mmu.v                 # MMU module tests
│   ├── tb_pmp.v                 # PMP module tests
│   ├── tb_branch_predictor.v    # Branch predictor tests
│   ├── tb_icache.v              # I-Cache tests
│   └── tb_dcache.v              # D-Cache tests
│
├── software/              # Test programs
│   ├── test_basic.s       # Assembly test suite
│   ├── test_c.c           # C test program
│   ├── crt0.s             # C runtime startup
│   ├── linker.ld          # Linker script
│   └── Makefile
│
├── build.bat              # Windows build script
├── run_tests.bat          # Windows test suite runner
├── test_cpu.bat           # Windows CPU test runner
└── Makefile               # Makefile for simulation (Linux/WSL)
```

## Build Commands

### Windows

```batch
# Build and run simulation
build.bat

# Run all module tests
run_tests.bat

# Run CPU tests with summary
test_cpu.bat
```

### Linux / WSL (using Makefile)

```bash
# Compile simulation
make compile

# Run simulation
make sim

# Clean build artifacts
make clean

# Compile and run (default)
make
```

### Manual Compilation (Icarus Verilog)

```bash
# Basic CPU simulation
iverilog -g2012 -Isrc/core -o sim/sim.vvp \
    src/core/defines.vh \
    src/core/ALU.v \
    src/core/control_unit.v \
    src/core/hazard_unit.v \
    src/pipeline/*.v \
    src/memory/*.v \
    src/utils/*.v \
    src/riscv_cpu_top.v \
    sim/tb_riscv_cpu.v

vvp sim/sim.vvp
```

## Testing

### Test Categories

| Testbench | Description | Status |
|-----------|-------------|--------|
| `tb_riscv_cpu_simple.v` | CPU integration (ADD, MUL, BEQ, Load-Use) | ✅ 4/4 Pass |
| `tb_csr_reg.v` | CSR module tests | ✅ 22/22 Pass |
| `tb_pmp.v` | PMP module tests | ✅ 33/33 Pass |
| `tb_mmu.v` | MMU module tests | ⚠️ Partial |
| `tb_branch_predictor.v` | Branch predictor tests | ✅ 4/5 Pass |
| `tb_icache.v` | I-Cache tests | ✅ 4/4 Pass |
| `tb_dcache.v` | D-Cache tests | ✅ 4/4 Pass |
| `tb_riscv_cpu_system.v` | System integration | ✅ 11/11 Pass |

### Running Individual Tests

```bash
# CSR tests
iverilog -o sim/tb_csr_reg.vvp -I src src/utils/csr_reg.v sim/tb_csr_reg.v
vvp sim/tb_csr_reg.vvp

# PMP tests
iverilog -o sim/tb_pmp.vvp -I src src/utils/pmp.v sim/tb_pmp.v
vvp sim/tb_pmp.vvp

# MMU tests
iverilog -o sim/tb_mmu.vvp -I src src/utils/mmu.v sim/tb_mmu.v
vvp sim/tb_mmu.vvp
```

## Memory Map

| Address Range | Size | Description |
|---------------|------|-------------|
| 0x0000_0000 - 0x0000_3FFF | 16KB | Instruction Memory (BRAM) |
| 0x0000_4000 - 0x0000_7FFF | 16KB | Data Memory (BRAM) |
| 0x1000_0000 - 0x1000_0FFF | 4KB | UART Controller |
| 0x1000_1000 - 0x1000_1FFF | 4KB | GPIO/LED Controller |
| 0x1000_2000 - 0x1000_2FFF | 4KB | Timer |
| 0x1000_3000 - 0x1000_3FFF | 4KB | VGA Controller |
| 0x1000_4000 - 0x1000_4FFF | 4KB | PS/2 Keyboard |
| 0x1000_5000 - 0x1000_5FFF | 4KB | DMA Controller |
| 0x0200_0000 - 0x0200_BFFF | 48KB | CLINT |

## Coding Style Guidelines

### Verilog Conventions

1. **File Naming**: Use `snake_case.v` for module files
2. **Module Naming**: Use `snake_case` for module names
3. **Parameter Naming**: Use `UPPER_CASE` for parameters and localparams
4. **Signal Naming**:
   - Inputs: suffix with `_i` (e.g., `clk_i`, `rst_n_i`)
   - Outputs: suffix with `_o` (e.g., `result_o`)
   - Wires: use `snake_case`
   - Active-low signals: prefix with `_n` (e.g., `rst_n`)

5. **Clock and Reset**:
   - Clock: `clk` (positive edge triggered)
   - Reset: `rst_n` (active low, asynchronous)

6. **Pipeline Registers**: Use stage prefix
   - IF stage outputs: `if_xxx`
   - ID stage outputs: `id_xxx`
   - Pipeline registers: `if_id_xxx`, `id_ex_xxx`, etc.

### Example Module Structure

```verilog
`timescale 1ns / 1ps
`include "defines.vh"

module module_name (
    input  wire        clk,
    input  wire        rst_n,
    // Inputs
    input  wire [31:0] data_i,
    input  wire        valid_i,
    // Outputs
    output reg  [31:0] result_o,
    output wire        ready_o
);

// Parameters
parameter WIDTH = 32;

// Internal signals
wire [WIDTH-1:0] internal_wire;
reg  [WIDTH-1:0] internal_reg;

// Combinational logic
assign internal_wire = data_i + 1;
assign ready_o = valid_i;

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        internal_reg <= {WIDTH{1'b0}};
    end else begin
        internal_reg <= internal_wire;
    end
end

// Output assignment
always @(*) begin
    result_o = internal_reg;
end

endmodule
```

## FPGA Synthesis (Vivado)

```tcl
# Create project
create_project riscv_cpu ./riscv_cpu -part xc7a35tcsg324-1

# Add source files
add_files [glob ./src/core/*.v ./src/pipeline/*.v ./src/memory/*.v]
add_files ./src/riscv_cpu_top.v

# Add constraints
add_files -fileset constrs_1 ./constraints/ego1.xdc

# Run synthesis and implementation
launch_runs synth_1 -jobs 4
launch_runs impl_1 -to_step write_bitstream -jobs 4
```

## Common Tasks

### Adding a New Module

1. Create file in appropriate subdirectory under `src/`
2. Include `defines.vh` for shared constants
3. Follow naming conventions
4. Add testbench in `sim/` directory
5. Update build scripts if needed

### Modifying Pipeline Stages

1. Identify the stage file (e.g., `src/pipeline/ex_stage.v`)
2. Update pipeline register interface if needed
3. Update hazard unit if new forwarding paths are added
4. Update control unit if new control signals are needed
5. Run relevant tests to verify

### Adding New Instructions

1. Update `control_unit.v` to decode new opcode/funct
2. Update `ALU.v` if new operation needed
3. Update hazard detection if new hazards introduced
4. Add test cases in testbench

## Important Notes

1. **Always use `defines.vh`**: Include it at the top of each source file for consistent constants
2. **Reset handling**: Always use active-low asynchronous reset (`rst_n`)
3. **Pipeline hazards**: When modifying pipeline stages, check hazard_unit.v for required updates
4. **Testing**: Every module should have a corresponding testbench
5. **FPGA target**: Design targets 50MHz on Artix-7; be mindful of timing constraints

## Dependencies

### Required Tools
- **Icarus Verilog**: For simulation (`iverilog`, `vvp`)
- **GTKWave**: For waveform viewing (optional)
- **Xilinx Vivado**: For FPGA synthesis and bitstream generation
- **RISC-V GCC**: For compiling test programs (`riscv32-unknown-elf-gcc`, `riscv32-unknown-elf-as`)

### Verilog Version
- Use SystemVerilog-2012 (`-g2012` flag)
- Use `*.v` extension for all Verilog files
