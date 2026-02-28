//============================================================================
// Hazard Detection and Forwarding Unit
//============================================================================
`include "defines.vh"

module hazard_unit (
    input  wire        clk,
    input  wire        rst_n,
    
    // IF/ID stage signals (instruction currently in ID stage)
    input  wire [4:0]  if_id_rs1,
    input  wire [4:0]  if_id_rs2,
    
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
    
    // Forwarding control for ID stage (based on IF/ID instruction)
    output reg  [1:0]  forward_a_id,  // 00: no forward, 01: WB, 10: MEM
    output reg  [1:0]  forward_b_id,
    
    // Forwarding control for EX stage (based on ID/EX instruction)
    output reg  [1:0]  forward_a_ex,  // 00: no forward, 01: WB, 10: MEM
    output reg  [1:0]  forward_b_ex,
    
    // Stall and flush control
    output reg         pc_stall,
    output reg         if_id_stall,
    output reg         id_ex_stall,
    output reg         id_ex_flush
);

    // Forwarding logic for ID stage operand A (based on IF/ID rs1)
    always @(*) begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == if_id_rs1))
            forward_a_id = 2'b10;  // Forward from EX/MEM
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == if_id_rs1))
            forward_a_id = 2'b01;  // Forward from MEM/WB
        else
            forward_a_id = 2'b00;  // No forwarding
    end
    
    // Forwarding logic for ID stage operand B (based on IF/ID rs2)
    always @(*) begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == if_id_rs2))
            forward_b_id = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == if_id_rs2))
            forward_b_id = 2'b01;
        else
            forward_b_id = 2'b00;
    end

    // Forwarding logic for EX stage operand A (based on ID/EX rs1)
    always @(*) begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            forward_a_ex = 2'b10;  // Forward from EX/MEM
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            forward_a_ex = 2'b01;  // Forward from MEM/WB
        else
            forward_a_ex = 2'b00;  // No forwarding
    end
    
    // Forwarding logic for EX stage operand B (based on ID/EX rs2)
    always @(*) begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            forward_b_ex = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            forward_b_ex = 2'b01;
        else
            forward_b_ex = 2'b00;
    end
    
    // Load-use hazard detection (stall one cycle)
    // Detect when instruction in EX stage is a load,
    // and instruction in ID stage needs that result
    always @(*) begin
        if (id_ex_mem_read && (id_ex_rd != 5'd0) && 
            ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
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
