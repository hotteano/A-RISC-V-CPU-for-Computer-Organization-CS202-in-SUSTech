//============================================================================
// Hazard Detection and Forwarding Unit
//============================================================================
`include "defines.vh"

module hazard_unit (
    input  wire        clk,
    input  wire        rst_n,
    
    // ID/EX stage signals
    input  wire [4:0]  id_ex_rs1,
    input  wire [4:0]  id_ex_rs2,
    input  wire [4:0]  id_ex_rd,
    input  wire        id_ex_mem_read,
    input  wire        id_ex_reg_write,
    
    // EX/MEM stage signals
    input  wire [4:0]  ex_mem_rd,
    input  wire        ex_mem_reg_write,
    
    // MEM/WB stage signals
    input  wire [4:0]  mem_wb_rd,
    input  wire        mem_wb_reg_write,
    
    // Forwarding control
    output reg  [1:0]  forward_a,  // 00: no forward, 01: WB, 10: MEM
    output reg  [1:0]  forward_b,
    
    // Stall and flush control
    output reg         pc_stall,
    output reg         if_id_stall,
    output reg         id_ex_stall,
    output reg         id_ex_flush
);

    // Forwarding logic for operand A (rs1)
    always @(*) begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;  // Forward from EX/MEM
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;  // Forward from MEM/WB
        else
            forward_a = 2'b00;  // No forwarding
    end
    
    // Forwarding logic for operand B (rs2)
    always @(*) begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end
    
    // Load-use hazard detection (stall one cycle)
    always @(*) begin
        if (id_ex_mem_read && 
            ((id_ex_rd != 5'd0) && 
             ((id_ex_rd == id_ex_rs1) || (id_ex_rd == id_ex_rs2)))) begin
            pc_stall    = 1'b1;
            if_id_stall = 1'b1;
            id_ex_flush = 1'b1;
        end else begin
            pc_stall    = 1'b0;
            if_id_stall = 1'b0;
            id_ex_flush = 1'b0;
        end
        id_ex_stall = 1'b0;
    end

endmodule
