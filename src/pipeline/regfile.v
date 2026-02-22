//============================================================================
// Register File - 32 General Purpose Registers for RISC-V RV32I
//============================================================================
`include "defines.vh"

module regfile (
    input  wire        clk,
    input  wire        rst_n,
    
    // Read port 1
    input  wire [4:0]  rs1_addr,
    output wire [31:0] rs1_data,
    
    // Read port 2
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs2_data,
    
    // Write port
    input  wire        we,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data
);

    // 32 registers, each 32-bit wide
    reg [31:0] registers [0:31];
    
    integer i;
    
    // Reset and write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end else if (we && rd_addr != 5'd0) begin
            // x0 is hardwired to 0
            registers[rd_addr] <= rd_data;
        end
    end
    
    // Read (asynchronous)
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : registers[rs2_addr];

endmodule
