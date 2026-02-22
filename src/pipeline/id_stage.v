//============================================================================
// ID Stage - Instruction Decode Stage
//============================================================================
`include "defines.vh"

module id_stage (
    input  wire        clk,
    input  wire        rst_n,
    
    // From IF/ID pipeline register
    input  wire [31:0] pc,
    input  wire [31:0] pc_plus4,
    input  wire [31:0] instr,
    
    // From register file (WB stage)
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    
    // Register addresses
    output wire [4:0]  rs1_addr,
    output wire [4:0]  rs2_addr,
    
    // Forwarded data for hazard resolution
    input  wire [31:0] forward_mem_data,
    input  wire [31:0] forward_wb_data,
    input  wire [1:0]  forward_a_sel,
    input  wire [1:0]  forward_b_sel,
    
    // To ID/EX pipeline register
    output reg  [31:0] pc_out,
    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] rs1_data_out,
    output reg  [31:0] rs2_data_out,
    output reg  [31:0] imm_out,
    output reg  [4:0]  rs1_addr_out,
    output reg  [4:0]  rs2_addr_out,
    output reg  [4:0]  rd_addr_out,
    output reg  [5:0]  alu_op_out,
    output reg         alu_src_a_out,
    output reg         alu_src_b_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg         reg_write_out,
    output reg         branch_out,
    output reg         jump_out,
    
    // Control signals
    output wire        is_ecall,
    output wire        is_ebreak
);

    // Extract instruction fields
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    wire [4:0] rd_addr = instr[11:7];
    
    // Immediate generation
    reg [31:0] imm;
    wire [2:0] imm_sel;
    
    always @(*) begin
        case (imm_sel)
            3'b000: imm = {{20{instr[31]}}, instr[31:20]};  // I-type
            3'b001: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};  // S-type
            3'b010: imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};  // B-type
            3'b011: imm = {instr[31:12], 12'b0};  // U-type
            3'b100: imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};  // J-type
            default: imm = 32'd0;
        endcase
    end
    
    // Forwarded rs1 data
    wire [31:0] rs1_data_fwd;
    assign rs1_data_fwd = (forward_a_sel == 2'b10) ? forward_mem_data :
                          (forward_a_sel == 2'b01) ? forward_wb_data :
                          rs1_data;
    
    // Forwarded rs2 data
    wire [31:0] rs2_data_fwd;
    assign rs2_data_fwd = (forward_b_sel == 2'b10) ? forward_mem_data :
                          (forward_b_sel == 2'b01) ? forward_wb_data :
                          rs2_data;
    
    // Control Unit instantiation
    control_unit ctrl (
        .instr(instr),
        .alu_op(alu_op_out),
        .alu_src_a(alu_src_a_out),
        .alu_src_b(alu_src_b_out),
        .mem_read(mem_read_out),
        .mem_write(mem_write_out),
        .mem_to_reg(mem_to_reg_out),
        .reg_write(reg_write_out),
        .branch(branch_out),
        .jump(jump_out),
        .imm_sel(imm_sel),
        .is_ecall(is_ecall),
        .is_ebreak(is_ebreak)
    );
    
    // ID/EX Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out       <= 32'd0;
            pc_plus4_out <= 32'd0;
            rs1_data_out <= 32'd0;
            rs2_data_out <= 32'd0;
            imm_out      <= 32'd0;
            rs1_addr_out <= 5'd0;
            rs2_addr_out <= 5'd0;
            rd_addr_out  <= 5'd0;
        end else begin
            pc_out       <= pc;
            pc_plus4_out <= pc_plus4;
            rs1_data_out <= rs1_data_fwd;
            rs2_data_out <= rs2_data_fwd;
            imm_out      <= imm;
            rs1_addr_out <= rs1_addr;
            rs2_addr_out <= rs2_addr;
            rd_addr_out  <= rd_addr;
        end
    end

endmodule
