//============================================================================
// Return Address Stack (RAS)
// Used for predicting return addresses of function calls
// Supports: CALL/JAL (push), RET/JALR to ra (pop)
//============================================================================
`include "defines.vh"

module return_address_stack #(
    parameter STACK_DEPTH = 16,         // Number of entries in RAS
    parameter ADDR_WIDTH  = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Prediction request (from IF stage)
    input  wire [ADDR_WIDTH-1:0] pc,            // Current PC
    input  wire                  is_call,       // Is this a function call? (JAL/JALR with rd=ra/x1)
    input  wire                  is_return,     // Is this a function return? (JALR with rs1=ra/x1, rd=x0)
    output wire [ADDR_WIDTH-1:0] ras_predict,   // Predicted return address
    output wire                  ras_valid,     // RAS prediction is valid
    
    // Update from EX/MEM stage (actual resolution)
    input  wire                  ex_is_call,        // Confirmed call instruction
    input  wire                  ex_is_return,      // Confirmed return instruction
    input  wire [ADDR_WIDTH-1:0] ex_return_addr,    // Actual return address to push
    input  wire                  ex_mispredict,     // Misprediction signal (for recovery)
    input  wire [$clog2(STACK_DEPTH)-1:0] ex_ras_ptr // RAS pointer from EX stage (for recovery)
);

    // Stack entries
    reg [ADDR_WIDTH-1:0] ras_stack [0:STACK_DEPTH-1];
    
    // Stack pointer (points to top of stack)
    reg [$clog2(STACK_DEPTH)-1:0] ras_ptr;
    
    // Stack for speculative RAS pointers (for misprediction recovery)
    reg [$clog2(STACK_DEPTH)-1:0] spec_ptr_stack [0:STACK_DEPTH-1];
    
    // Output assignment
    assign ras_predict = ras_stack[ras_ptr - 1'b1];  // Top of stack
    assign ras_valid = (ras_ptr != {$clog2(STACK_DEPTH){1'b0}});
    
    // Operation detection
    wire do_push = ex_is_call;
    wire do_pop = ex_is_return;
    
    integer i;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset stack pointer
            ras_ptr <= {$clog2(STACK_DEPTH){1'b0}};
            
            // Clear stack
            for (i = 0; i < STACK_DEPTH; i = i + 1) begin
                ras_stack[i] <= {ADDR_WIDTH{1'b0}};
                spec_ptr_stack[i] <= {$clog2(STACK_DEPTH){1'b0}};
            end
        end else if (ex_mispredict) begin
            // Recovery: restore RAS pointer from EX stage
            ras_ptr <= ex_ras_ptr;
        end else begin
            // Speculative update for IF stage
            if (is_call && !is_return) begin
                // Push return address (PC + 4)
                if (ras_ptr < STACK_DEPTH) begin
                    ras_stack[ras_ptr] <= pc + 32'd4;
                    spec_ptr_stack[ras_ptr] <= ras_ptr + 1'b1;
                    ras_ptr <= ras_ptr + 1'b1;
                end else begin
                    // Stack full, wrap around (or could stall)
                    ras_stack[0] <= pc + 32'd4;
                    ras_ptr <= 1'b1;
                end
            end else if (is_return && !is_call) begin
                // Pop from stack
                if (ras_ptr > {$clog2(STACK_DEPTH){1'b0}}) begin
                    ras_ptr <= ras_ptr - 1'b1;
                end
                // If empty, keep at 0 (invalid prediction)
            end
            // If both call and return (unlikely), do nothing
            
            // Actual update from EX stage (commit)
            if (ex_is_call && !is_call) begin  // Only if not already done speculatively
                if (ras_ptr < STACK_DEPTH) begin
                    ras_stack[ras_ptr] <= ex_return_addr;
                    ras_ptr <= ras_ptr + 1'b1;
                end
            end
            // Actual pops are handled by speculative updates
        end
    end

endmodule
