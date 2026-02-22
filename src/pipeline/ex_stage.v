//============================================================================
// EX Stage - Execute Stage
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
    input  wire        alu_src_a,    // 0: rs1, 1: PC
    input  wire        alu_src_b,    // 0: rs2, 1: imm
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire        mem_to_reg,
    input  wire        reg_write,
    input  wire        branch,
    input  wire        jump,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    
    // Forwarded data
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
    output wire        branch_taken_out,
    output reg  [31:0] branch_target_out
);

    // ALU inputs with forwarding
    wire [31:0] alu_a_src;
    wire [31:0] alu_b_src;
    wire [31:0] alu_a_final;
    wire [31:0] alu_b_final;
    wire [31:0] alu_result;
    
    // Forward mux for rs1
    assign alu_a_src = (forward_a_sel == 2'b10) ? forward_mem_data :
                       (forward_a_sel == 2'b01) ? forward_wb_data :
                       rs1_data;
    
    // Forward mux for rs2
    wire [31:0] rs2_fwd = (forward_b_sel == 2'b10) ? forward_mem_data :
                          (forward_b_sel == 2'b01) ? forward_wb_data :
                          rs2_data;
    
    // ALU source selection
    assign alu_a_final = alu_src_a ? pc : alu_a_src;
    assign alu_b_final = alu_src_b ? imm : rs2_fwd;
    
    // ALU instantiation
    ALU alu (
        .a(alu_a_final),
        .b(alu_b_final),
        .alu_op(alu_op),
        .result(alu_result)
    );
    
    // Branch condition check
    wire rs1_eq_rs2 = (alu_a_src == rs2_fwd);
    wire rs1_lt_rs2_signed = ($signed(alu_a_src) < $signed(rs2_fwd));
    wire rs1_lt_rs2_unsigned = (alu_a_src < rs2_fwd);
    
    reg branch_cond;
    always @(*) begin
        case (alu_op)
            `ALU_BEQ:  branch_cond = rs1_eq_rs2;
            `ALU_BNE:  branch_cond = !rs1_eq_rs2;
            `ALU_BLT:  branch_cond = rs1_lt_rs2_signed;
            `ALU_BGE:  branch_cond = !rs1_lt_rs2_signed;
            `ALU_BLTU: branch_cond = rs1_lt_rs2_unsigned;
            `ALU_BGEU: branch_cond = !rs1_lt_rs2_unsigned;
            default:   branch_cond = 1'b0;
        endcase
    end
    
    assign branch_taken_out = (branch & branch_cond) | jump;
    
    // Branch target calculation
    always @(*) begin
        if (jump && (alu_op == `ALU_JALR))
            branch_target_out = {alu_result[31:1], 1'b0};  // JALR
        else
            branch_target_out = alu_result;  // PC + imm for branch/JAL
    end
    
    // EX/MEM Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_out    <= 32'd0;
            alu_result_out  <= 32'd0;
            rs2_data_out    <= 32'd0;
            rd_addr_out     <= 5'd0;
            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;
            mem_to_reg_out  <= 1'b0;
            reg_write_out   <= 1'b0;
        end else begin
            pc_plus4_out    <= pc_plus4;
            alu_result_out  <= alu_result;
            rs2_data_out    <= rs2_fwd;
            rd_addr_out     <= rd_addr;
            mem_read_out    <= mem_read;
            mem_write_out   <= mem_write;
            mem_to_reg_out  <= mem_to_reg;
            reg_write_out   <= reg_write;
        end
    end

endmodule
