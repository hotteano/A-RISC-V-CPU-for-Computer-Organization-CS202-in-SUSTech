//============================================================================
// SBI - Supervisor Binary Interface (firmware interface)
// Simple proxy for ecalls from S-mode
//============================================================================
`include "defines.vh"

module sbi_interface (
    input  wire        clk,
    input  wire        rst_n,

    // ECALL from S-mode
    input  wire        sbi_ecall,
    input  wire [31:0] sbi_a0,      // Function argument
    input  wire [31:0] sbi_a1,      // Function argument
    input  wire [31:0] sbi_a2,      // Function argument
    input  wire [31:0] sbi_a6,      // Function ID
    input  wire [31:0] sbi_a7,      // Extension ID

    // Return values
    output reg  [31:0] sbi_ret0,
    output reg  [31:0] sbi_ret1,
    output reg         sbi_done
);

    // SBI extension IDs
    localparam SBI_EXT_BASE     = 32'h10;
    localparam SBI_EXT_TIME     = 32'h54494D45;
    localparam SBI_EXT_IPI      = 32'h735049;
    localparam SBI_EXT_HSM      = 32'h48534D;
    localparam SBI_EXT_SRST     = 32'h53525354;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sbi_ret0 <= 32'd0;
            sbi_ret1 <= 32'd0;
            sbi_done <= 1'b0;
        end else begin
            sbi_done <= 1'b0;
            if (sbi_ecall) begin
                sbi_done <= 1'b1;
                case (sbi_a7)
                    SBI_EXT_BASE: begin
                        // Base extension
                        case (sbi_a6)
                            32'h0: begin sbi_ret0 = 32'h01; sbi_ret1 = 32'h00; end // Get spec version
                            32'h1: begin sbi_ret0 = 32'h01; sbi_ret1 = 32'h00; end // Get impl ID
                            default: begin sbi_ret0 = 32'hFFFFFFFF; sbi_ret1 = 32'hFFFFFFFF; end
                        endcase
                    end
                    SBI_EXT_TIME: begin
                        // Timer extension
                        sbi_ret0 = 32'd0;
                        sbi_ret1 = 32'd0;
                    end
                    default: begin
                        sbi_ret0 = 32'hFFFFFFFF;  // SBI_ERR_NOT_SUPPORTED
                        sbi_ret1 = 32'd0;
                    end
                endcase
            end
        end
    end

endmodule
