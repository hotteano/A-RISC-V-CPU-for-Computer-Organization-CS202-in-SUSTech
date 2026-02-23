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
| **ISA** | RV32I + RV32M (Base Integer + Multiply) |
| **Pipeline Stages** | 5 (IF, ID, EX, MEM, WB) |
| **Clock Frequency** | 50 MHz (EGO1 Board) |
| **Instruction Memory** | 16KB BRAM (4K x 32-bit) |
| **Data Memory** | 16KB BRAM (4K x 32-bit) |
| **Register File** | 32 x 32-bit (x0 hardwired to 0) |
| **Branch Predictor** | Tournament (Local + Gshare) + BTB + RAS |
| **Privilege Modes** | M-mode, S-mode, U-mode |
| **CSR Support** | Full M-mode CSR support |
| **MMU** | Sv32 page-based virtual memory |
| **PMP** | 4-region Physical Memory Protection |
| **Bus Architecture** | Wishbone-compatible with arbiter |
| **DMA** | 4-channel DMA controller |
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

### 8. Advanced Branch Prediction

```
┌─────────────────────────────────────────────────────────┐
│         Advanced Branch Prediction Unit                 │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐   │
│  │           Tournament Predictor                  │   │
│  │  ┌──────────────┐      ┌──────────────────┐    │   │
│  │  │   Local      │      │  Global (Gshare) │    │   │
│  │  │  Predictor   │      │    Predictor     │    │   │
│  │  │  BHT + PHT   │      │  GHR + PHT       │    │   │
│  │  └──────┬───────┘      └────────┬─────────┘    │   │
│  │         │                       │              │   │
│  │         └───────────┬───────────┘              │   │
│  │                     ▼                          │   │
│  │              ┌────────────┐                    │   │
│  │              │  Chooser   │                    │   │
│  │              └─────┬──────┘                    │   │
│  └────────────────────┼──────────────────────────┘   │
│                       │                              │
│  ┌────────────────────┼──────────────────────────┐   │
│  │         BTB        │    (32-entry)            │   │
│  │    (Branch Target Buffer)                     │   │
│  │         Tag + Target                          │   │
│  └────────────────────┼──────────────────────────┘   │
│                       │                              │
│  ┌────────────────────┼──────────────────────────┐   │
│  │         RAS        │    (8-entry)             │   │
│  │  (Return Address Stack)                       │   │
│  └────────────────────┼──────────────────────────┘   │
│                       ▼                              │
│              Final Prediction                        │
└──────────────────────────────────────────────────────┘
```

**Components:**
- **Tournament Predictor**: Combines Local (per-branch history) and Global (Gshare with GHR) predictors with a chooser
- **BTB**: 32-entry Branch Target Buffer for target addresses  
- **RAS**: 8-entry Return Address Stack for function returns
- **Gshare**: Global History Register (GHR) with Pattern History Table (PHT)

**Accuracy:** ~92-95% for typical code patterns

### 3. CSR (Control and Status Registers) Unit

