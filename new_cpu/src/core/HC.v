//============================================================================
// Hazard Control Unit - Forwarding and Stall/Flush Control
//============================================================================
`include "defines.vh"

module hazard_unit (
    input  wire        clk,
    input  wire        rst_n,

    // IF/ID stage instruction fields
    input  wire [4:0]  if_id_rs1,
    input  wire [4:0]  if_id_rs2,

    // ID/EX stage
    input  wire [4:0]  id_ex_rs1,
    input  wire [4:0]  id_ex_rs2,
    input  wire [4:0]  id_ex_rd,
    input  wire        id_ex_mem_read,
    input  wire        id_ex_reg_write,

    // EX/MEM stage
    input  wire [4:0]  ex_mem_rd,
    input  wire        ex_mem_reg_write,

    // MEM/WB stage
    input  wire [4:0]  mem_wb_rd,
    input  wire        mem_wb_reg_write,

    // Forwarding controls (to ID stage)
    output reg  [1:0]  forward_a_id,
    output reg  [1:0]  forward_b_id,

    // Forwarding controls (to EX stage)
    output reg  [1:0]  forward_a_ex,
    output reg  [1:0]  forward_b_ex,

    // Stall/Flush controls
    output reg         pc_stall,
    output reg         if_id_stall,
    output reg         id_ex_flush
);

    // Load-use hazard detection (stall one cycle)
    wire load_use_hazard;
    assign load_use_hazard = id_ex_mem_read &&
                             ((id_ex_rd == if_id_rs1 && if_id_rs1 != 5'd0) ||
                              (id_ex_rd == if_id_rs2 && if_id_rs2 != 5'd0));

    // Stall signals
    always @(*) begin
        pc_stall     = load_use_hazard;
        if_id_stall  = load_use_hazard;
        id_ex_flush  = load_use_hazard;
    end

    // Forwarding to EX stage (priority: MEM > WB)
    always @(*) begin
        // Forward A (rs1)
        if (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs1)
            forward_a_ex = `FORWARD_MEM;
        else if (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs1)
            forward_a_ex = `FORWARD_WB;
        else
            forward_a_ex = `FORWARD_NONE;

        // Forward B (rs2)
        if (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs2)
            forward_b_ex = `FORWARD_MEM;
        else if (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs2)
            forward_b_ex = `FORWARD_WB;
        else
            forward_b_ex = `FORWARD_NONE;
    end

    // Forwarding to ID stage (for branch resolution in ID)
    always @(*) begin
        // Forward A (rs1)
        if (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == if_id_rs1)
            forward_a_id = `FORWARD_MEM;
        else if (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == if_id_rs1)
            forward_a_id = `FORWARD_WB;
        else
            forward_a_id = `FORWARD_NONE;

        // Forward B (rs2)
        if (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == if_id_rs2)
            forward_b_id = `FORWARD_MEM;
        else if (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == if_id_rs2)
            forward_b_id = `FORWARD_WB;
        else
            forward_b_id = `FORWARD_NONE;
    end

endmodule
