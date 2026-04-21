//============================================================================
// MRET - Machine Mode Return
//============================================================================
`include "defines.vh"

module mret_handler (
    input  wire        mret_instr,

    // MSTATUS register
    input  wire [31:0] mstatus,

    // MEPC register
    input  wire [31:0] mepc,

    // Outputs
    output wire        mret,
    output wire [31:0] return_pc,
    output wire [1:0]  return_priv
);

    assign mret       = mret_instr;
    assign return_pc  = mepc;
    assign return_priv = mstatus[`MSTATUS_MPP_HI:`MSTATUS_MPP_LO];

endmodule
