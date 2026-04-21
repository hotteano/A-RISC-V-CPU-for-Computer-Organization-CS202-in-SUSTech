//===================================================
// I_BRam - Instruction BRAM for RISC-V CPU
// 1KB (256 x 32-bit) Instruction Memory
//===================================================
`include "defines.vh"

module I_BRam #(
    parameter ADDR_WIDTH = 14,          // 实际 BRAM 地址宽度 (14 = 16KB)
    parameter DATA_WIDTH = 32,
    parameter INIT_FILE  = ""
)(
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire [`INST_ADDR_BUS] addr_a,
    output wire [`INST_BUS]      dout_a,

    input  wire                  we_b,
    input  wire [`INST_ADDR_BUS] addr_b,
    input  wire [`INST_BUS]      din_b,
    input  wire [3:0]            be_b
);
    localparam MEM_SIZE  = 1 << ADDR_WIDTH; // Total memory size in bytes
    localparam MEM_DEPTH = 1 << (ADDR_WIDTH - 2);
    localparam AW        = ADDR_WIDTH - 2;

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    wire [AW-1:0] word_addr_a = addr_a[ADDR_WIDTH-1:2];
    wire [AW-1:0] word_addr_b = addr_b[ADDR_WIDTH-1:2];

    assign dout_a = mem[word_addr_a];
    
    
endmodule
