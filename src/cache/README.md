# RISC-V CPU Cache Subsystem

## Overview

This directory contains the instruction cache (I-Cache) and data cache (D-Cache) implementation for the RISC-V CPU.

## Features

### I-Cache (Instruction Cache)
- **Size**: 1KB
- **Line Size**: 16 bytes
- **Organization**: Direct mapped
- **Sets**: 64
- **Policy**: Read-only, Write-allocate on miss
- **Refill**: 4-cycle burst (4 x 32-bit words)

### D-Cache (Data Cache)
- **Size**: 1KB
- **Line Size**: 16 bytes
- **Organization**: Direct mapped
- **Sets**: 64
- **Policy**: Write-back (with dirty bit), Write-allocate on miss
- **Refill**: 4-cycle burst (4 x 32-bit words)
- **Byte-wise Write**: Supported via write strobe

## File Structure

```
cache/
├── cache_defs.vh    - Cache parameter definitions
├── icache.v         - Instruction Cache implementation
├── dcache.v         - Data Cache implementation
└── README.md        - This file
```

## Cache Line Format

```
Address breakdown (32-bit):
[31:10] - Tag (22 bits)
[9:4]   - Index (6 bits) - selects one of 64 sets
[3:0]   - Offset (4 bits) - selects byte within 16-byte line
```

## Interface

### I-Cache Interface
```verilog
// CPU Interface
input  [31:0] cpu_addr;      // Request address
output [31:0] cpu_rdata;     // Read data (32-bit word)
input         cpu_re;        // Read enable
output        cpu_ready;     // Data ready (hit or refill complete)

// Memory Interface
output [31:0] mem_addr;      // Memory request address
input  [31:0] mem_rdata;     // Memory read data
output        mem_re;        // Memory read enable
input         mem_ready;     // Memory data ready
```

### D-Cache Interface
```verilog
// CPU Interface
input  [31:0] cpu_addr;      // Request address
input  [31:0] cpu_wdata;     // Write data
output [31:0] cpu_rdata;     // Read data
input         cpu_we;        // Write enable
input         cpu_re;        // Read enable
output        cpu_ready;     // Data ready
input  [3:0]  cpu_wstrb;     // Write strobe (byte-wise enable)

// Memory Interface
output [31:0] mem_addr;
output [31:0] mem_wdata;
input  [31:0] mem_rdata;
output        mem_we;
output        mem_re;
input         mem_ready;
```

## Testing

### Running Tests

```bash
# I-Cache test
cd sim
iverilog -g2012 -o tb_icache.vvp -I ../src -I ../src/cache ../src/cache/icache.v tb_icache.v
vvp tb_icache.vvp

# D-Cache test
iverilog -g2012 -o tb_dcache.vvp -I ../src -I ../src/cache ../src/cache/dcache.v tb_dcache.v
vvp tb_dcache.vvp
```

### Test Results

| Test | Description | Status |
|------|-------------|--------|
| I-Cache Cold Miss | First access miss and refill | ✅ Pass |
| I-Cache Hit | Same line access (hit) | ✅ Pass |
| I-Cache Multi-set | Different sets | ✅ Pass |
| D-Cache Read Miss | First read miss | ✅ Pass |
| D-Cache Read Hit | Same line read hit | ✅ Pass |
| D-Cache Write Hit | Write to cached line | ✅ Pass |
| D-Cache Read-After-Write | Verify write | ✅ Pass |

## Integration

To integrate caches with the CPU:

1. Instantiate `icache` between IF stage and instruction memory
2. Instantiate `dcache` between MEM stage and data memory
3. Connect `cpu_ready` signals to pipeline stall logic
4. Handle cache miss stalls in the hazard unit

## Future Improvements

- Multi-way set associative (2-way or 4-way)
- LRU replacement policy
- Victim buffer for reduced miss penalty
- Cache coherence support (for multi-core)
- Lock-down cache for critical code/data
