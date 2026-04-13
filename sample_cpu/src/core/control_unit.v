//============================================================================
// Control Unit - Instruction Decoder for RISC-V RV32I + RV32M + RV32A + RV32F/D
//============================================================================
`include "defines.vh"

module control_unit (
    input  wire [31:0] instr,
    
    // Control signals
    output reg  [5:0]  alu_op,
    output reg         alu_src_a,   // 0: rs1, 1: PC
    output reg         alu_src_b,   // 0: rs2, 1: imm
    output reg         mem_read,
    output reg         mem_write,
    output reg         mem_to_reg,  // 0: ALU result, 1: memory data
    output reg         reg_write,
    output reg         branch,
    output reg         jump,
    output reg  [2:0]  imm_sel,     // Immediate type selector
    output reg         is_ecall,
    output reg         is_ebreak
);

    // Extract fields from instruction
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];
    
    // Opcode definitions
    localparam OPCODE_LOAD     = 7'b0000011;
    localparam OPCODE_STORE    = 7'b0100011;
    localparam OPCODE_OP_IMM   = 7'b0010011;
    localparam OPCODE_OP       = 7'b0110011;
    localparam OPCODE_LUI      = 7'b0110111;
    localparam OPCODE_AUIPC    = 7'b0010111;
    localparam OPCODE_JAL      = 7'b1101111;
    localparam OPCODE_JALR     = 7'b1100111;
    localparam OPCODE_BRANCH   = 7'b1100011;
    localparam OPCODE_AMO      = 7'b0101111;
    localparam OPCODE_LOAD_FP  = 7'b0000111;
    localparam OPCODE_STORE_FP = 7'b0100111;
    localparam OPCODE_MADD     = 7'b1000011;
    localparam OPCODE_MSUB     = 7'b1000111;
    localparam OPCODE_NMSUB    = 7'b1001011;
    localparam OPCODE_NMADD    = 7'b1001111;
    localparam OPCODE_OP_FP    = 7'b1010011;
    localparam OPCODE_SYSTEM   = 7'b1110011;
    
    // Immediate type selectors
    localparam IMM_I = 3'b000;  // I-type
    localparam IMM_S = 3'b001;  // S-type
    localparam IMM_B = 3'b010;  // B-type
    localparam IMM_U = 3'b011;  // U-type
    localparam IMM_J = 3'b100;  // J-type
    
    always @(*) begin
        // Default values
        alu_op     = 6'b0;
        alu_src_a  = 1'b0;  // Use rs1
        alu_src_b  = 1'b0;  // Use rs2
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        reg_write  = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        imm_sel    = IMM_I;
        is_ecall   = 1'b0;
        is_ebreak  = 1'b0;
        
        case (opcode)
            OPCODE_OP_IMM: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;  // Use immediate
                imm_sel   = IMM_I;
                case (funct3)
                    3'b000: alu_op = `ALU_ADD;   // ADDI
                    3'b010: alu_op = `ALU_SLT;   // SLTI
                    3'b011: alu_op = `ALU_SLTU;  // SLTIU
                    3'b100: alu_op = `ALU_XOR;   // XORI
                    3'b110: alu_op = `ALU_OR;    // ORI
                    3'b111: alu_op = `ALU_AND;   // ANDI
                    3'b001: alu_op = `ALU_SLL;   // SLLI
                    3'b101: alu_op = (funct7[5]) ? `ALU_SRA : `ALU_SRL; // SRAI / SRLI
                endcase
            end
            
            OPCODE_OP: begin
                reg_write = 1'b1;
                if (funct7 == 7'b0000001) begin
                    // RV32M Multiply Extension
                    case (funct3)
                        3'b000: alu_op = `ALU_MUL;      // MUL
                        3'b001: alu_op = `ALU_MULH;     // MULH
                        3'b010: alu_op = `ALU_MULHSU;   // MULHSU
                        3'b011: alu_op = `ALU_MULHU;    // MULHU
                        3'b100: alu_op = `ALU_DIV;      // DIV
                        3'b101: alu_op = `ALU_DIVU;     // DIVU
                        3'b110: alu_op = `ALU_REM;      // REM
                        3'b111: alu_op = `ALU_REMU;     // REMU
                    endcase
                end else begin
                    // Standard RV32I ALU operations
                    case (funct3)
                        3'b000: alu_op = (funct7[5]) ? `ALU_SUB : `ALU_ADD; // SUB / ADD
                        3'b001: alu_op = `ALU_SLL;
                        3'b010: alu_op = `ALU_SLT;
                        3'b011: alu_op = `ALU_SLTU;
                        3'b100: alu_op = `ALU_XOR;
                        3'b101: alu_op = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                        3'b110: alu_op = `ALU_OR;
                        3'b111: alu_op = `ALU_AND;
                    endcase
                end
            end
            
            OPCODE_LUI: begin
                reg_write = 1'b1;
                alu_op    = `ALU_LUI;
                alu_src_b = 1'b1;
                imm_sel   = IMM_U;
            end
            
            OPCODE_AUIPC: begin
                reg_write = 1'b1;
                alu_op    = `ALU_AUIPC;
                alu_src_a = 1'b1;  // Use PC
                alu_src_b = 1'b1;  // Use immediate
                imm_sel   = IMM_U;
            end
            
            OPCODE_JAL: begin
                reg_write = 1'b1;
                alu_op    = `ALU_JAL;
                alu_src_a = 1'b1;  // Use PC
                alu_src_b = 1'b1;  // Use immediate
                jump      = 1'b1;
                imm_sel   = IMM_J;
            end
            
            OPCODE_JALR: begin
                reg_write = 1'b1;
                alu_op    = `ALU_JALR;
                alu_src_b = 1'b1;
                jump      = 1'b1;
                imm_sel   = IMM_I;
            end
            
            OPCODE_BRANCH: begin
                branch = 1'b1;
                alu_src_a = 1'b1;  // Use PC for branch target calculation
                alu_src_b = 1'b1;  // Use immediate
                imm_sel = IMM_B;
                case (funct3)
                    3'b000: alu_op = `ALU_BEQ;
                    3'b001: alu_op = `ALU_BNE;
                    3'b100: alu_op = `ALU_BLT;
                    3'b101: alu_op = `ALU_BGE;
                    3'b110: alu_op = `ALU_BLTU;
                    3'b111: alu_op = `ALU_BGEU;
                endcase
            end
            
            OPCODE_LOAD: begin
                reg_write = 1'b1;
                mem_read  = 1'b1;
                mem_to_reg = 1'b1;
                alu_src_b = 1'b1;
                alu_op    = `ALU_ADD;
                imm_sel   = IMM_I;
            end
            
            OPCODE_STORE: begin
                mem_write = 1'b1;
                alu_src_b = 1'b1;
                alu_op    = `ALU_ADD;
                imm_sel   = IMM_S;
            end
            
            OPCODE_SYSTEM: begin
                if (funct3 == 3'b000) begin
                    case (instr[31:20])
                        12'b000000000000: is_ecall = 1'b1;
                        12'b000000000001: is_ebreak = 1'b1;
                    endcase
                end
            end

            OPCODE_AMO: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;  // imm = 0 for AMO address calc
                case (funct3)
                    `FUNCT3_AMO: begin
                        case (funct7[6:2])  // funct5
                            `FUNCT5_LR:       begin mem_read = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_LR;      end
                            `FUNCT5_SC:       begin mem_write = 1'b1; alu_op = `ALU_SC;      end
                            `FUNCT5_AMOSWAP:  begin mem_read = 1'b1; mem_write = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_AMOSWAP; end
                            `FUNCT5_AMOADD:   begin mem_read = 1'b1; mem_write = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_AMOADD;  end
                            `FUNCT5_AMOXOR:   begin mem_read = 1'b1; mem_write = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_AMOXOR;  end
                            `FUNCT5_AMOAND:   begin mem_read = 1'b1; mem_write = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_AMOAND;  end
                            `FUNCT5_AMOOR:    begin mem_read = 1'b1; mem_write = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_AMOOR;   end
                            `FUNCT5_AMOMIN:   begin mem_read = 1'b1; mem_write = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_AMOMIN;  end
                            `FUNCT5_AMOMAX:   begin mem_read = 1'b1; mem_write = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_AMOMAX;  end
                            `FUNCT5_AMOMINU:  begin mem_read = 1'b1; mem_write = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_AMOMINU; end
                            `FUNCT5_AMOMAXU:  begin mem_read = 1'b1; mem_write = 1'b1; mem_to_reg = 1'b1; alu_op = `ALU_AMOMAXU; end
                        endcase
                    end
                endcase
            end

            OPCODE_LOAD_FP: begin
                reg_write = 1'b1;
                mem_read  = 1'b1;
                mem_to_reg = 1'b1;
                alu_src_b = 1'b1;
                alu_op    = `ALU_ADD;  // address = rs1 + imm
                imm_sel   = IMM_I;
            end

            OPCODE_STORE_FP: begin
                mem_write = 1'b1;
                alu_src_b = 1'b1;
                alu_op    = `ALU_ADD;  // address = rs1 + imm
                imm_sel   = IMM_S;
            end

            OPCODE_MADD,
            OPCODE_MSUB,
            OPCODE_NMSUB,
            OPCODE_NMADD: begin
                // Fused multiply-add (skeletal: decoded as FMUL since ALU has only 2 inputs)
                reg_write = 1'b1;
                alu_op    = `ALU_FMUL;
            end

            OPCODE_OP_FP: begin
                reg_write = 1'b1;
                case (funct7)
                    `FUNCT7_FADD_S,
                    `FUNCT7_FADD_D:   alu_op = `ALU_FADD;
                    `FUNCT7_FSUB_S,
                    `FUNCT7_FSUB_D:   alu_op = `ALU_FSUB;
                    `FUNCT7_FMUL_S,
                    `FUNCT7_FMUL_D:   alu_op = `ALU_FMUL;
                    `FUNCT7_FDIV_S,
                    `FUNCT7_FDIV_D:   alu_op = `ALU_FDIV;
                    `FUNCT7_FSQRT_S,
                    `FUNCT7_FSQRT_D:  alu_op = `ALU_FSQRT;
                    `FUNCT7_FSGNJ_S,
                    `FUNCT7_FSGNJ_D:  alu_op = `ALU_PASS_A; // SGNJ* (skeletal)
                    `FUNCT7_FMIN_S,
                    `FUNCT7_FMIN_D:   begin
                        case (funct3)
                            `FUNCT3_FMIN: alu_op = `ALU_FMIN;
                            `FUNCT3_FMAX: alu_op = `ALU_FMAX;
                        endcase
                    end
                    `FUNCT7_FEQ_S,
                    `FUNCT7_FEQ_D:    begin
                        case (funct3)
                            `FUNCT3_FLE: alu_op = `ALU_FLE;
                            `FUNCT3_FLT: alu_op = `ALU_FLT;
                            `FUNCT3_FEQ: alu_op = `ALU_FEQ;
                        endcase
                    end
                    `FUNCT7_FCVT_W_S,
                    `FUNCT7_FCVT_W_D: alu_op = `ALU_FCVT_W_S;
                    `FUNCT7_FCVT_S_W,
                    `FUNCT7_FCVT_D_W: alu_op = `ALU_FCVT_S_W;
                    `FUNCT7_FMV_X_W:  begin
                        case (funct3)
                            `FUNCT3_FMV_X_W: alu_op = `ALU_PASS_A;
                            `FUNCT3_FCLASS:  alu_op = `ALU_FCLASS;
                        endcase
                    end
                    `FUNCT7_FMV_W_X:  alu_op = `ALU_PASS_A;
                endcase
            end

            default: ;
        endcase
    end

endmodule
