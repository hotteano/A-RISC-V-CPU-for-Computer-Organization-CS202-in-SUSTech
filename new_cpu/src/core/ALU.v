//============================================================================
// ALU - Arithmetic Logic Unit for RISC-V RV32I + RV32M + RV32A + RV32F/D
// Supports: Basic integer, multiply/divide, atomic (skeletal), FP (skeletal)
//============================================================================
`include "defines.vh"

module ALU (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [5:0]  alu_op,
    output reg  [31:0] result
);

    // ALU Operation Codes
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
    localparam ALU_LUI     = 6'b010000;
    localparam ALU_AUIPC   = 6'b010001;
    localparam ALU_JAL     = 6'b010010;
    localparam ALU_JALR    = 6'b010011;
    localparam ALU_BEQ     = 6'b001010;
    localparam ALU_BNE     = 6'b001011;
    localparam ALU_BLT     = 6'b001100;
    localparam ALU_BGE     = 6'b001101;
    localparam ALU_BLTU    = 6'b001110;
    localparam ALU_BGEU    = 6'b001111;
    localparam ALU_PASS_B  = 6'b011000;

    // RV32M Multiply Extension
    localparam ALU_MUL     = 6'b100000;
    localparam ALU_MULH    = 6'b100001;
    localparam ALU_MULHSU  = 6'b100010;
    localparam ALU_MULHU   = 6'b100011;
    localparam ALU_DIV     = 6'b100100;
    localparam ALU_DIVU    = 6'b100101;
    localparam ALU_REM     = 6'b100110;
    localparam ALU_REMU    = 6'b100111;

    // RV32A Atomic Extension
    localparam ALU_LR      = 6'b011001;
    localparam ALU_SC      = 6'b011010;
    localparam ALU_AMOSWAP = 6'b011011;
    localparam ALU_AMOADD  = 6'b011100;
    localparam ALU_AMOXOR  = 6'b011101;
    localparam ALU_AMOAND  = 6'b011110;
    localparam ALU_AMOOR   = 6'b101000;
    localparam ALU_AMOMIN  = 6'b101001;
    localparam ALU_AMOMAX  = 6'b101010;
    localparam ALU_AMOMINU = 6'b101011;
    localparam ALU_AMOMAXU = 6'b101100;

    // RV32F/D Floating-Point Extension
    localparam ALU_FADD    = 6'b101101;
    localparam ALU_FSUB    = 6'b101110;
    localparam ALU_FMUL    = 6'b101111;
    localparam ALU_FDIV    = 6'b110000;
    localparam ALU_FSQRT   = 6'b110001;
    localparam ALU_FMIN    = 6'b110010;
    localparam ALU_FMAX    = 6'b110011;
    localparam ALU_FEQ     = 6'b110100;
    localparam ALU_FLT     = 6'b110101;
    localparam ALU_FLE     = 6'b110110;
    localparam ALU_FCVT_W_S= 6'b110111;
    localparam ALU_FCVT_S_W= 6'b111000;
    localparam ALU_FCLASS  = 6'b111001;

    // FP helpers (skeletal implementation using Verilog real)
    real fp_a, fp_b, fp_r;

    // FCLASS bit analysis
    wire [7:0]  fp_exp      = a[30:23];
    wire [22:0] fp_mant     = a[22:0];
    wire        fp_is_zero  = (fp_exp == 8'h00) && (fp_mant == 23'h0);
    wire        fp_is_sub   = (fp_exp == 8'h00) && (fp_mant != 23'h0);
    wire        fp_is_norm  = (fp_exp != 8'h00) && (fp_exp != 8'hFF);
    wire        fp_is_inf   = (fp_exp == 8'hFF) && (fp_mant == 23'h0);
    wire        fp_is_nan   = (fp_exp == 8'hFF) && (fp_mant != 23'h0);
    wire        fp_is_snan  = fp_is_nan && !fp_mant[22];
    wire        fp_is_qnan  = fp_is_nan && fp_mant[22];
    wire        fp_sign     = a[31];

    // Signed multiplication results (64-bit)
    wire signed [63:0] mul_signed   = $signed(a) * $signed(b);
    wire signed [63:0] mul_mixed    = $signed(a) * $signed({1'b0, b});
    wire        [63:0] mul_unsigned = a * b;
    
    // Division results
    wire signed [31:0] div_signed   = (b == 32'd0) ? 32'hFFFFFFFF : $signed(a) / $signed(b);
    wire        [31:0] div_unsigned = (b == 32'd0) ? 32'hFFFFFFFF : a / b;
    
    // Remainder results
    wire signed [31:0] rem_signed   = (b == 32'd0) ? a : $signed(a) % $signed(b);
    wire        [31:0] rem_unsigned = (b == 32'd0) ? a : a % b;
    
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
            ALU_BEQ, 
            ALU_BNE, 
            ALU_BLT, 
            ALU_BGE, 
            ALU_BLTU, 
            ALU_BGEU:   result = a + b;  // Branch target = PC + imm
            ALU_PASS_B: result = b;
            
            // RV32M Multiply Extension
            ALU_MUL:    result = mul_signed[31:0];
            ALU_MULH:   result = mul_signed[63:32];
            ALU_MULHSU: result = mul_mixed[63:32];
            ALU_MULHU:  result = mul_unsigned[63:32];
            
            // RV32M Divide Extension
            ALU_DIV:    result = div_signed;
            ALU_DIVU:   result = div_unsigned;
            ALU_REM:    result = rem_signed;
            ALU_REMU:   result = rem_unsigned;

            // RV32A Atomic Extension (skeletal ALU-level implementation)
            ALU_LR:      result = a;
            ALU_SC:      result = b;
            ALU_AMOSWAP: result = b;
            ALU_AMOADD:  result = a + b;
            ALU_AMOXOR:  result = a ^ b;
            ALU_AMOAND:  result = a & b;
            ALU_AMOOR:   result = a | b;
            ALU_AMOMIN:  result = ($signed(a) < $signed(b)) ? a : b;
            ALU_AMOMAX:  result = ($signed(a) > $signed(b)) ? a : b;
            ALU_AMOMINU: result = (a < b) ? a : b;
            ALU_AMOMAXU: result = (a > b) ? a : b;

            // RV32F/D Floating-Point Extension (skeletal implementation)
            // Note: $bitstoshortreal/$shortrealtobits require SystemVerilog-2012
            ALU_FADD:     begin fp_a = $bitstoshortreal(a); fp_b = $bitstoshortreal(b); fp_r = fp_a + fp_b;       result = $shortrealtobits(fp_r); end
            ALU_FSUB:     begin fp_a = $bitstoshortreal(a); fp_b = $bitstoshortreal(b); fp_r = fp_a - fp_b;       result = $shortrealtobits(fp_r); end
            ALU_FMUL:     begin fp_a = $bitstoshortreal(a); fp_b = $bitstoshortreal(b); fp_r = fp_a * fp_b;       result = $shortrealtobits(fp_r); end
            ALU_FDIV:     begin fp_a = $bitstoshortreal(a); fp_b = $bitstoshortreal(b); fp_r = fp_a / fp_b;       result = $shortrealtobits(fp_r); end
            ALU_FSQRT:    begin fp_a = $bitstoshortreal(a); fp_r = $sqrt(fp_a);                                      result = $shortrealtobits(fp_r); end
            ALU_FMIN:     begin fp_a = $bitstoshortreal(a); fp_b = $bitstoshortreal(b); result = (fp_a < fp_b) ? a : b; end
            ALU_FMAX:     begin fp_a = $bitstoshortreal(a); fp_b = $bitstoshortreal(b); result = (fp_a > fp_b) ? a : b; end
            ALU_FEQ:      begin fp_a = $bitstoshortreal(a); fp_b = $bitstoshortreal(b); result = (fp_a == fp_b) ? 32'd1 : 32'd0; end
            ALU_FLT:      begin fp_a = $bitstoshortreal(a); fp_b = $bitstoshortreal(b); result = (fp_a < fp_b)  ? 32'd1 : 32'd0; end
            ALU_FLE:      begin fp_a = $bitstoshortreal(a); fp_b = $bitstoshortreal(b); result = (fp_a <= fp_b) ? 32'd1 : 32'd0; end
            ALU_FCVT_W_S: begin fp_a = $bitstoshortreal(a); result = $signed($rtoi(fp_a)); end
            ALU_FCVT_S_W: begin fp_r = $itor($signed(a)); result = $shortrealtobits(fp_r); end
            ALU_FCLASS:   result = {22'b0, fp_is_qnan, fp_is_snan, fp_is_inf && !fp_sign,
                                    fp_is_norm && !fp_sign, fp_is_sub && !fp_sign,
                                    fp_is_zero && !fp_sign, fp_is_zero && fp_sign,
                                    fp_is_sub && fp_sign, fp_is_norm && fp_sign,
                                    fp_is_inf && fp_sign};

            default:    result = 32'd0;
        endcase
    end

endmodule
