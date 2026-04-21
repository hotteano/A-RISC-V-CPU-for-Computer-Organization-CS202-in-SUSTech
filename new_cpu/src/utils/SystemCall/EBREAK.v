//============================================================================
// EBREAK - Breakpoint Handler
//============================================================================
`include "defines.vh"

module ebreak_handler (
    input  wire        ebreak,
    input  wire [31:0] pc,

    // Exception output
    output reg         trap,
    output reg  [31:0] trap_cause,
    output reg  [31:0] trap_pc
);

    always @(*) begin
        trap      = ebreak;
        trap_cause = ebreak ? `CAUSE_BREAKPOINT : 32'd0;
        trap_pc   = ebreak ? pc : 32'd0;
    end

endmodule
