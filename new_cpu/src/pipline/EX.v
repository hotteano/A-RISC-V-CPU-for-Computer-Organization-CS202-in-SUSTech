//============================================================================
// EX Stage - Execute
//============================================================================
`include "defines.vh"

module ex_stage (
    input  wire        clk,
    input  wire        rst_n,

    // From ID/EX pipeline register
    input  wire [31:0] pc,
    input  wire [31:0] pc_plus4,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire [31:0] imm,
    input  wire [5:0]  alu_op,
    input  wire        alu_src_a,
    input  wire        alu_src_b,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire        mem_to_reg,
    input  wire        reg_write,
    input  wire        branch,
    input  wire        jump,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,

    // Forwarding
    input  wire [31:0] forward_mem_data,
    input  wire [31:0] forward_wb_data,
    input  wire [1:0]  forward_a_sel,
    input  wire [1:0]  forward_b_sel,

    // To EX/MEM pipeline register
    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] alu_result_out,
    output reg  [31:0] rs2_data_out,
    output reg  [4:0]  rd_addr_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg         reg_write_out,
    output reg         branch_taken_out,
    output reg  [31:0] branch_target_out
);

    // ALU operands after forwarding
    wire [31:0] alu_a_fwd;
    wire [31:0] alu_b_fwd;
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_result;

    // Forwarding multiplexers
    assign alu_a_fwd = (forward_a_sel == `FORWARD_MEM) ? forward_mem_data :
                       (forward_a_sel == `FORWARD_WB)  ? forward_wb_data  : rs1_data;
    assign alu_b_fwd = (forward_b_sel == `FORWARD_MEM) ? forward_mem_data :
                       (forward_b_sel == `FORWARD_WB)  ? forward_wb_data  : rs2_data;

    // ALU source selection
    assign alu_a = alu_src_a ? pc : alu_a_fwd;
    assign alu_b = alu_src_b ? imm : alu_b_fwd;

    // ALU instance
    ALU u_alu (
        .a(alu_a),
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_result)
    );

    // Branch condition evaluation
    wire branch_taken;
    assign branch_taken = branch && (
        (alu_op == `ALU_BEQ  && alu_result == 32'd0) ||
        (alu_op == `ALU_BNE  && alu_result != 32'd0) ||
        (alu_op == `ALU_BLT  && $signed(alu_a_fwd) < $signed(alu_b_fwd)) ||
        (alu_op == `ALU_BGE  && $signed(alu_a_fwd) >= $signed(alu_b_fwd)) ||
        (alu_op == `ALU_BLTU && alu_a_fwd < alu_b_fwd) ||
        (alu_op == `ALU_BGEU && alu_a_fwd >= alu_b_fwd)
    );

    // Branch/Jump target
    wire [31:0] branch_target;
    assign branch_target = (jump && alu_op == `ALU_JALR) ? {alu_result[31:1], 1'b0} : alu_result;

    // EX/MEM pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_out      <= 32'd0;
            alu_result_out    <= 32'd0;
            rs2_data_out      <= 32'd0;
            rd_addr_out       <= 5'd0;
            mem_read_out      <= 1'b0;
            mem_write_out     <= 1'b0;
            mem_to_reg_out    <= 1'b0;
            reg_write_out     <= 1'b0;
            branch_taken_out  <= 1'b0;
            branch_target_out <= 32'd0;
        end else begin
            pc_plus4_out      <= pc_plus4;
            alu_result_out    <= alu_result;
            rs2_data_out      <= alu_b_fwd;
            rd_addr_out       <= rd_addr;
            mem_read_out      <= mem_read;
            mem_write_out     <= mem_write;
            mem_to_reg_out    <= mem_to_reg;
            reg_write_out     <= reg_write;
            branch_taken_out  <= branch_taken || jump;
            branch_target_out <= branch_target;
        end
    end

endmodule
