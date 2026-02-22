//============================================================================
// Control Unit - Instruction Decoder for RISC-V RV32I
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
            
            default: ;
        endcase
    end

endmodule
