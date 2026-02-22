# RISC-V CPU for Computer Organization (CS202) - SUSTech

A complete 5-stage pipelined RISC-V CPU implementation in Verilog, targeting the EGO1 FPGA development board (Xilinx Artix-7 XC7A35TCSG324-1).

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [CPU Specifications](#cpu-specifications)
- [Pipeline Stages](#pipeline-stages)
- [Data Flow](#data-flow)
- [Key Features](#key-features)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Memory Map](#memory-map)
- [Instruction Set](#instruction-set)
- [Performance](#performance)
- [Testing](#testing)

---

## Architecture Overview

```
    ┌─────────────────────────────────────────────────────────────────────────┐
    │                        RISC-V 5-Stage Pipeline                          │
    ├─────────────────────────────────────────────────────────────────────────┤
    │                                                                         │
    │   ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐     │
    │   │ IF  │───→│ ID  │───→│ EX  │───→│ MEM │───→│ WB  │───→│ Reg │     │
    │   │     │    │     │    │     │    │     │    │     │    │File │     │
    │   └──┬──┘    └──┬──┘    └──┬──┘    └──┬──┘    └──┬──┘    └──┬──┘     │
    │      │          │          │          │          │          │         │
    │   ┌──┴──┐    ┌──┴──┐    ┌──┴──┐    ┌──┴──┐    ┌──┴──┐              │
    │   │IF/ID│    │ID/EX│    │EX/MEM│   │MEM/WB│                           │
    │   │ Reg │    │ Reg │    │ Reg  │   │ Reg  │                           │
    │   └─────┘    └─────┘    └──────┘   └──────┘                           │
    │                                                                         │
    │   ◄──────────────── Forwarding Paths (Bypass) ────────────────►        │
    │                                                                         │
    └─────────────────────────────────────────────────────────────────────────┘
```

---

## CPU Specifications

| Parameter | Value |
|-----------|-------|
| **ISA** | RV32I (Base Integer 32-bit) |
| **Pipeline Stages** | 5 (IF, ID, EX, MEM, WB) |
| **Clock Frequency** | 50 MHz (EGO1 Board) |
| **Instruction Memory** | 16KB BRAM (4K x 32-bit) |
| **Data Memory** | 16KB BRAM (4K x 32-bit) |
| **Register File** | 32 x 32-bit (x0 hardwired to 0) |
| **Branch Predictor** | BTB (32-entry) + BHT (2-bit) + RAS (8-entry) |
| **Privilege Mode** | Machine (M) Mode only |
| **Endianness** | Little-endian |

---

## Pipeline Stages

### 1. Instruction Fetch (IF)

```
┌─────────────────────────────────────────────────────────┐
│                    IF Stage                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   PC Register ──► Instruction Memory (BRAM)             │
│        │                    │                           │
│        │                    ▼                           │
│        │            ┌──────────────┐                   │
│        │            │  Instruction │                   │
│        │            └──────────────┘                   │
│        │                    │                           │
│        ▼                    ▼                           │
│   ┌──────────┐      ┌──────────┐                       │
│   │ PC + 4   │      │  IF/ID   │                       │
│   │ Logic    │      │ Pipeline │                       │
│   └──────────┘      │ Register │                       │
│                     └──────────┘                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Functions:**
- Program Counter (PC) management
- Sequential fetch (PC+4) or branch target
- Instruction memory access (combinational read)

**Inputs:**
- `pc_stall`: Stall signal from Hazard Unit
- `if_flush`: Flush signal
- `pc_redirect`: PC redirect enable
- `pc_target`: Target address for redirect

**Outputs:**
- `if_pc`: Current PC
- `if_instr`: Fetched instruction
- `if_valid`: Valid signal

---

### 2. Instruction Decode (ID)

```
┌─────────────────────────────────────────────────────────┐
│                    ID Stage                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   IF/ID Register ──► Instruction Decode                 │
│        │                    │                           │
│        │    ┌───────────────┼───────────────┐          │
│        │    ▼               ▼               ▼          │
│        │ ┌──────┐     ┌──────────┐    ┌────────┐      │
│        │ │Opcode│     │Register │    │Immediate│      │
│        │ │Funct3│     │ File   │    │Generate │      │
│        │ │Funct7│     │        │    │         │      │
│        │ └──┬───┘     └───┬────┘    └────┬────┘      │
│        │    │             │              │            │
│        │    ▼             ▼              ▼            │
│        │ Control      rs1_data      imm_out           │
│        │ Signals      rs2_data                        │
│        │    │             │                           │
│        ▼    ▼             ▼                           │
│   ┌──────────────────────────────────────┐           │
│   │           ID/EX Pipeline Register    │           │
│   └──────────────────────────────────────┘           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Functions:**
- Instruction decoding (opcode, funct3, funct7)
- Register file read (2 read ports)
- Immediate value generation
- Control signal generation

**Key Control Signals:**
| Signal | Description |
|--------|-------------|
| `alu_op` | ALU operation select |
| `alu_src_a` | ALU A source: 0=rs1, 1=PC |
| `alu_src_b` | ALU B source: 0=rs2, 1=imm |
| `mem_read` | Data memory read enable |
| `mem_write` | Data memory write enable |
| `reg_write` | Register write enable |
| `mem_to_reg` | WB source: 0=ALU, 1=Mem |
| `branch` | Branch instruction |
| `jump` | Jump instruction |

---

### 3. Execute (EX)

```
┌─────────────────────────────────────────────────────────┐
│                    EX Stage                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ID/EX Register ────────────────────┐                  │
│        │                             │                  │
│        ▼                             ▼                  │
│   ┌──────────┐                 ┌──────────┐            │
│   │ Forward  │                 │  ALU     │            │
│   │Mux (rs1) │────────────────►│          │            │
│   └──────────┘                 │ Operation│            │
│        ▲                       │          │            │
│        │                       └───┬──────┘            │
│   ┌──────────┐                     │                   │
│   │ Forward  │                     ▼                   │
│   │Mux (rs2) │────────────────► Result/Branch          │
│   └──────────┘                     │                   │
│        ▲                           │                   │
│        │                       ┌──────────┐            │
│   Hazard Unit                  │  Branch  │            │
│   (Forwarding)                 │Compare/Jump│          │
│                                └──────────┘            │
│                                     │                   │
│                                     ▼                   │
│   ┌──────────────────────────────────────┐            │
│   │          EX/MEM Pipeline Register    │            │
│   └──────────────────────────────────────┘            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Functions:**
- ALU operations (arithmetic, logical, shift, compare)
- Branch/Jump target calculation
- Branch condition evaluation
- Data forwarding from MEM/WB stages
- Exception detection

**Forwarding Sources:**
| Forward Signal | Source | Latency |
|----------------|--------|---------|
| `forward_a/b = 00` | Register File | 0 cycle |
| `forward_a/b = 01` | WB stage | 0 cycle |
| `forward_a/b = 10` | MEM stage | 0 cycle |

---

### 4. Memory Access (MEM)

```
┌─────────────────────────────────────────────────────────┐
│                   MEM Stage                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   EX/MEM Register ──► Address/Data                      │
│        │                    │                           │
│        │    ┌───────────────┴───────────────┐          │
│        │    ▼                               ▼          │
│        │ ┌──────────┐                 ┌──────────┐     │
│        │ │  Data    │                 │   IO     │     │
│        │ │  BRAM    │                 │Controller│     │
│        │ │          │                 │          │     │
│        │ │ Read/Write│                │ UART/VGA │     │
│        │ │ Alignment │                │ Keyboard │     │
│        │ └──────────┘                 └──────────┘     │
│        │       │                             │         │
│        │       ▼                             ▼         │
│        │  Load Data                     IO Data        │
│        │  (Sign/Zero Ext)                              │
│        │       │                             │         │
│        └───────┴─────────────┬───────────────┘         │
│                              ▼                         │
│                    ┌──────────────────┐                │
│                    │  Write-back Data │                │
│                    └──────────────────┘                │
│                              │                         │
│                              ▼                         │
│   ┌──────────────────────────────────────┐            │
│   │          MEM/WB Pipeline Register    │            │
│   └──────────────────────────────────────┘            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Functions:**
- Data memory access (BRAM)
- IO device access (UART, VGA, Keyboard)
- Load data alignment and sign/zero extension
- Store data alignment

**Memory Access Types:**
| Funct3 | Instruction | Size | Extension |
|--------|-------------|------|-----------|
| 000 | LB | Byte | Signed |
| 001 | LH | Half-word | Signed |
| 010 | LW | Word | - |
| 100 | LBU | Byte | Unsigned |
| 101 | LHU | Half-word | Unsigned |

---

### 5. Write Back (WB)

```
┌─────────────────────────────────────────────────────────┐
│                   WB Stage                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   MEM/WB Register ──► Write-back Data Select            │
│        │                    │                           │
│        │    ┌───────────────┴───────────────┐          │
│        │    ▼                               ▼          │
│        │ ┌──────────┐                 ┌──────────┐     │
│        │ │  ALU     │                 │  Memory  │     │
│        │ │ Result   │                 │   Data   │     │
│        │ │          │                 │          │     │
│        │ └──────────┘                 └──────────┘     │
│        │       │                             │         │
│        │       └─────────────┬───────────────┘         │
│        │                     ▼                         │
│        │              ┌────────────┐                   │
│        │              │   Mux      │                   │
│        │              │(mem_to_reg)│                   │
│        │              └─────┬──────┘                   │
│        │                    │                          │
│        ▼                    ▼                          │
│   ┌──────────────────────────────────────┐            │
│   │         Register File Write          │            │
│   │     (rd_addr, rd_data, we)           │            │
│   └──────────────────────────────────────┘            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Functions:**
- Select write-back data source (ALU result or Memory data)
- Write to register file

---

## Data Flow

### Typical R-type Instruction Flow

```
Cycle:    1      2      3      4      5      6
          │      │      │      │      │      │
ADD x1, x2, x3
          │      │      │      │      │      │
IF  ─────► ID ──► EX ──► MEM ─► WB
               │      │      │      │
               │      │  ALU │      │
               │      │  x2+x3      │
               │      │      │      │
               │      │      │   Write x1
               │      │      │      │
```

### Load-Use Hazard (with Stall)

```
Cycle:    1      2      3      4      5      6      7
          │      │      │      │      │      │      │
LW  x1, 0(x2)
          │      │      │      │      │      │      │
IF  ─────► ID ──► EX ──► MEM ─► WB
               │      │      │      │
               │  Load│ Addr │ Data │ Write x1
               │      │      │      │
ADD x3, x1, x4
               │      │      │      │      │
               IF ───► ID ───► STALL ► EX ──► MEM
                        │             │
                        │ Hazard      │ Forward x1
                        │ Detected    │ from WB
```

### Branch with Prediction

```
Correct Prediction:
Cycle:    1      2      3      4      5
          │      │      │      │      │
BEQ x1, x2, target  (Predicted Taken)
          │      │      │      │      │
IF  ─────► ID ──► EX ──► MEM (Branch Resolved)
               │      │      │
Predicted Target ────► IF ──► ID
               (0 cycle penalty)

Misprediction:
Cycle:    1      2      3      4      5      6
          │      │      │      │      │      │
BEQ x1, x2, target  (Predicted Taken, Actually Not Taken)
          │      │      │      │      │      │
IF  ─────► ID ──► EX ──► MEM (Branch Resolved)
               │      │      │      │
Predicted Target ────► IF ──► ID ──► FLUSH
               │      │      │
               │      │  PC+4 ───► IF ──► ID
               │      │      (2 cycle penalty)
```

---

## Key Features

### 1. Hazard Handling

| Hazard Type | Detection | Resolution |
|-------------|-----------|------------|
| **Data (RAW)** | ID stage compares registers | Forwarding from EX/MEM/WB |
| **Load-Use** | ID stage detects load→use | 1 cycle stall + forwarding |
| **Control** | EX stage evaluates branch | Flush IF/ID on mispredict |
| **Structural** | MEM stage IO access | Stall pipeline |

### 2. Branch Prediction

```
┌─────────────────────────────────────────────────────────┐
│              Branch Prediction Unit                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌──────────────┐    ┌──────────────┐                 │
│   │     BTB      │    │     BHT      │                 │
│   │  (32-entry)  │    │ (128-entry)  │                 │
│   │              │    │ 2-bit satur. │                 │
│   │ Tag + Target │    │   counter    │                 │
│   └──────┬───────┘    └──────┬───────┘                 │
│          │                   │                         │
│          └─────────┬─────────┘                         │
│                    ▼                                   │
│            ┌──────────────┐                           │
│            │   Predicted  │                           │
│            │    Target    │                           │
│            └──────────────┘                           │
│                                                         │
│   ┌──────────────┐                                    │
│   │     RAS      │    (Return Address Stack)          │
│   │  (8-entry)   │    for function returns            │
│   └──────────────┘                                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Accuracy:** ~90%+ for typical code patterns

### 3. Exception & Interrupt Handling

```
┌─────────────────────────────────────────────────────────┐
│              Trap Handling Flow                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   Exception/Interrupt detected in EX/MEM stage          │
│                    │                                    │
│                    ▼                                    │
│   ┌────────────────────────────────────┐               │
│   │ 1. Save current PC to MEPC         │               │
│   │ 2. Set MCAUSE (exception code)     │               │
│   │ 3. Save MTVAL (faulting address)   │               │
│   │ 4. MPP = current privilege         │               │
│   │ 5. MPIE = MIE, MIE = 0             │               │
│   └────────────────────────────────────┘               │
│                    │                                    │
│                    ▼                                    │
│   ┌────────────────────────────────────┐               │
│   │ 6. PC = MTVEC (trap vector base)   │               │
│   │    (or MTVEC + 4*cause if vectored)│               │
│   └────────────────────────────────────┘               │
│                    │                                    │
│                    ▼                                    │
│   Execute trap handler                                  │
│                    │                                    │
│                    ▼                                    │
│   MRET instruction                                      │
│   ┌────────────────────────────────────┐               │
│   │ 1. PC = MEPC                       │               │
│   │ 2. MIE = MPIE                      │               │
│   │ 3. Privilege = MPP                 │               │
│   └────────────────────────────────────┘               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4. IO Subsystem

```
┌─────────────────────────────────────────────────────────┐
│                 IO Memory Map                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   0x1000_0000 - 0x1000_0FFF    UART Controller          │
│   ├─ 0x0000: TX/RX Data                                 │
│   ├─ 0x0004: Status (TX ready, RX valid)                │
│   └─ 0x0008: Baud rate divisor                          │
│                                                         │
│   0x1000_1000 - 0x1000_1FFF    GPIO                     │
│   ├─ 0x0000: Switches input (16-bit)                    │
│   ├─ 0x0004: Buttons input (4-bit)                      │
│   ├─ 0x0008: LEDs output (16-bit)                       │
│   └─ 0x000C: 7-segment display                          │
│                                                         │
│   0x1000_2000 - 0x1000_2FFF    Timer                    │
│   ├─ 0x0000: Counter                                    │
│   ├─ 0x0004: Compare value                              │
│   └─ 0x0008: Control (enable, interrupt)                │
│                                                         │
│   0x1000_3000 - 0x1000_3FFF    VGA Controller           │
│   ├─ 0x0000: Framebuffer address                        │
│   ├─ 0x0004: Control                                    │
│   └─ 0x0008: Color data                                 │
│                                                         │
│   0x1000_4000 - 0x1000_4FFF    PS/2 Keyboard            │
│   ├─ 0x0000: Scan code                                  │
│   └─ 0x0004: Status (data ready)                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
A-RISC-V-CPU-for-Computer-Organization-CS202-in-SUSTech/
├── src/
│   ├── core/                    # Core modules
│   │   ├── defines.v            # Global constants (macros)
│   │   ├── ALU.v                # Arithmetic Logic Unit
│   │   ├── Hazard_Unit.v        # Hazard detection & forwarding
│   │   ├── Trap_Unit.v          # Exception/interrupt handling
│   │   ├── DMA_Controller.v     # Direct Memory Access
│   │   └── IO_Controller.v      # IO subsystem
│   │
│   ├── pipeline/                # 5 Pipeline Stages (Unified Naming)
│   │   ├── if_stage.v           # Instruction Fetch
│   │   ├── id_stage.v           # Instruction Decode
│   │   ├── ex_stage.v           # Execute
│   │   ├── mem_stage.v          # Memory Access
│   │   ├── wb_stage.v           # Write Back
│   │   └── regfile.v            # Register File
│   │
│   ├── memory/                  # Memory modules
│   │   ├── inst_bram.v          # Instruction BRAM
│   │   └── data_bram.v          # Data BRAM
│   │
│   └── riscv_cpu_top.v          # Top-level module
│
├── constraints/
│   └── ego1.xdc                 # EGO1 FPGA pin constraints
│
├── software/                    # Test programs
│   ├── test_basic.s             # Assembly test suite
│   ├── test_c.c                 # C test program
│   ├── crt0.s                   # C runtime startup
│   ├── linker.ld                # Linker script
│   └── Makefile
│
└── README.md                    # This file
```

---

## Quick Start

### 1. Hardware Synthesis (Vivado)

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

### 2. Software Compilation

```bash
cd software

# Compile assembly test
riscv32-unknown-elf-as -march=rv32i test_basic.s -o test_basic.o
riscv32-unknown-elf-ld -T linker.ld test_basic.o -o test_basic.elf
riscv32-unknown-elf-objcopy -O verilog test_basic.elf test_basic.hex

# Or use Makefile
make test_basic.hex
make test_c.hex
```

### 3. Load Program to BRAM

```verilog
// In inst_bram.v, update INIT_FILE parameter:
inst_bram #(
    .ADDR_WIDTH(14),
    .INIT_FILE("software/test_basic.hex")
) inst_mem (...);
```

---

## Memory Map

| Address Range | Size | Description |
|---------------|------|-------------|
| 0x0000_0000 - 0x0000_3FFF | 16KB | Instruction Memory (BRAM) |
| 0x0000_4000 - 0x0000_7FFF | 16KB | Data Memory (BRAM) |
| 0x1000_0000 - 0x1000_0FFF | 4KB | UART |
| 0x1000_1000 - 0x1000_1FFF | 4KB | GPIO |
| 0x1000_2000 - 0x1000_2FFF | 4KB | Timer |
| 0x1000_3000 - 0x1000_3FFF | 4KB | VGA |
| 0x1000_4000 - 0x1000_4FFF | 4KB | Keyboard |
| 0x1000_5000 - 0x1000_5FFF | 4KB | DMA Controller |
| 0x0200_0000 - 0x0200_BFFF | 48KB | CLINT (Timer + Software IRQ) |

---

## Instruction Set

### RV32I Base Integer (Complete)

| Category | Instructions |
|----------|--------------|
| **Arithmetic** | ADD, ADDI, SUB, LUI, AUIPC |
| **Logical** | AND, ANDI, OR, ORI, XOR, XORI |
| **Shift** | SLL, SLLI, SRL, SRLI, SRA, SRAI |
| **Compare** | SLT, SLTI, SLTU, SLTIU |
| **Branch** | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| **Jump** | JAL, JALR |
| **Load** | LB, LH, LW, LBU, LHU |
| **Store** | SB, SH, SW |
| **System** | FENCE, ECALL, EBREAK |
| **CSR** | CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI |
| **Privileged** | MRET, WFI |

---

## Performance

| Metric | Value | Notes |
|--------|-------|-------|
| **Clock Frequency** | 50 MHz | EGO1 board |
| **CPI (avg)** | ~1.2 | With branch prediction |
| **DMIPS/MHz** | ~0.8 | Dhrystone benchmark |
| **Branch Penalty** | 2 cycles | On misprediction |
| **Load-Use Stall** | 1 cycle | + forwarding |

---

## Testing

### Simulation Testbench

See `sim/` directory for testbench files.

### FPGA Testing

1. **LED Test**: Program outputs alternating pattern on LEDs
2. **UART Test**: Connect serial terminal, should see "PASS" message
3. **Switch Test**: Toggles switches, LEDs should mirror switch state

### Debug Features

- **LEDs**: Show pipeline status or register values
- **7-Segment**: Display current PC
- **UART**: Print debug messages from software

---

## License

MIT License - See LICENSE file

## Authors

Computer Organization Course (CS202) - SUSTech

## References

1. RISC-V Instruction Set Manual, Volume I: User-Level ISA
2. RISC-V Instruction Set Manual, Volume II: Privileged Architecture  
3. Computer Organization and Design RISC-V Edition (Patterson & Hennessy)