```
┌─────────────────────────────────────────────────────────┐
│              CSR Unit Architecture                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌──────────────┐    ┌──────────────┐                 │
│   │   ID Stage   │    │   MEM Stage  │                 │
│   │  (CSR r/w)   │    │ (Exceptions) │                 │
│   └──────┬───────┘    └──────┬───────┘                 │
│          │                   │                         │
│          ▼                   ▼                         │
│   ┌────────────────────────────────────┐              │
│   │           CSR Register File        │              │
│   ├────────────────────────────────────┤              │
│   │  mstatus  │ mie       │ mip        │              │
│   │  mepc     │ mcause    │ mtval      │              │
│   │  mtvec    │ mscratch  │ mcycle     │              │
│   │  minstret │ misa      │ medeleg    │              │
│   └────────────────────────────────────┘              │
│          │                   │                         │
│          ▼                   ▼                         │
│   ┌──────────────┐    ┌──────────────┐                 │
│   │ Read Data    │    │ Trap Vector  │                 │
│   │ (to ID/EX)   │    │ (to IF)      │                 │
│   └──────────────┘    └──────────────┘                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Supported CSRs:**

| CSR | Address | Description | Access |
|-----|---------|-------------|--------|
| mstatus | 0x300 | Machine Status | R/W |
| misa | 0x301 | Machine ISA | R/O |
| medeleg | 0x302 | Exception Delegation | R/W |
| mideleg | 0x303 | Interrupt Delegation | R/W |
| mie | 0x304 | Machine Interrupt Enable | R/W |
| mtvec | 0x305 | Machine Trap Vector | R/W |
| mscratch | 0x340 | Machine Scratch | R/W |
| mepc | 0x341 | Machine Exception PC | R/W |
| mcause | 0x342 | Machine Cause | R/W |
| mtval | 0x343 | Machine Trap Value | R/W |
| mip | 0x344 | Machine Interrupt Pending | R/O |
| mcycle | 0xB00 | Machine Cycle Counter | R/W |
| minstret | 0xB02 | Machine Instructions Retired | R/W |

**Features:**
- Full CSR read/write instructions (CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI)
- 64-bit cycle and instruction counters (mcycle, minstret)
- MRET instruction for trap return
- Global interrupt enable control (MIE bit)

---

### 4. MMU (Memory Management Unit) - Sv32

```
┌─────────────────────────────────────────────────────────┐
│              MMU Architecture                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   Virtual Address (32-bit)                              │
│   ┌──────────┬──────────┬─────────────┐                │
│   │ VPN[1]   │ VPN[0]   │ Page Offset │                │
│   │ 10 bits  │ 10 bits  │  12 bits    │                │
│   └────┬─────┴────┬─────┴──────┬──────┘                │
│        │          │            │                        │
│        ▼          ▼            ▼                        │
│   SATP.PPN ──► Level 1 ──► Level 0 ──► Physical Addr   │
│                PTE         PTE                          │
│                                                         │
│   Page Table Entry (PTE) Format:                        │
│   ┌────────┬─────┬─────┬─────┬─────┬─────┬────┐        │
│   │  PPN   │ RSW │  D  │  A  │  G  │  U  │ X │        │
│   │22 bits │2bits│  1  │  1  │  1  │  1  │ 1 │        │
│   └────────┴─────┴─────┴─────┴─────┴─────┴────┘        │
│                                                         │
│   ┌─────┬────┐                                         │
│   │  W  │ R  │ V │ <- Flags                            │
│   │  1  │ 1  │ 1 │                                     │
│   └─────┴────┴───┘                                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- Sv32 page-based virtual memory (RISC-V standard)
- 4KB base page size, 4MB megapages
- Two-level page table walk
- Page fault detection (page_fault signal)
- Access permission fault detection
- Bare mode support (MMU disabled when SATP.mode = 0)
- M-mode bypass (MMU disabled in Machine mode unless MPRV=1)

**Page Table Entry Fields:**

| Bit | Name | Description |
|-----|------|-------------|
| 0 | V | Valid |
| 1 | R | Readable |
| 2 | W | Writable |
| 3 | X | Executable |
| 4 | U | User accessible |
| 5 | G | Global |
| 6 | A | Accessed |
| 7 | D | Dirty |
| 31:10 | PPN | Physical Page Number |

---

### 5. PMP (Physical Memory Protection)

