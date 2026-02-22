//============================================================================
// MEM Stage - Memory Access Stage
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
    input  wire        reg_write,
    
    // Data memory interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    output wire        dmem_we,
    output wire        dmem_re,
    
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
    assign dmem_wdata = rs2_data;
    assign dmem_we    = mem_write;
    assign dmem_re    = mem_read;
    
    // MEM/WB Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_out   <= 32'd0;
            alu_result_out <= 32'd0;
            mem_data_out   <= 32'd0;
            rd_addr_out    <= 5'd0;
            mem_to_reg_out <= 1'b0;
            reg_write_out  <= 1'b0;
        end else begin
            pc_plus4_out   <= pc_plus4;
            alu_result_out <= alu_result;
            mem_data_out   <= dmem_rdata;
            rd_addr_out    <= rd_addr;
            mem_to_reg_out <= mem_to_reg;
            reg_write_out  <= reg_write;
        end
    end

endmodule
