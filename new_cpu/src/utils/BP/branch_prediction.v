//============================================================================
// Branch Predictor - GShare + Local Predictor (configurable)
//============================================================================
`include "defines.vh"

module branch_predictor (
    input  wire        clk,
    input  wire        rst_n,

    // Prediction request (from IF stage)
    input  wire [31:0] pc,
    input  wire        req,
    output reg         predict_taken,
    output reg  [31:0] predict_target,

    // Update (from EX/MEM stage)
    input  wire        update,
    input  wire [31:0] update_pc,
    input  wire        actual_taken,
    input  wire [31:0] actual_target
);

    // GShare parameters
    localparam GHR_BITS = 8;
    localparam BHT_BITS = 8;
    localparam BHT_SIZE = 1 << BHT_BITS;

    // Global History Register
    reg [GHR_BITS-1:0] ghr;

    // Branch History Table (2-bit saturating counters)
    reg [1:0] bht [0:BHT_SIZE-1];

    // Branch Target Buffer
    localparam BTB_SIZE = 64;
    localparam BTB_IDX  = $clog2(BTB_SIZE);

    reg [31:0] btb_pc   [0:BTB_SIZE-1];
    reg [31:0] btb_target[0:BTB_SIZE-1];
    reg        btb_valid [0:BTB_SIZE-1];

    wire [BTB_IDX-1:0]  btb_index = pc[BTB_IDX+1:2];
    wire [BHT_BITS-1:0] bht_index = pc[BHT_BITS+1:2] ^ ghr;

    integer i;

    // Prediction logic
    always @(*) begin
        if (req && btb_valid[btb_index] && btb_pc[btb_index] == pc) begin
            predict_taken = (bht[bht_index] >= 2'b10);
            predict_target = btb_target[btb_index];
        end else begin
            predict_taken = 1'b0;
            predict_target = pc + 32'd4;
        end
    end

    // Update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ghr <= {GHR_BITS{1'b0}};
            for (i = 0; i < BHT_SIZE; i = i + 1)
                bht[i] <= 2'b01;  // Weakly not-taken
            for (i = 0; i < BTB_SIZE; i = i + 1) begin
                btb_valid[i]  <= 1'b0;
                btb_pc[i]     <= 32'd0;
                btb_target[i] <= 32'd0;
            end
        end else begin
            if (update) begin
                // Update GHR
                ghr <= {ghr[GHR_BITS-2:0], actual_taken};

                // Update BHT
                wire [BHT_BITS-1:0] update_bht_idx = update_pc[BHT_BITS+1:2] ^ ghr;
                if (actual_taken) begin
                    if (bht[update_bht_idx] < 2'b11)
                        bht[update_bht_idx] <= bht[update_bht_idx] + 1;
                end else begin
                    if (bht[update_bht_idx] > 2'b00)
                        bht[update_bht_idx] <= bht[update_bht_idx] - 1;
                end

                // Update BTB
                btb_valid[update_pc[BTB_IDX+1:2]]  <= 1'b1;
                btb_pc[update_pc[BTB_IDX+1:2]]     <= update_pc;
                btb_target[update_pc[BTB_IDX+1:2]] <= actual_target;
            end
        end
    end

endmodule