```
┌─────────────────────────────────────────────────────────┐
│              PMP Architecture                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌──────────┐   ┌──────────┐   ┌──────────┐           │
│   │ pmpcfg0  │   │ pmpaddr0 │   │ Region 0 │           │
│   │ pmpcfg1  │   │ pmpaddr1 │   │ Region 1 │           │
│   │ pmpcfg2  │   │ pmpaddr2 │   │ Region 2 │           │
│   │ pmpcfg3  │   │ pmpaddr3 │   │ Region 3 │           │
│   └────┬─────┘   └────┬─────┘   └────┬─────┘           │
│        │              │              │                  │
│        └──────────────┼──────────────┘                  │
│                       ▼                                 │
│              ┌─────────────────┐                        │
│              │  Address Match  │                        │
│              │  & Permission   │                        │
│              │    Checker      │                        │
│              └────────┬────────┘                        │
│                       │                                 │
│         ┌─────────────┼─────────────┐                   │
│         ▼             ▼             ▼                   │
│      access_ok   access_fault   priv_mode               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- 4 configurable PMP regions
- Address matching modes: OFF, TOR, NA4, NAPOT
- Permission bits: Read (R), Write (W), Execute (X), Lock (L)
- Privilege-based access control:
  - M-mode: Full access unless region is locked
  - S/U-mode: Access only to configured regions with matching permissions

**Address Matching Modes:**

| Mode | Encoding | Description |
|------|----------|-------------|
| OFF | 00 | Region disabled |
| TOR | 01 | Top of Range (pmpaddr[i-1] <= addr < pmpaddr[i]) |
| NA4 | 10 | Naturally Aligned 4-byte region |
| NAPOT | 11 | Naturally Aligned Power of Two |

**PMP Configuration Register (pmpcfg):**

| Bit | Name | Description |
|-----|------|-------------|
| 0 | R | Read permission |
| 1 | W | Write permission |
| 2 | X | Execute permission |
| 4:3 | A | Address matching mode |
| 7 | L | Lock bit (enforces PMP in M-mode) |

---

### 6. Exception & Interrupt Handling

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

### 7. Bus Architecture & DMA

```
┌─────────────────────────────────────────────────────────┐
│              Bus Architecture                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌──────────┐         ┌──────────┐                    │
│   │   CPU    │◄───────►│  Bus     │◄──────┐            │
│   │ (Master) │         │ Arbiter  │       │            │
│   └──────────┘         └────┬─────┘       │            │
│                             │             │            │
│   ┌──────────┐              │      ┌──────┴──────┐     │
│   │   DMA    │◄─────────────┘      │ Bus Decoder │     │
│   │ (Master) │                     │  & Mux      │     │
│   └──────────┘                     └──────┬──────┘     │
│                                           │            │
│         ┌─────────┬─────────┬────────────┼─────────┐  │
│         ▼         ▼         ▼            ▼         ▼  │
│      ┌──────┐  ┌──────┐  ┌──────┐    ┌──────┐  ┌────┐│
│      │Mem   │  │IO    │  │VGA   │    │DMA   │  │... ││
│      │(Slave)│  │(Slave)│  │(Slave)│    │(Cfg) │  │    ││
│      └──────┘  └──────┘  └──────┘    └──────┘  └────┘│
│                                                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              DMA Controller                             │
├─────────────────────────────────────────────────────────┤
│  Features:                                              │
│  • 4 independent channels                               │
│  • Memory-to-memory, memory-to-peripheral               │
│  • Circular buffer mode                                 │
│  • Transfer complete interrupts                         │
│                                                         │
│  Registers (per channel):                               │
│  • SRC_ADDR: Source address                             │
│  • DST_ADDR: Destination address                        │
│  • SIZE: Transfer size (bytes)                          │
│  • CTRL: Control (enable, mode, direction)              │
└─────────────────────────────────────────────────────────┘
```

### 9. IO Subsystem

```
┌─────────────────────────────────────────────────────────┐
│                 IO Memory Map                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   0x1000_0000 - 0x1000_0FFF    UART Controller          │
│   ├─ 0x00: TX/RX Data (R/W)                             │
│   ├─ 0x04: Status (FIFO states)                         │
│   ├─ 0x08: Control (interrupt enable)                   │
│   └─ 0x0C: Baud rate divisor                            │
│   Features: 115200 baud default, 16-byte FIFOs           │
│                                                         │
│   0x1000_1000 - 0x1000_1FFF    LED/GPIO Controller      │
│   ├─ 0x00: LED output (16-bit, PWM support)             │
│   ├─ 0x04: LED PWM duty cycle                           │
│   ├─ 0x08: Switch input (16-bit)                        │
│   ├─ 0x0C: Button input (5-bit, debounced)              │
│   ├─ 0x20-0x2F: 7-segment display digits 0-7            │
│   └─ 0x30: 7-segment control                            │
│                                                         │
│   0x1000_2000 - 0x1000_2FFF    Timer                    │
│   ├─ 0x00: Counter                                      │
│   ├─ 0x04: Compare value                                │
│   └─ 0x08: Control (enable, interrupt)                  │
│                                                         │
│   0x1000_3000 - 0x1000_3FFF    VGA Controller           │
│   ├─ 0x00: Control (enable, mode)                       │
│   ├─ 0x04: Status (VSync flag)                          │
│   ├─ 0x08: Framebuffer base address                     │
│   ├─ 0x0C: Scroll X offset                              │
│   ├─ 0x10: Scroll Y offset                              │
│   └─ 0x20-0x5F: Color palette (256 entries, 12-bit)     │
│   Resolution: 640x480 @ 60Hz, 8-bit indexed color        │
│                                                         │
│   0x1000_4000 - 0x1000_4FFF    PS/2 Controller          │
│   ├─ 0x00: Data (R/W)                                   │
│   ├─ 0x04: Status (RX/TX FIFO state)                    │
│   └─ 0x08: Control                                      │
│   Supports: Keyboard and Mouse (configurable)            │
│                                                         │
│   0x1000_5000 - 0x1000_5FFF    DMA Configuration        │
│   ├─ 0x00-0x1F: Channel 0 registers                     │
│   ├─ 0x20-0x3F: Channel 1 registers                     │
│   ├─ 0x40-0x5F: Channel 2 registers                     │
│   ├─ 0x60-0x7F: Channel 3 registers                     │
│   └─ 0x80-0xFF: Global control/status                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
A-RISC-V-CPU-for-Computer-Organization-CS202-in-SUSTech/
├── src/
│   ├── core/                    # Core modules
│   │   ├── defines.vh           # Global constants (macros)
│   │   ├── ALU.v                # Arithmetic Logic Unit
│   │   ├── control_unit.v       # Instruction decode & control
│   │   └── hazard_unit.v        # Hazard detection & forwarding
│   │
│   ├── pipeline/                # 5 Pipeline Stages
│   │   ├── if_stage.v           # Instruction Fetch
│   │   ├── if_stage_bp.v        # Instruction Fetch with Branch Prediction
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
│   ├── utils/                   # Utility modules
│   │   ├── csr_reg.v            # CSR Register Unit
│   │   ├── mmu.v                # Memory Management Unit (Sv32)
│   │   ├── pmp.v                # Physical Memory Protection
│   │   ├── branch_predictor.v   # Basic Branch Predictor
│   │   ├── gshare_predictor.v   # Gshare Global Predictor
│   │   ├── tournament_predictor.v # Tournament Predictor
│   │   ├── return_address_stack.v # Return Address Stack
│   │   └── advanced_branch_predictor.v # Integrated BP
│   │
│   ├── bus/                     # Bus architecture
│   │   ├── bus_arbiter.v        # Bus arbiter (round-robin)
│   │   ├── bus_decoder.v        # Address decoder
│   │   ├── bus_mux.v            # Bus multiplexer
│   │   └── dma_controller.v     # DMA controller (4 channels)
│   │
│   ├── peripherals/             # IO peripherals
│   │   ├── ps2_controller.v     # PS/2 Keyboard/Mouse
│   │   ├── vga_controller.v     # VGA display controller
│   │   ├── uart_controller.v    # UART serial port
│   │   └── led_controller.v     # LED/GPIO controller
│   │
│   └── riscv_cpu_top.v          # Top-level module
│
├── constraints/
│   └── ego1.xdc                 # EGO1 FPGA pin constraints
│
├── sim/                         # Simulation testbenches
│   ├── tb_riscv_cpu.v           # CPU testbench
│   ├── tb_system.v              # System-level test
│   ├── tb_csr_reg.v             # CSR module testbench
│   ├── tb_mmu.v                 # MMU module testbench
│   ├── tb_pmp.v                 # PMP module testbench
│   ├── tb_branch_predictor.v    # Branch predictor testbench
│   └── tb_dma.v                 # DMA controller testbench
│
├── software/                    # Test programs
│   ├── test_basic.s             # Assembly test suite
│   ├── test_c.c                 # C test program
│   ├── crt0.s                   # C runtime startup
│   ├── linker.ld                # Linker script
│   └── Makefile
│
├── build.bat                    # Windows build script
├── Makefile                     # Makefile for simulation
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

