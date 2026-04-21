//============================================================================
// Register File - 32 x 32-bit registers (x0 is hardwired to 0)
//============================================================================
`include "defines.vh"

module regfile (
    input  wire        clk,
    input  wire        rst_n,

    // Read ports (asynchronous)
    input  wire [4:0]  rs1_addr,
    output wire [31:0] rs1_data,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs2_data,

    // Write port (synchronous)
    input  wire        we,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data
);

    // 32 registers, each 32-bit wide
    reg [31:0] regs [0:31];
    integer i;

    // Asynchronous read (x0 always returns 0)
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];

    // Synchronous write (x0 is not writable)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'd0;
            end
        end else if (we && rd_addr != 5'd0) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule
