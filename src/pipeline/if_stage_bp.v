//============================================================================
// IF Stage with Branch Prediction
//============================================================================
`include "defines.vh"

module if_stage_bp (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        pc_stall,
    input  wire        pc_src,       // Actual branch taken
    input  wire [31:0] pc_target,    // Actual branch target
    
    // Branch prediction update (from MEM stage)
    input  wire        branch_valid,
    input  wire [31:0] branch_pc,
    input  wire        branch_taken,
    input  wire [31:0] branch_target,
    
    // Instruction memory interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    
    // To IF/ID pipeline register
    output reg  [31:0] pc_out,
    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] instr_out,
    output reg         predict_taken_out,
    output reg  [31:0] predict_target_out
);

    wire [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    
    // Branch predictor signals
    wire        predict_taken;
    wire [31:0] predict_target;
    wire        predict_valid;
    
    // Select predicted target if valid
    wire [31:0] pc_predicted = (predict_valid && predict_taken) ? predict_target : pc_plus4;
    
    // PC update logic
    assign pc_plus4 = pc + 32'd4;
    assign pc_next = pc_src ? pc_target : pc_predicted;
    
    // PC register
    reg [31:0] pc_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_reg <= 32'h0000_0000;
        else if (!pc_stall)
            pc_reg <= pc_next;
    end
    assign pc = pc_reg;
    
    // Instruction memory address
    assign imem_addr = pc;
    
    // Branch predictor instantiation
    branch_predictor #(
        .BTB_ENTRIES(8),
        .ADDR_WIDTH(32)
    ) u_bp (
        .clk(clk),
        .rst_n(rst_n),
        .pc(pc),
        .predict_taken(predict_taken),
        .predict_target(predict_target),
        .predict_valid(predict_valid),
        .branch_valid(branch_valid),
        .branch_pc(branch_pc),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .branch_is_cond(1'b1)
    );
    
    // Pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out            <= 32'd0;
            pc_plus4_out      <= 32'd0;
            instr_out         <= 32'd0;
            predict_taken_out <= 1'b0;
            predict_target_out <= 32'd0;
        end else if (!pc_stall) begin
            pc_out            <= pc;
            pc_plus4_out      <= pc_plus4;
            instr_out         <= imem_data;
            predict_taken_out <= predict_taken;
            predict_target_out <= predict_target;
        end
    end

endmodule
