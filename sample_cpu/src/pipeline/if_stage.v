//============================================================================
// IF Stage - Instruction Fetch Stage
//============================================================================
`include "defines.vh"

module if_stage (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        pc_stall,
    input  wire        pc_src,       // 0: PC+4, 1: branch/jump target
    
    // PC target for branch/jump
    input  wire [31:0] pc_target,
    
    // Instruction memory interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    
    // To IF/ID pipeline register
    output reg  [31:0] pc_out,
    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] instr_out
);

    reg [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    
    // PC update logic
    assign pc_plus4 = pc + 32'd4;
    assign pc_next = pc_src ? pc_target : pc_plus4;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;  // Reset vector
        else if (!pc_stall)
            pc <= pc_next;
    end
    
    // Instruction memory address
    assign imem_addr = pc;
    
    // Pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out      <= 32'd0;
            pc_plus4_out <= 32'd0;
            instr_out   <= 32'd0;
        end else if (!pc_stall) begin
            pc_out      <= pc;
            pc_plus4_out <= pc_plus4;
            instr_out   <= imem_data;
        end
    end

endmodule
