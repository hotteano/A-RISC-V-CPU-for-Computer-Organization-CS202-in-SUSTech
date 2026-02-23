//============================================================================
// RISC-V CPU Top Module with I-Cache and D-Cache
//============================================================================
`include "defines.vh"
`include "cache/cache_defs.vh"

module riscv_cpu_top_cache (
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction memory interface (to external memory)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    output wire        imem_re,
    input  wire        imem_ready,
    
    // Data memory interface (to external memory)
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    output wire        dmem_we,
    output wire        dmem_re,
    input  wire        dmem_ready
);

    // Internal signals between CPU and Cache
    wire [31:0] cpu_imem_addr;
    wire [31:0] cpu_imem_data;
    wire        cpu_imem_re;
    wire        cpu_imem_ready;
    
    wire [31:0] cpu_dmem_addr;
    wire [31:0] cpu_dmem_wdata;
    wire [31:0] cpu_dmem_rdata;
    wire        cpu_dmem_we;
    wire        cpu_dmem_re;
    wire        cpu_dmem_ready;

    //========================================================================
    // Core CPU (existing riscv_cpu_top without memory interface)
    //========================================================================
    riscv_cpu_core u_cpu_core (
        .clk(clk),
        .rst_n(rst_n),
        // Instruction interface (to I-Cache)
        .imem_addr(cpu_imem_addr),
        .imem_data(cpu_imem_data),
        .imem_re(cpu_imem_re),
        .imem_ready(cpu_imem_ready),
        // Data interface (to D-Cache)
        .dmem_addr(cpu_dmem_addr),
        .dmem_wdata(cpu_dmem_wdata),
        .dmem_rdata(cpu_dmem_rdata),
        .dmem_we(cpu_dmem_we),
        .dmem_re(cpu_dmem_re),
        .dmem_ready(cpu_dmem_ready)
    );

    //========================================================================
    // I-Cache
    //========================================================================
    icache u_icache (
        .clk(clk),
        .rst_n(rst_n),
        // CPU interface
        .cpu_addr(cpu_imem_addr),
        .cpu_rdata(cpu_imem_data),
        .cpu_re(cpu_imem_re),
        .cpu_ready(cpu_imem_ready),
        // Memory interface
        .mem_addr(imem_addr),
        .mem_rdata(imem_data),
        .mem_re(imem_re),
        .mem_ready(imem_ready)
    );

    //========================================================================
    // D-Cache
    //========================================================================
    dcache u_dcache (
        .clk(clk),
        .rst_n(rst_n),
        // CPU interface
        .cpu_addr(cpu_dmem_addr),
        .cpu_wdata(cpu_dmem_wdata),
        .cpu_rdata(cpu_dmem_rdata),
        .cpu_we(cpu_dmem_we),
        .cpu_re(cpu_dmem_re),
        .cpu_ready(cpu_dmem_ready),
        .cpu_wstrb(4'b1111),  // Always word access for now
        // Memory interface
        .mem_addr(dmem_addr),
        .mem_wdata(dmem_wdata),
        .mem_rdata(dmem_rdata),
        .mem_we(dmem_we),
        .mem_re(dmem_re),
        .mem_ready(dmem_ready)
    );

endmodule
