//============================================================================
// Interrupt/Exception Delegation - Routes traps to S-mode when delegated
//============================================================================
`include "defines.vh"

module interrupt_delegation (
    input  wire [1:0]  priv_mode,

    // Delegation registers
    input  wire [31:0] medeleg,
    input  wire [31:0] mideleg,

    // Trap cause
    input  wire [31:0] trap_cause,
    input  wire        is_interrupt,

    // Target privilege output
    output reg  [1:0]  target_priv
);

    wire [3:0] cause_idx = trap_cause[3:0];

    always @(*) begin
        if (is_interrupt) begin
            // Check mideleg bit
            if (mideleg[cause_idx] && priv_mode <= `PRIV_S)
                target_priv = `PRIV_S;
            else
                target_priv = `PRIV_M;
        end else begin
            // Check medeleg bit
            if (medeleg[cause_idx] && priv_mode <= `PRIV_S)
                target_priv = `PRIV_S;
            else
                target_priv = `PRIV_M;
        end
    end

endmodule
