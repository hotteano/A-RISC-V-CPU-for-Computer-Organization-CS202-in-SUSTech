//============================================================================
// IF Stage - Instruction Fetch with Branch Prediction
//============================================================================
`include "defines.vh"

module if_stage_bp (
    input  wire        clk,
    input  wire        rst_n,

    // Hazard control
    input  wire        pc_stall,

    // Branch/Jump resolution (from EX/MEM)
    input  wire        pc_src,
    input  wire [31:0] pc_target,
    input  wire        branch_valid,
    input  wire [31:0] branch_pc,
    input  wire        branch_taken,
    input  wire [31:0] branch_target,

    // Instruction memory interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,

    // To ID stage (IF/ID pipeline register)
    output reg  [31:0] pc_out,
    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] instr_out,
    output reg         predict_taken_out,
    output reg  [31:0] predict_target_out
);

    // PC register
    reg [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;

    // Branch prediction signals
    wire        bp_taken;
    wire [31:0] bp_target;

    // PC update logic
    assign pc_plus4 = pc + 32'd4;

    // Select next PC: branch resolution > RAS > BP > sequential
    assign pc_next = pc_src ? pc_target :
                     (ras_valid ? ras_top :
                      (bp_taken ? bp_target : pc_plus4));

    // Instruction memory address
    assign imem_addr = pc;

    // PC update (sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= `RESET_VECTOR;
        end else if (!pc_stall) begin
            pc <= pc_next;
        end
    end

    // IF/ID pipeline register (sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out           <= 32'd0;
            pc_plus4_out     <= 32'd0;
            instr_out        <= 32'd0;
            predict_taken_out <= 1'b0;
            predict_target_out <= 32'd0;
        end else if (!pc_stall) begin
            pc_out           <= pc;
            pc_plus4_out     <= pc_plus4;
            instr_out        <= imem_data;
            predict_taken_out <= bp_taken;
            predict_target_out <= bp_target;
        end
    end

    //========================================================================
    // Branch Predictor
    //========================================================================
    branch_predictor u_bp (
        .clk           (clk),
        .rst_n         (rst_n),
        .pc            (pc),
        .req           (1'b1),
        .predict_taken (bp_taken),
        .predict_target(bp_target),
        .update        (branch_valid),
        .update_pc     (branch_pc),
        .actual_taken  (branch_taken),
        .actual_target (branch_target)
    );

    //========================================================================
    // Return Address Stack
    //========================================================================
    wire [31:0] ras_top;
    wire        ras_valid;

    return_address_stack u_ras (
        .clk        (clk),
        .rst_n      (rst_n),
        .call       (1'b0),
        .ret        (1'b0),
        .call_pc    (pc),
        .return_addr(pc_plus4),
        .ras_top    (ras_top),
        .valid      (ras_valid)
    );

endmodule
