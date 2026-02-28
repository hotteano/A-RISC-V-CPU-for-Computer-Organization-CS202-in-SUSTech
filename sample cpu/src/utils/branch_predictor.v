//============================================================================
// Branch Predictor with 2-bit Saturating Counter and BTB
//============================================================================
`include "defines.vh"

module branch_predictor #(
    parameter BTB_ENTRIES = 8,
    parameter ADDR_WIDTH  = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Prediction request (from IF stage)
    input  wire [ADDR_WIDTH-1:0] pc,
    output reg                   predict_taken,
    output reg  [ADDR_WIDTH-1:0] predict_target,
    output reg                   predict_valid,
    
    // Branch outcome update (from MEM stage)
    input  wire                  branch_valid,
    input  wire [ADDR_WIDTH-1:0] branch_pc,
    input  wire                  branch_taken,
    input  wire [ADDR_WIDTH-1:0] branch_target,
    input  wire                  branch_is_cond
);

    // 2-bit saturating counter states
    localparam STRONGLY_NOT_TAKEN = 2'b00;
    localparam WEAKLY_NOT_TAKEN   = 2'b01;
    localparam WEAKLY_TAKEN       = 2'b10;
    localparam STRONGLY_TAKEN     = 2'b11;
    
    // BTB entry structure
    reg [1:0]  bht [0:BTB_ENTRIES-1];  // Branch History Table
    reg        btb_valid [0:BTB_ENTRIES-1];
    reg [31:0] btb_target [0:BTB_ENTRIES-1];
    reg [31:0] btb_tag [0:BTB_ENTRIES-1];
    
    wire [$clog2(BTB_ENTRIES)-1:0] pc_index = pc[$clog2(BTB_ENTRIES)+1:2];
    wire [31:0] pc_tag = pc[31:$clog2(BTB_ENTRIES)+2];
    
    integer i;
    
    // Prediction logic
    always @(*) begin
        if (btb_valid[pc_index] && btb_tag[pc_index] == pc_tag) begin
            predict_valid = 1'b1;
            predict_target = btb_target[pc_index];
            predict_taken = bht[pc_index][1];  // MSB of 2-bit counter
        end else begin
            predict_valid = 1'b0;
            predict_target = 32'd0;
            predict_taken = 1'b0;
        end
    end
    
    // Update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < BTB_ENTRIES; i = i + 1) begin
                bht[i] <= 2'b01;  // Weakly not taken
                btb_valid[i] <= 1'b0;
                btb_target[i] <= 32'd0;
                btb_tag[i] <= 32'd0;
            end
        end else if (branch_valid) begin
            // Update BTB
            btb_valid[pc_index] <= 1'b1;
            btb_target[pc_index] <= branch_target;
            btb_tag[pc_index] <= pc_tag;
            
            // Update 2-bit saturating counter
            if (branch_taken) begin
                if (bht[pc_index] != STRONGLY_TAKEN)
                    bht[pc_index] <= bht[pc_index] + 1;
            end else begin
                if (bht[pc_index] != STRONGLY_NOT_TAKEN)
                    bht[pc_index] <= bht[pc_index] - 1;
            end
        end
    end

endmodule
