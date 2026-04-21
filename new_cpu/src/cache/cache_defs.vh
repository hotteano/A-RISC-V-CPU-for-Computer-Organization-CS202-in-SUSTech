//============================================================================
// Cache Definitions - I-Cache and D-Cache Parameters
//============================================================================

//----------------------------------------------------------------------------
// General Cache Parameters
//----------------------------------------------------------------------------
`define CACHE_LINE_SIZE      16       // Bytes per cache line
`define CACHE_LINE_WIDTH     128      // Bits per cache line (16 * 8)
`define CACHE_OFFSET_BITS    4        // $clog2(CACHE_LINE_SIZE)

//----------------------------------------------------------------------------
// I-Cache Parameters
//----------------------------------------------------------------------------
`define ICACHE_SETS          64       // Number of sets
`define ICACHE_WAYS          1        // Associativity (1 = direct mapped)
`define ICACHE_SIZE          1024     // Total size in bytes (64 * 16)
`define ICACHE_INDEX_BITS    6        // $clog2(ICACHE_SETS)
`define ICACHE_TAG_BITS      22       // 32 - INDEX_BITS - OFFSET_BITS

//----------------------------------------------------------------------------
// D-Cache Parameters
//----------------------------------------------------------------------------
`define DCACHE_SETS          64       // Number of sets
`define DCACHE_WAYS          1        // Associativity (1 = direct mapped)
`define DCACHE_SIZE          1024     // Total size in bytes (64 * 16)
`define DCACHE_INDEX_BITS    6        // $clog2(DCACHE_SETS)
`define DCACHE_TAG_BITS      22       // 32 - INDEX_BITS - OFFSET_BITS

//----------------------------------------------------------------------------
// Cache State Machine States
//----------------------------------------------------------------------------
`define CACHE_IDLE           3'b000
`define CACHE_LOOKUP         3'b001
`define CACHE_MISS           3'b010
`define CACHE_REFILL         3'b011
`define CACHE_WRITEBACK      3'b100
`define CACHE_DONE           3'b101

//----------------------------------------------------------------------------
// MESI-like Cache Coherence States (for future multi-core support)
//----------------------------------------------------------------------------
`define CACHE_INVALID        2'b00
`define CACHE_SHARED         2'b01
`define CACHE_EXCLUSIVE      2'b10
`define CACHE_MODIFIED       2'b11