The `sim/` directory contains testbenches for CPU and individual modules:

| Testbench | Description | Status |
|-----------|-------------|--------|
| `tb_riscv_cpu.v` | CPU integration testbench | ✅ Pass |
| `tb_system.v` | System-level test with CSR instructions | ✅ Pass |
| `tb_csr_reg.v` | CSR module tests (read/write, exceptions, interrupts) | ✅ 22/22 Pass |
| `tb_mmu.v` | MMU module tests (page table walk, faults) | ⚠️ Partial |
| `tb_pmp.v` | PMP module tests (TOR, NAPOT, permissions) | ✅ 33/33 Pass |
| `tb_branch_predictor.v` | Branch predictor tests (BTB, Tournament, RAS) | ✅ 4/5 Pass |
| `tb_dma.v` | DMA controller tests | 🆕 New |

**Running Tests:**

```bash
# Run all tests
make test

# Run individual module tests
iverilog -o sim/tb_csr_reg.vvp -I src src/utils/csr_reg.v sim/tb_csr_reg.v
vvp sim/tb_csr_reg.vvp

iverilog -o sim/tb_mmu.vvp -I src src/utils/mmu.v sim/tb_mmu.v
vvp sim/tb_mmu.vvp

iverilog -o sim/tb_pmp.vvp -I src src/utils/pmp.v sim/tb_pmp.v
vvp sim/tb_pmp.vvp
```

