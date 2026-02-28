//============================================================================
// Advanced Branch Predictor Unit
// Combines: BTB (Branch Target Buffer)
//           Tournament Predictor (Local + Gshare Global)
//           RAS (Return Address Stack) for function returns
//============================================================================
`include "defines.vh"

module advanced_branch_predictor #(
    parameter BTB_ENTRIES      = 32,
    parameter RAS_DEPTH        = 16,
    parameter GHR_WIDTH        = 10,
    parameter LOCAL_BHT_SIZE   = 256,
    parameter LOCAL_PHT_SIZE   = 1024,
    parameter GLOBAL_PHT_SIZE  = 4096,
    parameter CHOOSER_SIZE     = 4096,
    parameter ADDR_WIDTH       = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    //========================================================================
    // Prediction Request (from IF stage)
    //========================================================================
    input  wire [ADDR_WIDTH-1:0] pc,
    input  wire [ADDR_WIDTH-1:0] pc_plus4,
    input  wire [31:0]           instr,         // Instruction word for immediate
    input  wire [4:0]            rs1,           // rs1 for JALR
    input  wire [4:0]            rd,            // rd for call/return detection
    input  wire [6:0]            opcode,        // Opcode to detect branch type
    input  wire [2:0]            funct3,        // funct3 for branch type
    
    // Prediction output
    output reg                   predict_taken,
    output reg  [ADDR_WIDTH-1:0] predict_target,
    output reg                   predict_valid,
    
    //========================================================================
    // Branch Outcome Update (from MEM stage)
    //========================================================================
    input  wire                  branch_valid,       // Valid branch instruction
    input  wire [ADDR_WIDTH-1:0] branch_pc,
    input  wire                  branch_taken,       // Actual outcome
    input  wire [ADDR_WIDTH-1:0] branch_target,      // Actual target
    input  wire                  branch_is_cond,     // Conditional branch
    input  wire                  branch_is_call,     // Function call (JAL/JALR with link)
    input  wire                  branch_is_return,   // Function return (JALR to ra)
    input  wire                  branch_mispredict   // Misprediction occurred
);

    //========================================================================
    // Local Parameters (must be defined before use)
    //========================================================================
    localparam STRONGLY_NOT_TAKEN = 2'b00;
    localparam WEAKLY_NOT_TAKEN   = 2'b01;
    localparam WEAKLY_TAKEN       = 2'b10;
    localparam STRONGLY_TAKEN     = 2'b11;
    localparam STRONGLY_LOCAL     = 2'b00;
    localparam WEAKLY_LOCAL       = 2'b01;
    localparam WEAKLY_GLOBAL      = 2'b10;
    localparam STRONGLY_GLOBAL    = 2'b11;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;
    
    wire is_branch = (opcode == OPCODE_BRANCH);
    wire is_jal    = (opcode == OPCODE_JAL);
    wire is_jalr   = (opcode == OPCODE_JALR);
    wire is_conditional = is_branch;
    
    // Call/Return detection for IF stage
    wire ra_reg = (rs1 == 5'd1);  // x1/ra
    wire link_reg = (rd == 5'd1) || (rd == 5'd5);  // rd = ra or t0 (common for calls)
    wire if_is_call = (is_jal || is_jalr) && link_reg;
    wire if_is_return = is_jalr && ra_reg && (rd == 5'd0);  // JR ra
    
    // JAL immediate extraction
    wire [31:0] jal_imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    wire [31:0] jal_target = pc + jal_imm;
    
    //========================================================================
    // BTB (Branch Target Buffer)
    //========================================================================
    reg        btb_valid  [0:BTB_ENTRIES-1];
    reg [31:0] btb_tag    [0:BTB_ENTRIES-1];
    reg [31:0] btb_target [0:BTB_ENTRIES-1];
    reg        btb_is_call [0:BTB_ENTRIES-1];
    reg        btb_is_ret  [0:BTB_ENTRIES-1];
    
    wire [$clog2(BTB_ENTRIES)-1:0] btb_index = pc[$clog2(BTB_ENTRIES)+1:2];
    wire [31:0] btb_pc_tag = pc[31:$clog2(BTB_ENTRIES)+2];
    
    wire btb_hit = btb_valid[btb_index] && (btb_tag[btb_index] == btb_pc_tag);
    wire [31:0] btb_predicted_target = btb_target[btb_index];
    wire btb_predicted_call = btb_is_call[btb_index];
    wire btb_predicted_ret = btb_is_ret[btb_index];
    
    //========================================================================
    // Tournament Predictor (Local + Global)
    //========================================================================
    
    //----- Local Predictor -----
    reg [$clog2(LOCAL_PHT_SIZE)-1:0] local_bht [0:LOCAL_BHT_SIZE-1];
    reg [1:0] local_pht [0:LOCAL_PHT_SIZE-1];
    
    wire [$clog2(LOCAL_BHT_SIZE)-1:0] local_bht_idx = pc[$clog2(LOCAL_BHT_SIZE)+1:2];
    wire [$clog2(LOCAL_PHT_SIZE)-1:0] local_pht_idx = local_bht[local_bht_idx];
    wire local_pred = local_pht[local_pht_idx][1];
    
    //----- Global Predictor (Gshare) -----
    reg [GHR_WIDTH-1:0] ghr;
    reg [1:0] global_pht [0:GLOBAL_PHT_SIZE-1];
    
    wire [$clog2(GLOBAL_PHT_SIZE)-1:0] global_pc_idx = pc[$clog2(GLOBAL_PHT_SIZE)+1:2];
    wire [$clog2(GLOBAL_PHT_SIZE)-1:0] global_idx = global_pc_idx ^ 
                                                     ghr[GHR_WIDTH-1:GHR_WIDTH-$clog2(GLOBAL_PHT_SIZE)];
    wire global_pred = global_pht[global_idx][1];
    
    //----- Chooser -----
    reg [1:0] chooser [0:CHOOSER_SIZE-1];
    wire [$clog2(CHOOSER_SIZE)-1:0] chooser_idx = pc[$clog2(CHOOSER_SIZE)+1:2];
    wire [1:0] chooser_state = chooser[chooser_idx];
    wire tournament_pred = (chooser_state[1] == 1'b0) ? local_pred : global_pred;
    
    //========================================================================
    // Return Address Stack (RAS)
    //========================================================================
    reg [ADDR_WIDTH-1:0] ras_stack [0:RAS_DEPTH-1];
    reg [$clog2(RAS_DEPTH)-1:0] ras_ptr;
    wire [ADDR_WIDTH-1:0] ras_top = (ras_ptr > 0) ? ras_stack[ras_ptr-1] : pc_plus4;
    wire ras_valid = (ras_ptr > 0);
    
    //========================================================================
    // Combined Prediction Logic
    //========================================================================
    
    // For calls: push return address
    // For returns: use RAS
    // For branches: use BTB + Tournament predictor
    // For JAL: use BTB target or PC-relative
    
    always @(*) begin
        predict_valid = 1'b0;
        predict_taken = 1'b0;
        predict_target = pc_plus4;
        
        if (if_is_return && ras_valid) begin
            // Return instruction: use RAS
            predict_valid = 1'b1;
            predict_taken = 1'b1;
            predict_target = ras_top;
        end else if (if_is_call) begin
            // Call instruction: predict taken, use BTB or JAL target
            predict_valid = 1'b1;
            predict_taken = 1'b1;
            if (is_jal) begin
                // JAL: PC-relative target
                predict_target = jal_target;
            end else if (btb_hit) begin
                predict_target = btb_predicted_target;
            end
        end else if (is_branch && btb_hit) begin
            // Conditional branch: use tournament predictor for direction, BTB for target
            predict_valid = 1'b1;
            predict_taken = tournament_pred;
            predict_target = btb_predicted_target;
        end else if (is_jal) begin
            // Unconditional JAL: always taken
            predict_valid = 1'b1;
            predict_taken = 1'b1;
            predict_target = jal_target;
        end else if (is_jalr && btb_hit) begin
            // JALR: use BTB target
            predict_valid = 1'b1;
            predict_taken = 1'b1;
            predict_target = btb_predicted_target;
        end
    end
    
    //========================================================================
    // Update Logic
    //========================================================================
    
    // Update indices
    wire [$clog2(LOCAL_BHT_SIZE)-1:0] upd_local_bht_idx = branch_pc[$clog2(LOCAL_BHT_SIZE)+1:2];
    wire [$clog2(GLOBAL_PHT_SIZE)-1:0] upd_global_pc_idx = branch_pc[$clog2(GLOBAL_PHT_SIZE)+1:2];
    wire [$clog2(CHOOSER_SIZE)-1:0] upd_chooser_idx = branch_pc[$clog2(CHOOSER_SIZE)+1:2];
    wire [$clog2(BTB_ENTRIES)-1:0] upd_btb_idx = branch_pc[$clog2(BTB_ENTRIES)+1:2];
    wire [31:0] upd_btb_tag = branch_pc[31:$clog2(BTB_ENTRIES)+2];
    
    // For update calculations
    wire [$clog2(LOCAL_PHT_SIZE)-1:0] upd_local_pht_idx = local_bht[upd_local_bht_idx];
    wire [GHR_WIDTH-1:0] ghr_shifted = {ghr[GHR_WIDTH-2:0], 1'b0};
    wire [$clog2(GLOBAL_PHT_SIZE)-1:0] upd_global_idx = upd_global_pc_idx ^ 
                                                        ghr_shifted[GHR_WIDTH-1:GHR_WIDTH-$clog2(GLOBAL_PHT_SIZE)];
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset BTB
            for (i = 0; i < BTB_ENTRIES; i = i + 1) begin
                btb_valid[i] <= 1'b0;
                btb_tag[i] <= 32'd0;
                btb_target[i] <= 32'd0;
                btb_is_call[i] <= 1'b0;
                btb_is_ret[i] <= 1'b0;
            end
            
            // Reset Local Predictor
            for (i = 0; i < LOCAL_BHT_SIZE; i = i + 1)
                local_bht[i] <= {$clog2(LOCAL_PHT_SIZE){1'b0}};
            for (i = 0; i < LOCAL_PHT_SIZE; i = i + 1)
                local_pht[i] <= WEAKLY_NOT_TAKEN;
            
            // Reset Global Predictor
            ghr <= {GHR_WIDTH{1'b0}};
            for (i = 0; i < GLOBAL_PHT_SIZE; i = i + 1)
                global_pht[i] <= WEAKLY_NOT_TAKEN;
            
            // Reset Chooser
            for (i = 0; i < CHOOSER_SIZE; i = i + 1)
                chooser[i] <= WEAKLY_LOCAL;
            
            // Reset RAS
            ras_ptr <= {$clog2(RAS_DEPTH){1'b0}};
            for (i = 0; i < RAS_DEPTH; i = i + 1)
                ras_stack[i] <= {ADDR_WIDTH{1'b0}};
                
        end else begin
            // RAS speculative update (for IF stage call detection)
            if (if_is_call && !branch_mispredict) begin
                if (ras_ptr < RAS_DEPTH) begin
                    ras_stack[ras_ptr] <= pc_plus4;
                    ras_ptr <= ras_ptr + 1'b1;
                end
            end else if (if_is_return && !branch_mispredict) begin
                if (ras_ptr > 0) begin
                    ras_ptr <= ras_ptr - 1'b1;
                end
            end
            
            // Branch/commit update
            if (branch_valid) begin
                // Update BTB
                btb_valid[upd_btb_idx] <= 1'b1;
                btb_tag[upd_btb_idx] <= upd_btb_tag;
                btb_target[upd_btb_idx] <= branch_target;
                btb_is_call[upd_btb_idx] <= branch_is_call;
                btb_is_ret[upd_btb_idx] <= branch_is_return;
                
                // Update RAS on confirmed call/return
                if (branch_is_call) begin
                    if (ras_ptr < RAS_DEPTH) begin
                        ras_stack[ras_ptr] <= branch_pc + 32'd4;
                        ras_ptr <= ras_ptr + 1'b1;
                    end
                end else if (branch_is_return) begin
                    if (ras_ptr > 0) begin
                        ras_ptr <= ras_ptr - 1'b1;
                    end
                end
                
                // Update conditional branch predictors
                if (branch_is_cond) begin
                    // Update GHR
                    ghr <= {ghr[GHR_WIDTH-2:0], branch_taken};
                    
                    // Update Local BHT
                    local_bht[upd_local_bht_idx] <= {local_bht[upd_local_bht_idx][$clog2(LOCAL_PHT_SIZE)-2:0], branch_taken};
                    
                    // Update Local PHT
                    if (branch_taken) begin
                        if (local_pht[upd_local_pht_idx] != STRONGLY_TAKEN)
                            local_pht[upd_local_pht_idx] <= local_pht[upd_local_pht_idx] + 1;
                    end else begin
                        if (local_pht[upd_local_pht_idx] != STRONGLY_NOT_TAKEN)
                            local_pht[upd_local_pht_idx] <= local_pht[upd_local_pht_idx] - 1;
                    end
                    
                    // Update Global PHT
                    if (branch_taken) begin
                        if (global_pht[upd_global_idx] != STRONGLY_TAKEN)
                            global_pht[upd_global_idx] <= global_pht[upd_global_idx] + 1;
                    end else begin
                        if (global_pht[upd_global_idx] != STRONGLY_NOT_TAKEN)
                            global_pht[upd_global_idx] <= global_pht[upd_global_idx] - 1;
                    end
                    
                    // Update Chooser (when predictions differ)
                    if (local_pred != global_pred) begin
                        if (global_pred == branch_taken) begin
                            if (chooser[upd_chooser_idx] != STRONGLY_GLOBAL)
                                chooser[upd_chooser_idx] <= chooser[upd_chooser_idx] + 1;
                        end else begin
                            if (chooser[upd_chooser_idx] != STRONGLY_LOCAL)
                                chooser[upd_chooser_idx] <= chooser[upd_chooser_idx] - 1;
                        end
                    end
                end
                
                // Handle misprediction recovery
                if (branch_mispredict) begin
                    // Reset GHR to correct state
                    ghr <= {ghr[GHR_WIDTH-2:0], branch_taken};
                end
            end
        end
    end

endmodule
