//============================================================================
// FENCE.I - Instruction Fence (flush I-cache)
//============================================================================
`include "defines.vh"

module fence_i_handler (
    input  wire        fence_i,

    // I-cache flush control
    output reg         icache_flush,

    // Pipeline flush control
    output reg         pipeline_flush
);

    always @(*) begin
        icache_flush  = fence_i;
        pipeline_flush = fence_i;
    end

endmodule
