//============================================================================
// Module: data_bram
// Description: Data Memory using Xilinx BRAM
//              - Capacity: 16KB (4K x 32-bit) or 32KB (8K x 32-bit)
//              - 32-bit data width with byte/halfword/word access
//              - Little-endian (RISC-V standard)
//              - Byte addressing with alignment handling
//              - Supports initialization via $readmemh
//              - For Artix-7 FPGA (EGO1 board)
//============================================================================
`include "defines.vh"

`timescale 1ns / 1ps

module data_bram #(
    parameter ADDR_WIDTH = 14,          // 14-bit address: 16KB (default), use 15 for 32KB
    parameter DATA_WIDTH = 32,          // 32-bit data
    parameter INIT_FILE  = ""           // Hex initialization file path (optional)
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Memory interface
    input  wire [ADDR_WIDTH-1:0]    addr,         // Byte address
    input  wire [DATA_WIDTH-1:0]    din,          // Write data
    output reg  [DATA_WIDTH-1:0]    dout,         // Read data
    input  wire                     we,           // Write enable
    input  wire                     re,           // Read enable
    input  wire [2:0]               size,         // Access size: 000=byte, 001=half, 010=word
    input  wire                     unsigned_flag // 1=unsigned load, 0=signed load
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
    // Address decoding
    //========================================================================
    wire [AW-1:0] word_addr = addr[ADDR_WIDTH-1:2];
    wire [1:0]    byte_addr = addr[1:0];
    
    //========================================================================
    // Read/Write control signals
    //========================================================================
    reg [3:0]       byte_en;            // Byte enable for write
    reg [7:0]       byte0, byte1, byte2, byte3;  // Byte-level data selection
    reg [DATA_WIDTH-1:0] write_data;    // Aligned write data
    reg [DATA_WIDTH-1:0] raw_data;      // Raw data read from memory
    
    //========================================================================
    // Byte enable generation based on size and address
    //========================================================================
    always @(*) begin
        byte_en = 4'b0000;
        case (size)
            3'b000: begin // Byte
                case (byte_addr)
                    2'b00: byte_en = 4'b0001;
                    2'b01: byte_en = 4'b0010;
                    2'b10: byte_en = 4'b0100;
                    2'b11: byte_en = 4'b1000;
                endcase
            end
            3'b001: begin // Halfword (16-bit)
                case (byte_addr[1])
                    1'b0: byte_en = 4'b0011;  // Lower halfword
                    1'b1: byte_en = 4'b1100;  // Upper halfword
                endcase
            end
            3'b010: begin // Word (32-bit)
                byte_en = 4'b1111;
            end
            default: byte_en = 4'b0000;
        endcase
    end
    
    //========================================================================
    // Write data alignment (little-endian)
    //========================================================================
    always @(*) begin
        write_data = 32'h00000000;
        case (size)
            3'b000: begin // Byte - replicate to all positions, select by byte_en
                case (byte_addr)
                    2'b00: write_data = {24'h0, din[7:0]};
                    2'b01: write_data = {16'h0, din[7:0], 8'h0};
                    2'b10: write_data = {8'h0, din[7:0], 16'h0};
                    2'b11: write_data = {din[7:0], 24'h0};
                endcase
            end
            3'b001: begin // Halfword
                case (byte_addr[1])
                    1'b0: write_data = {16'h0, din[15:0]};
                    1'b1: write_data = {din[15:0], 16'h0};
                endcase
            end
            3'b010: begin // Word
                write_data = din;
            end
            default: write_data = 32'h00000000;
        endcase
    end
    
    //========================================================================
    // Memory Write (Synchronous)
    //========================================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // No reset for BRAM content
        end else if (we) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (byte_en[i]) begin
                    mem[word_addr][i*8 +: 8] <= write_data[i*8 +: 8];
                end
            end
        end
    end
    
    //========================================================================
    // Memory Read (Synchronous for BRAM)
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 32'h00000000;
        end else if (re) begin
            raw_data <= mem[word_addr];
        end
    end
    
    //========================================================================
    // Read data alignment and sign/zero extension
    // Little-endian: byte 0 at lowest address
    //========================================================================
    always @(*) begin
        // Extract bytes from raw data (little-endian storage)
        byte0 = raw_data[7:0];
        byte1 = raw_data[15:8];
        byte2 = raw_data[23:16];
        byte3 = raw_data[31:24];
        
        case (size)
            3'b000: begin // Byte
                case (byte_addr)
                    2'b00: dout = unsigned_flag ? {24'h0, byte0} : {{24{byte0[7]}}, byte0};
                    2'b01: dout = unsigned_flag ? {24'h0, byte1} : {{24{byte1[7]}}, byte1};
                    2'b10: dout = unsigned_flag ? {24'h0, byte2} : {{24{byte2[7]}}, byte2};
                    2'b11: dout = unsigned_flag ? {24'h0, byte3} : {{24{byte3[7]}}, byte3};
                endcase
            end
            3'b001: begin // Halfword
                case (byte_addr[1])
                    1'b0: dout = unsigned_flag ? {16'h0, byte1, byte0} : {{16{byte1[7]}}, byte1, byte0};
                    1'b1: dout = unsigned_flag ? {16'h0, byte3, byte2} : {{16{byte3[7]}}, byte3, byte2};
                endcase
            end
            3'b010: begin // Word
                dout = raw_data;
            end
            default: dout = 32'h00000000;
        endcase
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
// Alternative: Synchronous Read Version (for pipelined designs)
//============================================================================
module data_bram_sync_read #(
    parameter ADDR_WIDTH = 14,
    parameter DATA_WIDTH = 32,
    parameter INIT_FILE  = ""
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    input  wire [ADDR_WIDTH-1:0]    addr,
    input  wire [DATA_WIDTH-1:0]    din,
    output reg  [DATA_WIDTH-1:0]    dout,
    input  wire                     we,
    input  wire                     re,
    input  wire [2:0]               size,
    input  wire                     unsigned_flag
);

    localparam MEM_DEPTH = 1 << (ADDR_WIDTH - 2);
    localparam AW = ADDR_WIDTH - 2;
    
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];
    
    wire [AW-1:0] word_addr = addr[ADDR_WIDTH-1:2];
    wire [1:0]    byte_addr = addr[1:0];
    
    // Registered read data and address for alignment
    reg  [DATA_WIDTH-1:0] read_data_reg;
    reg  [1:0]            byte_addr_reg;
    reg  [2:0]            size_reg;
    reg                   unsigned_reg;
    reg                   read_valid;
    
    // Byte enable logic
    reg [3:0] byte_en;
    always @(*) begin
        byte_en = 4'b0000;
        case (size)
            3'b000: begin
                case (byte_addr)
                    2'b00: byte_en = 4'b0001;
                    2'b01: byte_en = 4'b0010;
                    2'b10: byte_en = 4'b0100;
                    2'b11: byte_en = 4'b1000;
                endcase
            end
            3'b001: begin
                case (byte_addr[1])
                    1'b0: byte_en = 4'b0011;
                    1'b1: byte_en = 4'b1100;
                endcase
            end
            3'b010: byte_en = 4'b1111;
            default: byte_en = 4'b0000;
        endcase
    end
    
    // Write data alignment
    reg [DATA_WIDTH-1:0] write_data;
    always @(*) begin
        case (size)
            3'b000: begin
                case (byte_addr)
                    2'b00: write_data = {24'h0, din[7:0]};
                    2'b01: write_data = {16'h0, din[7:0], 8'h0};
                    2'b10: write_data = {8'h0, din[7:0], 16'h0};
                    2'b11: write_data = {din[7:0], 24'h0};
                endcase
            end
            3'b001: begin
                case (byte_addr[1])
                    1'b0: write_data = {16'h0, din[15:0]};
                    1'b1: write_data = {din[15:0], 16'h0};
                endcase
            end
            3'b010: write_data = din;
            default: write_data = 32'h0;
        endcase
    end
    
    // Memory write
    integer i;
    always @(posedge clk) begin
        if (we) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (byte_en[i]) begin
                    mem[word_addr][i*8 +: 8] <= write_data[i*8 +: 8];
                end
            end
        end
    end
    
    // Synchronous read with registered outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data_reg <= 32'h0;
            byte_addr_reg <= 2'b0;
            size_reg      <= 3'b0;
            unsigned_reg  <= 1'b0;
            read_valid    <= 1'b0;
        end else begin
            if (re) begin
                read_data_reg <= mem[word_addr];
                byte_addr_reg <= byte_addr;
                size_reg      <= size;
                unsigned_reg  <= unsigned_flag;
                read_valid    <= 1'b1;
            end else begin
                read_valid <= 1'b0;
            end
        end
    end
    
    // Output alignment
    always @(*) begin
        if (read_valid) begin
            case (size_reg)
                3'b000: begin
                    case (byte_addr_reg)
                        2'b00: dout = unsigned_reg ? {24'h0, read_data_reg[7:0]} 
                                                   : {{24{read_data_reg[7]}}, read_data_reg[7:0]};
                        2'b01: dout = unsigned_reg ? {24'h0, read_data_reg[15:8]} 
                                                   : {{24{read_data_reg[15]}}, read_data_reg[15:8]};
                        2'b10: dout = unsigned_reg ? {24'h0, read_data_reg[23:16]} 
                                                   : {{24{read_data_reg[23]}}, read_data_reg[23:16]};
                        2'b11: dout = unsigned_reg ? {24'h0, read_data_reg[31:24]} 
                                                   : {{24{read_data_reg[31]}}, read_data_reg[31:24]};
                    endcase
                end
                3'b001: begin
                    case (byte_addr_reg[1])
                        1'b0: dout = unsigned_reg ? {16'h0, read_data_reg[15:0]} 
                                                  : {{16{read_data_reg[15]}}, read_data_reg[15:0]};
                        1'b1: dout = unsigned_reg ? {16'h0, read_data_reg[31:16]} 
                                                  : {{16{read_data_reg[31]}}, read_data_reg[31:16]};
                    endcase
                end
                3'b010: dout = read_data_reg;
                default: dout = 32'h0;
            endcase
        end else begin
            dout = 32'h0;
        end
    end
    
    // Initialization
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

endmodule
