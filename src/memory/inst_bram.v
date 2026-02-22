//============================================================================
// Module: inst_bram
// Description: Instruction Memory using Xilinx BRAM (RAMB36E1)
//              - Capacity: 8KB (2K x 32-bit) or 16KB (4K x 32-bit)
//              - 32-bit data width
//              - Asynchronous read (combinational) for IF stage
//              - Supports initialization via $readmemh
//              - For Artix-7 FPGA (EGO1 board)
//============================================================================
`include "defines.vh"

`timescale 1ns / 1ps

module inst_bram #(
    parameter ADDR_WIDTH = 12,          // 12-bit address: 4KB (default), use 13 for 8KB
    parameter DATA_WIDTH = 32,          // 32-bit RISC-V instructions
    parameter INIT_FILE  = ""           // Hex initialization file path (optional)
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Port A: Instruction Fetch (Read-only, asynchronous read)
    input  wire [ADDR_WIDTH-1:0]    addr_a,       // Byte address (lower 2 bits should be 00)
    output wire [DATA_WIDTH-1:0]    dout_a,       // Instruction output
    
    // Port B: External loader/debugger (Write-only)
    input  wire                     we_b,         // Write enable
    input  wire [ADDR_WIDTH-1:0]    addr_b,       // Write address
    input  wire [DATA_WIDTH-1:0]    din_b,        // Write data
    input  wire [3:0]               be_b          // Byte enable (for partial writes)
);

    //========================================================================
    // Local Parameters
    //========================================================================
    localparam MEM_DEPTH = 1 << (ADDR_WIDTH - 2);  // Word-aligned depth
    localparam AW = ADDR_WIDTH - 2;                // Word address width
    
    //========================================================================
    // Memory Declaration (will infer BRAM on Xilinx)
    //========================================================================
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];
    
    //========================================================================
    // Word-aligned addresses
    //========================================================================
    wire [AW-1:0] word_addr_a = addr_a[ADDR_WIDTH-1:2];
    wire [AW-1:0] word_addr_b = addr_b[ADDR_WIDTH-1:2];
    
    //========================================================================
    // Port A: Asynchronous Read (Instruction Fetch)
    // Combinational read for single-cycle IF stage
    //========================================================================
    assign dout_a = mem[word_addr_a];
    
    //========================================================================
    // Port B: Synchronous Write (Loader/Debugger)
    //========================================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset - memory content preserved, just state if needed
        end else if (we_b) begin
            // Byte-wise write support
            for (i = 0; i < 4; i = i + 1) begin
                if (be_b[i]) begin
                    mem[word_addr_b][i*8 +: 8] <= din_b[i*8 +: 8];
                end
            end
        end
    end
    
    //========================================================================
    // Initialization
    //========================================================================
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

endmodule


//============================================================================
// Alternative: Using Xilinx RAMB36E1 Primitive (if needed)
// Uncomment and use this version for explicit BRAM primitive instantiation
//============================================================================
/*
module inst_bram_xilinx #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32,
    parameter INIT_FILE  = ""
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [ADDR_WIDTH-1:0]    addr_a,
    output wire [DATA_WIDTH-1:0]    dout_a,
    input  wire                     we_b,
    input  wire [ADDR_WIDTH-1:0]    addr_b,
    input  wire [DATA_WIDTH-1:0]    din_b,
    input  wire [3:0]               be_b
);

    // Using two RAMB18E1 or one RAMB36E1
    // For 8KB (2K x 32), we need 2 x RAMB18E1 or configure RAMB36E1 as 1K x 36
    // For simplicity, using inferred version above is recommended
    
    // RAMB36E1 primitive would go here if needed
    // ...

endmodule
*/
