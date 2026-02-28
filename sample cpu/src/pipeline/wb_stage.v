//============================================================================
// WB Stage - Write Back Stage
//============================================================================
`include "defines.vh"

module wb_stage (
    input  wire        clk,
    input  wire        rst_n,
    
    // From MEM/WB pipeline register
    input  wire [31:0] pc_plus4,
    input  wire [31:0] alu_result,
    input  wire [31:0] mem_data,
    input  wire [4:0]  rd_addr,
    input  wire        mem_to_reg,
    input  wire        reg_write,
    
    // To register file
    output wire [4:0]  wb_rd_addr,
    output wire [31:0] wb_rd_data,
    output wire        wb_reg_write
);

    // Write back data selection
    assign wb_rd_data = mem_to_reg ? mem_data : 
                        (rd_addr == 5'd0) ? pc_plus4 :  // JAL/JALR return address
                        alu_result;
    
    assign wb_rd_addr  = rd_addr;
    assign wb_reg_write = reg_write;

endmodule
