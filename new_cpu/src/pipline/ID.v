//============================================================================
// ID Stage - Instruction Decode
//============================================================================
`include "defines.vh"

module id_stage (
    input  wire        clk,
    input  wire        rst_n,

    // From IF/ID pipeline register
    input  wire [31:0] pc,
    input  wire [31:0] pc_plus4,
    input  wire [31:0] instr,

    // From register file
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    output wire [4:0]  rs1_addr,
    output wire [4:0]  rs2_addr,

    // Forwarding (from MEM/WB stages)
    input  wire [31:0] forward_mem_data,
    input  wire [31:0] forward_wb_data,
    input  wire [1:0]  forward_a_sel,
    input  wire [1:0]  forward_b_sel,

    // Hazard control
    input  wire        stall,
    input  wire        flush,

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
    output reg  [1:0]  mem_size_out,
    output reg         mem_unsigned_out,
    output reg         reg_write_out,
    output reg         branch_out,
    output reg         jump_out,
    output reg         is_ecall,
    output reg         is_ebreak,
    output reg         is_mret,
    output reg         is_sret,
    output reg         is_wfi,
    output reg         is_sfence_vma,
    output reg         csr_we,
    output reg         csr_re,
    output reg  [2:0]  csr_op
);

    // Control unit signals
    wire [5:0]  alu_op;
    wire        alu_src_a;
    wire        alu_src_b;
    wire        mem_read;
    wire        mem_write;
    wire        mem_to_reg;
    wire [1:0]  mem_size;
    wire        mem_unsigned;
    wire        reg_write;
    wire        branch;
    wire        jump;
    wire [2:0]  imm_sel;
    wire        ctrl_is_ecall;
    wire        ctrl_is_ebreak;
    wire        ctrl_is_mret;
    wire        ctrl_is_sret;
    wire        ctrl_is_wfi;
    wire        ctrl_is_sfence_vma;
    wire        ctrl_csr_we;
    wire        ctrl_csr_re;
    wire [2:0]  ctrl_csr_op;

    // Immediate generation
    wire [31:0] imm;

    // Register addresses
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    wire [4:0] rd_addr = instr[11:7];

    // Forwarded register data
    wire [31:0] rs1_fwd;
    wire [31:0] rs2_fwd;

    assign rs1_fwd = (forward_a_sel == `FORWARD_MEM) ? forward_mem_data :
                     (forward_a_sel == `FORWARD_WB)  ? forward_wb_data  : rs1_data;
    assign rs2_fwd = (forward_b_sel == `FORWARD_MEM) ? forward_mem_data :
                     (forward_b_sel == `FORWARD_WB)  ? forward_wb_data  : rs2_data;

    // Immediate generator
    imm_gen u_imm_gen (
        .instr(instr),
        .imm_sel(imm_sel),
        .imm(imm)
    );

    // Control unit
    control_unit u_ctrl (
        .instr(instr),
        .alu_op(alu_op),
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .mem_size(mem_size),
        .mem_unsigned(mem_unsigned),
        .reg_write(reg_write),
        .branch(branch),
        .jump(jump),
        .imm_sel(imm_sel),
        .is_ecall(ctrl_is_ecall),
        .is_ebreak(ctrl_is_ebreak),
        .is_mret(ctrl_is_mret),
        .is_sret(ctrl_is_sret),
        .is_wfi(ctrl_is_wfi),
        .is_sfence_vma(ctrl_is_sfence_vma),
        .csr_we(ctrl_csr_we),
        .csr_re(ctrl_csr_re),
        .csr_op(ctrl_csr_op)
    );

    // ID/EX pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            pc_out        <= 32'd0;
            pc_plus4_out  <= 32'd0;
            rs1_data_out  <= 32'd0;
            rs2_data_out  <= 32'd0;
            imm_out       <= 32'd0;
            rs1_addr_out  <= 5'd0;
            rs2_addr_out  <= 5'd0;
            rd_addr_out   <= 5'd0;
            alu_op_out    <= `ALU_NOP;
            alu_src_a_out <= 1'b0;
            alu_src_b_out <= 1'b0;
            mem_read_out      <= 1'b0;
            mem_write_out     <= 1'b0;
            mem_to_reg_out    <= 1'b0;
            mem_size_out      <= 2'b10;
            mem_unsigned_out  <= 1'b0;
            reg_write_out     <= 1'b0;
            branch_out        <= 1'b0;
            jump_out          <= 1'b0;
            is_ecall          <= 1'b0;
            is_ebreak     <= 1'b0;
            is_mret       <= 1'b0;
            is_sret       <= 1'b0;
            is_wfi        <= 1'b0;
            is_sfence_vma <= 1'b0;
            csr_we        <= 1'b0;
            csr_re        <= 1'b0;
            csr_op        <= 3'd0;
        end else if (!stall) begin
            pc_out        <= pc;
            pc_plus4_out  <= pc_plus4;
            rs1_data_out  <= rs1_fwd;
            rs2_data_out  <= rs2_fwd;
            imm_out       <= imm;
            rs1_addr_out  <= rs1_addr;
            rs2_addr_out  <= rs2_addr;
            rd_addr_out   <= rd_addr;
            alu_op_out    <= alu_op;
            alu_src_a_out <= alu_src_a;
            alu_src_b_out <= alu_src_b;
            mem_read_out      <= mem_read;
            mem_write_out     <= mem_write;
            mem_to_reg_out    <= mem_to_reg;
            mem_size_out      <= mem_size;
            mem_unsigned_out  <= mem_unsigned;
            reg_write_out     <= reg_write;
            branch_out        <= branch;
            jump_out          <= jump;
            is_ecall      <= ctrl_is_ecall;
            is_ebreak     <= ctrl_is_ebreak;
            is_mret       <= ctrl_is_mret;
            is_sret       <= ctrl_is_sret;
            is_wfi        <= ctrl_is_wfi;
            is_sfence_vma <= ctrl_is_sfence_vma;
            csr_we        <= ctrl_csr_we;
            csr_re        <= ctrl_csr_re;
            csr_op        <= ctrl_csr_op;
        end
    end

endmodule

//============================================================================
// Immediate Generator
//============================================================================
module imm_gen (
    input  wire [31:0] instr,
    input  wire [2:0]  imm_sel,
    output reg  [31:0] imm
);
    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    always @(*) begin
        case (imm_sel)
            IMM_I: imm = {{20{instr[31]}}, instr[31:20]};
            IMM_S: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            IMM_B: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            IMM_U: imm = {instr[31:12], 12'b0};
            IMM_J: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            default: imm = 32'd0;
        endcase
    end
endmodule
