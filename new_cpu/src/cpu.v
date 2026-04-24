//============================================================================
// RISC-V CPU Main Modules
//============================================================================
`include "defines.vh"

module riscv_cpu_top (
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction memory interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    output wire        imem_re,
    input  wire        imem_ready,

    // Data memory interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    output wire        dmem_we,
    output wire        dmem_re,
    output wire [3:0]  dmem_wstrb,
    input  wire        dmem_ready,

    // External interrupts (from PLIC)
    input  wire        plic_meip,
    input  wire        plic_seip,

    // Timer / software interrupts (from CLINT)
    input  wire        clint_mtip,
    input  wire        clint_msip,

    // Page faults (from MMU)
    input  wire        page_fault_inst,
    input  wire        page_fault_load,
    input  wire        page_fault_store,

    // PMP fault (from PMP unit)
    input  wire        pmp_fault,

    // CSR export for MMU / SoC
    output wire [31:0] csr_mstatus,
    output wire [1:0]  cpu_priv_mode
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
    wire [1:0]  id_ex_mem_size;
    wire        id_ex_mem_unsigned;
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
    wire [1:0]  ex_mem_mem_size;
    wire        ex_mem_mem_unsigned;
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

    // Memory stall
    wire        memory_stall = !imem_ready || !dmem_ready;

    // Exception signals from ID stage
    wire        id_ecall;
    wire        id_ebreak;
    wire        id_mret;
    wire        id_sret;
    wire        id_wfi;
    wire        id_sfence_vma;
    wire        id_csr_we;
    wire        id_csr_re;
    wire [2:0]  id_csr_op;
    
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
    
    // Instruction fetch enable
    assign imem_re = 1'b1;

    // IF Stage with Branch Predictor
    if_stage_bp u_if_stage (
        .clk(clk),
        .rst_n(rst_n),
        .pc_stall(pc_stall || memory_stall),
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
        .stall(if_id_stall || memory_stall),
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
        .mem_size_out(id_ex_mem_size),
        .mem_unsigned_out(id_ex_mem_unsigned),
        .reg_write_out(id_ex_reg_write),
        .branch_out(id_ex_branch),
        .jump_out(id_ex_jump),
        .is_ecall(id_ecall),
        .is_ebreak(id_ebreak),
        .is_mret(id_mret),
        .is_sret(id_sret),
        .is_wfi(id_wfi),
        .is_sfence_vma(id_sfence_vma),
        .csr_we(id_csr_we),
        .csr_re(id_csr_re),
        .csr_op(id_csr_op)
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
        .mem_size(id_ex_mem_size),
        .mem_unsigned(id_ex_mem_unsigned),
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
        .stall(memory_stall),
        .pc_plus4_out(ex_mem_pc_plus4),
        .alu_result_out(ex_mem_alu_result),
        .rs2_data_out(ex_mem_rs2_data),
        .rd_addr_out(ex_mem_rd_addr),
        .mem_read_out(ex_mem_mem_read),
        .mem_write_out(ex_mem_mem_write),
        .mem_to_reg_out(ex_mem_mem_to_reg),
        .mem_size_out(ex_mem_mem_size),
        .mem_unsigned_out(ex_mem_mem_unsigned),
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
        .mem_size(ex_mem_mem_size),
        .mem_unsigned(ex_mem_mem_unsigned),
        .reg_write(ex_mem_reg_write),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_re(dmem_re),
        .dmem_ready(dmem_ready),
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
    
    //========================================================================
    // Privileged Architecture Modules (instantiated, full integration TBD)
    //========================================================================

    // CSR Register File
    wire [31:0] csr_rdata;
    wire [31:0] csr_mie_out;
    wire [31:0] csr_mip_out;
    wire [31:0] csr_mstatus_out;
    wire [31:0] trap_return_pc;

    // Trap aggregation
    wire        trap_enter = ecall_trap || ebreak_trap || page_fault_inst || page_fault_load || page_fault_store || pmp_fault;
    wire [31:0] trap_cause = ecall_trap ? (priv_mode == `PRIV_M ? `CAUSE_ECALL_M : `CAUSE_ECALL_S) :
                             ebreak_trap ? `CAUSE_BREAKPOINT :
                             page_fault_inst ? `CAUSE_INST_PAGE_FAULT :
                             page_fault_load ? `CAUSE_LOAD_PAGE_FAULT :
                             page_fault_store ? `CAUSE_STORE_PAGE_FAULT :
                             pmp_fault ? `CAUSE_LOAD_ACCESS_FAULT : 32'd0;

    csr_reg u_csr_reg (
        .clk              (clk),
        .rst_n            (rst_n),
        .addr             (if_id_instr[31:20]),
        .rdata            (csr_rdata),
        .wdata            (rf_rd_data),
        .we               (id_csr_we),
        .re               (id_csr_re),
        .priv_mode        (priv_mode),
        .trap_enter       (trap_enter),
        .trap_pc          (if_id_pc),
        .trap_cause       (trap_cause),
        .trap_val         (32'd0),
        .trap_priv        (trap_target_priv),
        .mret             (mret_exec),
        .sret             (sret_exec),
        .trap_return_pc   (trap_return_pc),
        .mie_out          (csr_mie_out),
        .mip_out          (csr_mip_out),
        .mstatus_out      (csr_mstatus_out),
        .timer_irq_m      (clint_mtip),
        .timer_irq_s      (clint_mtip),
        .soft_irq_m       (clint_msip),
        .soft_irq_s       (clint_msip),
        .ext_irq_m        (plic_meip),
        .ext_irq_s        (plic_seip)
    );

    // Privilege Control
    wire [1:0] priv_mode;
    wire       illegal_priv_access;

    privilege_control u_privilege (
        .clk               (clk),
        .rst_n             (rst_n),
        .priv_mode         (priv_mode),
        .trap_enter        (trap_enter),
        .trap_target_priv  (trap_target_priv),
        .mret              (mret_exec),
        .sret              (sret_exec),
        .uret              (1'b0),
        .mstatus_mpp       (csr_mstatus_out[`MSTATUS_MPP_HI:`MSTATUS_MPP_LO]),
        .mstatus_spp       (csr_mstatus_out[`MSTATUS_SPP]),
        .illegal_priv_access(illegal_priv_access)
    );

    // ECALL Handler
    wire        ecall_trap;
    wire [31:0] ecall_cause;
    wire [31:0] ecall_trap_pc;

    ecall_handler u_ecall (
        .ecall     (id_ecall),
        .priv_mode (priv_mode),
        .trap      (ecall_trap),
        .trap_cause(ecall_cause),
        .trap_pc   (if_id_pc)
    );

    // EBREAK Handler
    wire        ebreak_trap;
    wire [31:0] ebreak_cause;
    wire [31:0] ebreak_trap_pc;

    ebreak_handler u_ebreak (
        .ebreak    (id_ebreak),
        .pc        (if_id_pc),
        .trap      (ebreak_trap),
        .trap_cause(ebreak_cause),
        .trap_pc   (ebreak_trap_pc)
    );

    // MRET Handler
    wire        mret_exec;
    wire [31:0] mret_pc;
    wire [1:0]  mret_priv;

    mret_handler u_mret (
        .mret_instr (id_mret),
        .mstatus    (csr_mstatus_out),
        .mret       (mret_exec),
        .return_pc  (mret_pc),
        .return_priv(mret_priv)
    );

    // SRET Handler
    wire        sret_exec;
    wire [31:0] sret_pc;
    wire [1:0]  sret_priv;

    sret_handler u_sret (
        .sret_instr (id_sret),
        .mstatus    (csr_mstatus_out),
        .sret       (sret_exec),
        .return_pc  (sret_pc),
        .return_priv(sret_priv)
    );

    // WFI Handler
    wire wfi_stall;
    wire wfi_wakeup;

    wfi_handler u_wfi (
        .clk          (clk),
        .rst_n        (rst_n),
        .wfi_instr    (id_wfi),
        .mip_msip     (csr_mip_out[`MIP_MSIP]),
        .mip_mtip     (csr_mip_out[`MIP_MTIP]),
        .mip_meip     (csr_mip_out[`MIP_MEIP]),
        .mip_ssip     (csr_mip_out[`MIP_SSIP]),
        .mip_stip     (csr_mip_out[`MIP_STIP]),
        .mip_seip     (csr_mip_out[`MIP_SEIP]),
        .mstatus_mie  (csr_mstatus_out[`MSTATUS_MIE]),
        .mstatus_sie  (csr_mstatus_out[`MSTATUS_SIE]),
        .mie          (csr_mie_out),
        .priv_mode    (priv_mode),
        .wfi_stall    (wfi_stall),
        .wfi_wakeup   (wfi_wakeup)
    );

    // Interrupt Delegation
    wire [1:0] trap_target_priv;

    interrupt_delegation u_int_deleg (
        .priv_mode     (priv_mode),
        .medeleg       (32'd0),
        .mideleg       (32'd0),
        .trap_cause    (32'd0),
        .is_interrupt  (1'b0),
        .target_priv   (trap_target_priv)
    );

    // FENCE.I Handler
    wire icache_flush;
    wire pipeline_flush_fence_i;

    fence_i_handler u_fence_i (
        .fence_i        (1'b0),
        .icache_flush   (icache_flush),
        .pipeline_flush (pipeline_flush_fence_i)
    );

    // SFENCE.VMA Handler
    wire sfence_illegal;
    wire tlb_flush;
    wire dcache_flush;

    sfence_vma_handler u_sfence_vma (
        .sfence_vma     (id_sfence_vma),
        .priv_mode      (priv_mode),
        .illegal_instr  (sfence_illegal),
        .tlb_flush      (tlb_flush),
        .dcache_flush   (dcache_flush)
    );

    // Branch control
    assign pc_src = ex_mem_branch_taken;
    assign pc_target = ex_mem_branch_target;

    // CSR / Privilege exports for SoC MMU
    assign csr_mstatus  = csr_mstatus_out;
    assign cpu_priv_mode = priv_mode;

endmodule
