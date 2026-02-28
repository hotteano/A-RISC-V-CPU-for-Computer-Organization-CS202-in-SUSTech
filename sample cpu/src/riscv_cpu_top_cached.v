//============================================================================
// RISC-V CPU Top Module with Cache Integration
// Directly integrates I-Cache and D-Cache into existing CPU
//============================================================================
`include "defines.vh"
`include "cache/cache_defs.vh"

module riscv_cpu_top_cached (
    input  wire        clk,
    input  wire        rst_n,
    
    // External Instruction memory interface (slower, main memory)
    output wire [31:0] ext_imem_addr,
    input  wire [31:0] ext_imem_data,
    output wire        ext_imem_re,
    input  wire        ext_imem_ready,
    
    // External Data memory interface (slower, main memory)
    output wire [31:0] ext_dmem_addr,
    output wire [31:0] ext_dmem_wdata,
    input  wire [31:0] ext_dmem_rdata,
    output wire        ext_dmem_we,
    output wire        ext_dmem_re,
    input  wire        ext_dmem_ready
);

    // Internal cache-interface signals
    wire [31:0] cache_imem_addr;
    wire [31:0] cache_imem_data;
    wire        cache_imem_re;
    wire        cache_imem_ready;
    
    wire [31:0] cache_dmem_addr;
    wire [31:0] cache_dmem_wdata;
    wire [31:0] cache_dmem_rdata;
    wire        cache_dmem_we;
    wire        cache_dmem_re;
    wire        cache_dmem_ready;

    //========================================================================
    // Original CPU Core (using original riscv_cpu_top as core)
    //========================================================================
    riscv_cpu_top u_cpu_core (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(cache_imem_addr),
        .imem_data(cache_imem_data),
        .dmem_addr(cache_dmem_addr),
        .dmem_wdata(cache_dmem_wdata),
        .dmem_rdata(cache_dmem_rdata),
        .dmem_we(cache_dmem_we),
        .dmem_re(cache_dmem_re)
    );
    
    // The original CPU expects combinational memory response
    // We need to modify the IF and MEM stages to handle cache delays
    // For now, this is a placeholder showing the architecture
    
    // TODO: Modify if_stage and mem_stage to support cache_ready signals
    // For now, assume cache is always ready (hit) or stalls are handled externally
    
    assign cache_imem_ready = 1'b1;  // Placeholder
    assign cache_dmem_ready = 1'b1;  // Placeholder

    //========================================================================
    // I-Cache (currently bypassed for compatibility)
    //========================================================================
    // icache u_icache (...)
    
    //========================================================================
    // D-Cache (currently bypassed for compatibility)
    //========================================================================
    // dcache u_dcache (...)
    
    // For now, bypass cache and connect directly to external memory
    assign ext_imem_addr  = cache_imem_addr;
    assign cache_imem_data = ext_imem_data;
    assign ext_imem_re    = cache_imem_re;
    
    assign ext_dmem_addr  = cache_dmem_addr;
    assign ext_dmem_wdata = cache_dmem_wdata;
    assign cache_dmem_rdata = ext_dmem_rdata;
    assign ext_dmem_we    = cache_dmem_we;
    assign ext_dmem_re    = cache_dmem_re;

endmodule