### Module Test Coverage

#### CSR Tests (`tb_csr_reg.v`)
- ✅ Read-only CSRs (MISA, MVENDORID, MARCHID, MIMPID, MHARTID)
- ✅ MSCRATCH read/write operations
- ✅ MTVEC alignment enforcement
- ✅ CSRRS (set bits) and CSRRC (clear bits) operations
- ✅ MSTATUS read/write
- ✅ Cycle counter (MCYCLE) increment
- ✅ Exception handling (MEPC, MCAUSE, MTVAL)
- ✅ MRET instruction
- ✅ Interrupt detection with MIE/MIP

#### MMU Tests (`tb_mmu.v`)
- ✅ Bare mode (MMU disabled)
- ✅ Sv32 mode with 4KB page translation
- ✅ Page fault detection (invalid PTE)
- ✅ Access fault detection (permission violations)
- ✅ Megapage (4MB) support
- ✅ M-mode bypass
- ✅ MPRV (Modify Privilege) mode
- ✅ Two-level page table walk

#### PMP Tests (`tb_pmp.v`)
- ✅ M-mode bypass (no PMP regions)
- ✅ U-mode with no PMP regions (all denied)
- ✅ NA4 mode (4-byte region)
- ✅ TOR mode (Top of Range)
- ✅ NAPOT mode (Power of 2 region)
- ✅ M-mode with locked regions
- ✅ Multiple matching regions (first match wins)
- ✅ S-mode access control

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
