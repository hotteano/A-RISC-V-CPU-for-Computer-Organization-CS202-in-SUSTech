//============================================================================
// ECALL - Environment Call Handler
//============================================================================
`include "defines.vh"

module ecall_handler (
    input  wire        ecall,
    input  wire [1:0]  priv_mode,

    // Exception output
    output reg         trap,
    output reg  [31:0] trap_cause,
    output reg  [31:0] trap_pc
);

    always @(*) begin
        trap = ecall;
        if (ecall) begin
            case (priv_mode)
                `PRIV_U: trap_cause = `CAUSE_ECALL_U;
                `PRIV_S: trap_cause = `CAUSE_ECALL_S;
                `PRIV_M: trap_cause = `CAUSE_ECALL_M;
                default: trap_cause = `CAUSE_ECALL_M;
            endcase
        end else begin
            trap_cause = 32'd0;
        end
    end

endmodule
