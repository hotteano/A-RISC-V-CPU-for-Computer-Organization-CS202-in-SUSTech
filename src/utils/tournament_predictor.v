//============================================================================
// Tournament Branch Predictor
// Features: Combines Local Predictor + Gshare Global Predictor
//           Uses a Meta-chooser (Selector) to pick between them
//============================================================================
`include "defines.vh"

module tournament_predictor #(
    parameter LOCAL_PHT_SIZE  = 1024,   // Local Pattern History Table size
    parameter LOCAL_BHT_SIZE  = 256,    // Local Branch History Table size
    parameter GLOBAL_SIZE     = 4096,   // Global predictor PHT size
    parameter CHOOSER_SIZE    = 4096,   // Chooser table size
    parameter GHR_WIDTH       = 12      // Global History Register width
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
    
    // Chooser states (prefer local vs prefer global)
    localparam STRONGLY_LOCAL     = 2'b00;
    localparam WEAKLY_LOCAL       = 2'b01;
    localparam WEAKLY_GLOBAL      = 2'b10;
    localparam STRONGLY_GLOBAL    = 2'b11;
    
    //========================================================================
    // Local Predictor (BHT + Local PHT)
    //========================================================================
    
    // Branch History Table - stores per-branch local history
    reg [$clog2(LOCAL_PHT_SIZE)-1:0] bht [0:LOCAL_BHT_SIZE-1];
    
    // Local Pattern History Table - indexed by local history
    reg [1:0] local_pht [0:LOCAL_PHT_SIZE-1];
    
    wire [$clog2(LOCAL_BHT_SIZE)-1:0] local_bht_index = branch_pc[$clog2(LOCAL_BHT_SIZE)+1:2];
    wire [$clog2(LOCAL_PHT_SIZE)-1:0] local_pht_index;
    reg  [$clog2(LOCAL_PHT_SIZE)-1:0] local_pht_index_reg;
    
    // Local prediction
    wire [$clog2(LOCAL_BHT_SIZE)-1:0] pred_local_bht_index = pc[$clog2(LOCAL_BHT_SIZE)+1:2];
    wire [$clog2(LOCAL_PHT_SIZE)-1:0] pred_local_pht_index = bht[pred_local_bht_index];
    wire local_pred = local_pht[pred_local_pht_index][1];
    
    //========================================================================
    // Global Predictor (GHR + Global PHT)
    //========================================================================
    
    // Global History Register
    reg [GHR_WIDTH-1:0] ghr;
    
    // Global Pattern History Table
    reg [1:0] global_pht [0:GLOBAL_SIZE-1];
    
    // Global prediction (Gshare style indexing)
    wire [$clog2(GLOBAL_SIZE)-1:0] global_pc_index = pc[$clog2(GLOBAL_SIZE)+1:2];
    wire [$clog2(GLOBAL_SIZE)-1:0] global_index = global_pc_index ^ ghr[GHR_WIDTH-1:GHR_WIDTH-$clog2(GLOBAL_SIZE)];
    wire global_pred = global_pht[global_index][1];
    
    //========================================================================
    // Chooser (Meta-predictor)
    //========================================================================
    
    // Chooser table - indexed by PC (can also use GHR)
    reg [1:0] chooser [0:CHOOSER_SIZE-1];
    
    wire [$clog2(CHOOSER_SIZE)-1:0] chooser_index = pc[$clog2(CHOOSER_SIZE)+1:2];
    wire [1:0] chooser_state = chooser[chooser_index];
    
    // Final prediction: use chooser to select between local and global
    assign predict_taken = (chooser_state[1] == 1'b0) ? local_pred : global_pred;
    assign predict_valid = 1'b1;
    
    //========================================================================
    // Update indices for MEM stage
    //========================================================================
    
    // Update indices calculated from branch_pc
    wire [$clog2(LOCAL_BHT_SIZE)-1:0] update_local_bht_index = branch_pc[$clog2(LOCAL_BHT_SIZE)+1:2];
    wire [$clog2(GLOBAL_SIZE)-1:0] update_global_pc_index = branch_pc[$clog2(GLOBAL_SIZE)+1:2];
    wire [$clog2(CHOOSER_SIZE)-1:0] update_chooser_index = branch_pc[$clog2(CHOOSER_SIZE)+1:2];
    
    // For local predictor update
    wire [$clog2(LOCAL_PHT_SIZE)-1:0] update_local_pht_index = bht[update_local_bht_index];
    
    // For global predictor update (GHR before update)
    wire [$clog2(GLOBAL_SIZE)-1:0] update_global_index = update_global_pc_index ^ 
                                                         {ghr[GHR_WIDTH-2:0], 1'b0}[GHR_WIDTH-1:GHR_WIDTH-$clog2(GLOBAL_SIZE)];
    
    integer i;
    
    // Sequential logic: Update all predictors
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset local predictor
            for (i = 0; i < LOCAL_BHT_SIZE; i = i + 1) begin
                bht[i] <= {$clog2(LOCAL_PHT_SIZE){1'b0}};
            end
            for (i = 0; i < LOCAL_PHT_SIZE; i = i + 1) begin
                local_pht[i] <= WEAKLY_NOT_TAKEN;
            end
            
            // Reset global predictor
            ghr <= {GHR_WIDTH{1'b0}};
            for (i = 0; i < GLOBAL_SIZE; i = i + 1) begin
                global_pht[i] <= WEAKLY_NOT_TAKEN;
            end
            
            // Reset chooser
            for (i = 0; i < CHOOSER_SIZE; i = i + 1) begin
                chooser[i] <= WEAKLY_LOCAL;  // Slightly prefer local initially
            end
        end else if (branch_valid && branch_is_cond) begin
            // Update GHR
            ghr <= {ghr[GHR_WIDTH-2:0], branch_taken};
            
            // Update Local BHT (shift in outcome)
            bht[update_local_bht_index] <= {bht[update_local_bht_index][$clog2(LOCAL_PHT_SIZE)-2:0], branch_taken};
            
            // Update Local PHT
            if (branch_taken) begin
                if (local_pht[update_local_pht_index] != STRONGLY_TAKEN)
                    local_pht[update_local_pht_index] <= local_pht[update_local_pht_index] + 1;
            end else begin
                if (local_pht[update_local_pht_index] != STRONGLY_NOT_TAKEN)
                    local_pht[update_local_pht_index] <= local_pht[update_local_pht_index] - 1;
            end
            
            // Update Global PHT
            if (branch_taken) begin
                if (global_pht[update_global_index] != STRONGLY_TAKEN)
                    global_pht[update_global_index] <= global_pht[update_global_index] + 1;
            end else begin
                if (global_pht[update_global_index] != STRONGLY_NOT_TAKEN)
                    global_pht[update_global_index] <= global_pht[update_global_index] - 1;
            end
            
            // Update Chooser (only when predictions differ)
            if (local_pred != global_pred) begin
                if (global_pred == branch_taken) begin
                    // Global was correct, strengthen global
                    if (chooser[update_chooser_index] != STRONGLY_GLOBAL)
                        chooser[update_chooser_index] <= chooser[update_chooser_index] + 1;
                end else begin
                    // Local was correct, strengthen local
                    if (chooser[update_chooser_index] != STRONGLY_LOCAL)
                        chooser[update_chooser_index] <= chooser[update_chooser_index] - 1;
                end
            end
        end
    end

endmodule
