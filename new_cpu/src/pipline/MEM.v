//============================================================================
// MEM Stage - Memory Access with byte/halfword support
//============================================================================
`include "defines.vh"

module mem_stage (
    input  wire        clk,
    input  wire        rst_n,

    // From EX/MEM pipeline register
    input  wire [31:0] pc_plus4,
    input  wire [31:0] alu_result,
    input  wire [31:0] rs2_data,
    input  wire [4:0]  rd_addr,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire        mem_to_reg,
    input  wire [1:0]  mem_size,      // 00=byte, 01=half, 10=word
    input  wire        mem_unsigned,  // 1=unsigned load

    // Data memory interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,    // Byte write enable
    input  wire [31:0] dmem_rdata,
    output wire        dmem_we,
    output wire        dmem_re,
    input  wire        dmem_ready,

    // To MEM/WB pipeline register
    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] alu_result_out,
    output reg  [31:0] mem_data_out,
    output reg  [4:0]  rd_addr_out,
    output reg         mem_to_reg_out,
    output reg         reg_write_out
);

    // Data memory interface
    assign dmem_addr  = alu_result;
    assign dmem_we    = mem_write;
    assign dmem_re    = mem_read;

    // Store data alignment: shift byte/halfword into correct lane based on address
    assign dmem_wdata = (mem_size == 2'b00) ? ({4{rs2_data[7:0]}}) :   // SB: replicate byte
                        (mem_size == 2'b01) ? ({2{rs2_data[15:0]}}) :  // SH: replicate half
                        rs2_data;                                         // SW

    // Write strobe generation
    assign dmem_wstrb = mem_write ? (
                            (mem_size == 2'b00) ? (4'b0001 << alu_result[1:0]) :
                            (mem_size == 2'b01) ? (4'b0011 << alu_result[1]) :
                            4'b1111
                        ) : 4'b0000;

    // Load data extraction and sign/zero extension
    wire [7:0]  byte_data = dmem_rdata >> (alu_result[1:0] * 8);
    wire [15:0] half_data = dmem_rdata >> (alu_result[1] * 16);

    wire [31:0] load_data;
    assign load_data = (mem_size == 2'b00) ? (mem_unsigned ? {24'd0, byte_data} : {{24{byte_data[7]}}, byte_data}) :
                       (mem_size == 2'b01) ? (mem_unsigned ? {16'd0, half_data} : {{16{half_data[15]}}, half_data}) :
                       dmem_rdata;

    // MEM/WB pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_out   <= 32'd0;
            alu_result_out <= 32'd0;
            mem_data_out   <= 32'd0;
            rd_addr_out    <= 5'd0;
            mem_to_reg_out <= 1'b0;
            reg_write_out  <= 1'b0;
        end else if (dmem_ready) begin
            pc_plus4_out   <= pc_plus4;
            alu_result_out <= alu_result;
            mem_data_out   <= load_data;
            rd_addr_out    <= rd_addr;
            mem_to_reg_out <= mem_to_reg;
            reg_write_out  <= reg_write;
        end
    end

endmodule
