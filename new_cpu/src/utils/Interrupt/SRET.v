//============================================================================
// SRET - Supervisor Mode Return
//============================================================================
`include "defines.vh"

module sret_handler (
    input  wire        sret_instr,
    input  wire [1:0]  priv_mode,

    // SSTATUS register
    input  wire [31:0] sstatus,

    // SEPC register
    input  wire [31:0] sepc,

    // Outputs
    output wire        sret,
    output wire [31:0] return_pc,
    output wire        illegal_instr
);

    // SRET is illegal in U-mode
    assign sret        = sret_instr && (priv_mode != `PRIV_U);
    assign return_pc   = sepc;
    assign illegal_instr = sret_instr && (priv_mode == `PRIV_U);

endmodule
