//============================================================================
// RISC-V CPU Top Module - 5-Stage Pipeline
//============================================================================
`include "defines.vh"

module riscv_cpu_top (
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction memory interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    
    // Data memory interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    output wire        dmem_we,
    output wire        dmem_re
);

    //========================================================================
    // Pipeline Registers
    //========================================================================
    
    // IF/ID Pipeline Register
    wire [31:0] if_id_pc;
    wire [31:0] if_id_pc_plus4;
    wire [31:0] if_id_instr;
    
    // ID/EX Pipeline Register
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_pc_plus4;
    wire [31:0] id_ex_rs1_data;
    wire [31:0] id_ex_rs2_data;
    wire [31:0] id_ex_imm;
    wire [4:0]  id_ex_rs1_addr;
    wire [4:0]  id_ex_rs2_addr;
    wire [4:0]  id_ex_rd_addr;
    wire [5:0]  id_ex_alu_op;
    wire        id_ex_alu_src_a;
    wire        id_ex_alu_src_b;
    wire        id_ex_mem_read;
    wire        id_ex_mem_write;
    wire        id_ex_mem_to_reg;
    wire        id_ex_reg_write;
    wire        id_ex_branch;
    wire        id_ex_jump;
    
    // EX/MEM Pipeline Register
    wire [31:0] ex_mem_pc_plus4;
    wire [31:0] ex_mem_alu_result;
    wire [31:0] ex_mem_rs2_data;
    wire [4:0]  ex_mem_rd_addr;
    wire        ex_mem_mem_read;
    wire        ex_mem_mem_write;
    wire        ex_mem_mem_to_reg;
    wire        ex_mem_reg_write;
    wire        ex_mem_branch_taken;
    wire [31:0] ex_mem_branch_target;
    
    // MEM/WB Pipeline Register
    wire [31:0] mem_wb_pc_plus4;
    wire [31:0] mem_wb_alu_result;
    wire [31:0] mem_wb_mem_data;
    wire [4:0]  mem_wb_rd_addr;
    wire        mem_wb_mem_to_reg;
    wire        mem_wb_reg_write;
    
    //========================================================================
    // Control Signals
    //========================================================================
    
    // Hazard Unit signals
    wire [1:0]  forward_a_id;
    wire [1:0]  forward_b_id;
    wire [1:0]  forward_a_ex;
    wire [1:0]  forward_b_ex;
    wire        pc_stall;
    wire        if_id_stall;
    wire        id_ex_flush;
    
    // Branch/Jump
    wire        pc_src;
    wire [31:0] pc_target;
    
    // Register file signals
    wire [4:0]  rf_rs1_addr;
    wire [4:0]  rf_rs2_addr;
    wire [31:0] rf_rs1_data;
    wire [31:0] rf_rs2_data;
    wire [4:0]  rf_rd_addr;
    wire [31:0] rf_rd_data;
    wire        rf_reg_write;
    
    //========================================================================
    // Stage Modules
    //========================================================================
    
    // IF Stage with Branch Predictor
    if_stage_bp u_if_stage (
        .clk(clk),
        .rst_n(rst_n),
        .pc_stall(pc_stall),
        .pc_src(pc_src),
        .pc_target(pc_target),
        .branch_valid(ex_mem_branch_taken),
        .branch_pc(ex_mem_pc_plus4 - 32'd4),
        .branch_taken(ex_mem_branch_taken),
        .branch_target(ex_mem_branch_target),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .pc_out(if_id_pc),
        .pc_plus4_out(if_id_pc_plus4),
        .instr_out(if_id_instr),
        .predict_taken_out(),
        .predict_target_out()
    );
    
    // ID Stage
    id_stage u_id_stage (
        .clk(clk),
        .rst_n(rst_n),
        .pc(if_id_pc),
        .pc_plus4(if_id_pc_plus4),
        .instr(if_id_instr),
        .rs1_data(rf_rs1_data),
        .rs2_data(rf_rs2_data),
        .rs1_addr(rf_rs1_addr),
        .rs2_addr(rf_rs2_addr),
        .forward_mem_data(ex_mem_alu_result),
        .forward_wb_data(rf_rd_data),
        .forward_a_sel(forward_a_id),
        .forward_b_sel(forward_b_id),
        .stall(if_id_stall),
        .flush(id_ex_flush),
        .pc_out(id_ex_pc),
        .pc_plus4_out(id_ex_pc_plus4),
        .rs1_data_out(id_ex_rs1_data),
        .rs2_data_out(id_ex_rs2_data),
        .imm_out(id_ex_imm),
        .rs1_addr_out(id_ex_rs1_addr),
        .rs2_addr_out(id_ex_rs2_addr),
        .rd_addr_out(id_ex_rd_addr),
        .alu_op_out(id_ex_alu_op),
        .alu_src_a_out(id_ex_alu_src_a),
        .alu_src_b_out(id_ex_alu_src_b),
        .mem_read_out(id_ex_mem_read),
        .mem_write_out(id_ex_mem_write),
        .mem_to_reg_out(id_ex_mem_to_reg),
        .reg_write_out(id_ex_reg_write),
        .branch_out(id_ex_branch),
        .jump_out(id_ex_jump),
        .is_ecall(),
        .is_ebreak()
    );
    
    // EX Stage
    ex_stage u_ex_stage (
        .clk(clk),
        .rst_n(rst_n),
        .pc(id_ex_pc),
        .pc_plus4(id_ex_pc_plus4),
        .rs1_data(id_ex_rs1_data),
        .rs2_data(id_ex_rs2_data),
        .imm(id_ex_imm),
        .alu_op(id_ex_alu_op),
        .alu_src_a(id_ex_alu_src_a),
        .alu_src_b(id_ex_alu_src_b),
        .mem_read(id_ex_mem_read),
        .mem_write(id_ex_mem_write),
        .mem_to_reg(id_ex_mem_to_reg),
        .reg_write(id_ex_reg_write),
        .branch(id_ex_branch),
        .jump(id_ex_jump),
        .rs1_addr(id_ex_rs1_addr),
        .rs2_addr(id_ex_rs2_addr),
        .rd_addr(id_ex_rd_addr),
        .forward_mem_data(ex_mem_alu_result),
        .forward_wb_data(rf_rd_data),
        .forward_a_sel(forward_a_ex),
        .forward_b_sel(forward_b_ex),
        .pc_plus4_out(ex_mem_pc_plus4),
        .alu_result_out(ex_mem_alu_result),
        .rs2_data_out(ex_mem_rs2_data),
        .rd_addr_out(ex_mem_rd_addr),
        .mem_read_out(ex_mem_mem_read),
        .mem_write_out(ex_mem_mem_write),
        .mem_to_reg_out(ex_mem_mem_to_reg),
        .reg_write_out(ex_mem_reg_write),
        .branch_taken_out(ex_mem_branch_taken),
        .branch_target_out(ex_mem_branch_target)
    );
    
    // MEM Stage
    mem_stage u_mem_stage (
        .clk(clk),
        .rst_n(rst_n),
        .pc_plus4(ex_mem_pc_plus4),
        .alu_result(ex_mem_alu_result),
        .rs2_data(ex_mem_rs2_data),
        .rd_addr(ex_mem_rd_addr),
        .mem_read(ex_mem_mem_read),
        .mem_write(ex_mem_mem_write),
        .mem_to_reg(ex_mem_mem_to_reg),
        .reg_write(ex_mem_reg_write),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_re(dmem_re),
        .pc_plus4_out(mem_wb_pc_plus4),
        .alu_result_out(mem_wb_alu_result),
        .mem_data_out(mem_wb_mem_data),
        .rd_addr_out(mem_wb_rd_addr),
        .mem_to_reg_out(mem_wb_mem_to_reg),
        .reg_write_out(mem_wb_reg_write)
    );
    
    // WB Stage
    wb_stage u_wb_stage (
        .clk(clk),
        .rst_n(rst_n),
        .pc_plus4(mem_wb_pc_plus4),
        .alu_result(mem_wb_alu_result),
        .mem_data(mem_wb_mem_data),
        .rd_addr(mem_wb_rd_addr),
        .mem_to_reg(mem_wb_mem_to_reg),
        .reg_write(mem_wb_reg_write),
        .wb_rd_addr(rf_rd_addr),
        .wb_rd_data(rf_rd_data),
        .wb_reg_write(rf_reg_write)
    );
    
    //========================================================================
    // Support Modules
    //========================================================================
    
    // Register File
    regfile u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rf_rs1_addr),
        .rs1_data(rf_rs1_data),
        .rs2_addr(rf_rs2_addr),
        .rs2_data(rf_rs2_data),
        .we(rf_reg_write),
        .rd_addr(rf_rd_addr),
        .rd_data(rf_rd_data)
    );
    
    // Hazard Unit
    hazard_unit u_hazard_unit (
        .clk(clk),
        .rst_n(rst_n),
        .if_id_rs1(if_id_instr[19:15]),   // Extract rs1 from IF/ID instruction
        .if_id_rs2(if_id_instr[24:20]),   // Extract rs2 from IF/ID instruction
        .id_ex_rs1(id_ex_rs1_addr),
        .id_ex_rs2(id_ex_rs2_addr),
        .id_ex_rd(id_ex_rd_addr),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_reg_write(id_ex_reg_write),
        .ex_mem_rd(ex_mem_rd_addr),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd(mem_wb_rd_addr),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a_id(forward_a_id),
        .forward_b_id(forward_b_id),
        .forward_a_ex(forward_a_ex),
        .forward_b_ex(forward_b_ex),
        .pc_stall(pc_stall),
        .if_id_stall(if_id_stall),
        .id_ex_flush(id_ex_flush)
    );
    
    // Branch control
    assign pc_src = ex_mem_branch_taken;
    assign pc_target = ex_mem_branch_target;

endmodule
