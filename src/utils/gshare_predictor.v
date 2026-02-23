//============================================================================
// Gshare Branch Predictor
// Features: Global History Register (GHR) + Pattern History Table (PHT)
//           2-bit saturating counters for each history pattern
//============================================================================
`include "defines.vh"

module gshare_predictor #(
    parameter GHR_WIDTH    = 10,        // Global History Register width
    parameter PHT_ENTRIES  = 1024       // Pattern History Table size (2^GHR_WIDTH)
)(
    input  wire         clk,
    input  wire         rst_n,
    
    // Prediction request (from IF stage)
    input  wire [31:0]  pc,
    output wire         predict_taken,
    output wire         predict_valid,
    
    // Branch outcome update (from MEM stage)
    input  wire         branch_valid,       // Valid branch to update
    input  wire [31:0]  branch_pc,
    input  wire         branch_taken,       // Actual outcome
    input  wire         branch_is_cond      // Conditional branch flag
);

    // 2-bit saturating counter states
    localparam STRONGLY_NOT_TAKEN = 2'b00;
    localparam WEAKLY_NOT_TAKEN   = 2'b01;
    localparam WEAKLY_TAKEN       = 2'b10;
    localparam STRONGLY_TAKEN     = 2'b11;
    
    // Global History Register (GHR) - records outcomes of recent branches
    reg [GHR_WIDTH-1:0] ghr;
    
    // Pattern History Table (PHT) - 2-bit saturating counters
    reg [1:0] pht [0:PHT_ENTRIES-1];
    
    // Gshare index: XOR of PC and GHR
    wire [GHR_WIDTH-1:0] pc_index = pc[GHR_WIDTH+1:2];
    wire [GHR_WIDTH-1:0] gshare_index = pc_index ^ ghr;
    
    // Update index (for branch update)
    wire [GHR_WIDTH-1:0] update_pc_index = branch_pc[GHR_WIDTH+1:2];
    wire [GHR_WIDTH-1:0] update_index;
    
    // For update, we need the GHR state BEFORE this branch was predicted
    // This requires shifting in the opposite direction or using a snapshot
    // Simplified: use current GHR XORed with current outcome for correction
    reg [GHR_WIDTH-1:0] ghr_snapshot [0:1];  // Simple history buffer
    reg [31:0]          pc_snapshot [0:1];
    reg                 valid_snapshot [0:1];
    
    integer i;
    
    // Prediction logic - use current GHR state
    assign predict_valid = 1'b1;  // Gshare always provides prediction
    assign predict_taken = pht[gshare_index][1];  // MSB of 2-bit counter
    
    // Calculate update index (GHR before this branch)
    // Shift GHR right by 1 and insert previous outcome
    wire [GHR_WIDTH-1:0] ghr_for_update = {ghr[GHR_WIDTH-2:0], 1'b0};
    assign update_index = update_pc_index ^ ghr_for_update;
    
    // Sequential logic: Update GHR and PHT
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset GHR
            ghr <= {GHR_WIDTH{1'b0}};
            
            // Reset PHT to weakly not taken
            for (i = 0; i < PHT_ENTRIES; i = i + 1) begin
                pht[i] <= WEAKLY_NOT_TAKEN;
            end
            
            // Reset snapshots
            for (i = 0; i < 2; i = i + 1) begin
                ghr_snapshot[i] <= {GHR_WIDTH{1'b0}};
                pc_snapshot[i] <= 32'd0;
                valid_snapshot[i] <= 1'b0;
            end
        end else begin
            // Shift snapshots (simple 2-entry FIFO for branch delay)
            ghr_snapshot[1] <= ghr_snapshot[0];
            pc_snapshot[1] <= pc_snapshot[0];
            valid_snapshot[1] <= valid_snapshot[0];
            
            ghr_snapshot[0] <= ghr;
            pc_snapshot[0] <= pc;
            valid_snapshot[0] <= branch_is_cond;
            
            // Update GHR when conditional branch is resolved
            if (branch_valid && branch_is_cond) begin
                // Shift in the actual outcome
                ghr <= {ghr[GHR_WIDTH-2:0], branch_taken};
                
                // Update PHT
                if (branch_taken) begin
                    if (pht[update_index] != STRONGLY_TAKEN)
                        pht[update_index] <= pht[update_index] + 1;
                end else begin
                    if (pht[update_index] != STRONGLY_NOT_TAKEN)
                        pht[update_index] <= pht[update_index] - 1;
                end
            end
        end
    end

endmodule
