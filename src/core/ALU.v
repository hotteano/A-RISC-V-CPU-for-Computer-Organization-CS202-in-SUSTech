//============================================================================
// ALU - Arithmetic Logic Unit for RISC-V RV32I
//============================================================================
`include "defines.vh"

module ALU (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [5:0]  alu_op,
    output reg  [31:0] result
);

    // ALU Operation Codes (from defines.vh)
    localparam ALU_ADD     = 6'b000000;
    localparam ALU_SUB     = 6'b000001;
    localparam ALU_AND     = 6'b000010;
    localparam ALU_OR      = 6'b000011;
    localparam ALU_XOR     = 6'b000100;
    localparam ALU_SLL     = 6'b000101;
    localparam ALU_SRL     = 6'b000110;
    localparam ALU_SRA     = 6'b000111;
    localparam ALU_SLT     = 6'b001000;
    localparam ALU_SLTU    = 6'b001001;
    localparam ALU_BEQ     = 6'b001010;
    localparam ALU_BNE     = 6'b001011;
    localparam ALU_BLT     = 6'b001100;
    localparam ALU_BGE     = 6'b001101;
    localparam ALU_BLTU    = 6'b001110;
    localparam ALU_BGEU    = 6'b001111;
    localparam ALU_LUI     = 6'b010000;
    localparam ALU_AUIPC   = 6'b010001;
    localparam ALU_JAL     = 6'b010010;
    localparam ALU_JALR    = 6'b010011;
    localparam ALU_PASS_B  = 6'b011000;
    
    always @(*) begin
        case (alu_op)
            ALU_ADD:    result = a + b;
            ALU_SUB:    result = a - b;
            ALU_AND:    result = a & b;
            ALU_OR:     result = a | b;
            ALU_XOR:    result = a ^ b;
            ALU_SLL:    result = a << b[4:0];
            ALU_SRL:    result = a >> b[4:0];
            ALU_SRA:    result = $signed(a) >>> b[4:0];
            ALU_SLT:    result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU:   result = (a < b) ? 32'd1 : 32'd0;
            ALU_LUI:    result = b;
            ALU_AUIPC:  result = a + b;
            ALU_JAL, 
            ALU_JALR:   result = a + 32'd4;  // Return address
            ALU_PASS_B: result = b;
            default:    result = 32'd0;
        endcase
    end

endmodule
