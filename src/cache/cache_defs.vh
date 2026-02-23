//============================================================================
// Cache Definitions
//============================================================================
`ifndef CACHE_DEFS_VH
`define CACHE_DEFS_VH

// I-Cache Parameters (1KB, Direct Mapped, 16B line)
`define ICACHE_SIZE      1024
`define ICACHE_LINE_SIZE 16
`define ICACHE_WAYS      1
`define ICACHE_SETS      64
`define ICACHE_INDEX_WIDTH 6
`define ICACHE_OFFSET_WIDTH 4
`define ICACHE_TAG_WIDTH 22

// D-Cache Parameters (1KB, Direct Mapped, 16B line)
`define DCACHE_SIZE      1024
`define DCACHE_LINE_SIZE 16
`define DCACHE_WAYS      1
`define DCACHE_SETS      64
`define DCACHE_INDEX_WIDTH 6
`define DCACHE_OFFSET_WIDTH 4
`define DCACHE_TAG_WIDTH 22

// Cache States
`define CACHE_IDLE       2'b00
`define CACHE_LOOKUP     2'b01
`define CACHE_MISS       2'b10
`define CACHE_REFILL     2'b11

`endif
