//============================================================================
// SFENCE.VMA - VM Address Translation Fence
//============================================================================
`include "defines.vh"

module sfence_vma_handler (
    input  wire        sfence_vma,
    input  wire [1:0]  priv_mode,

    // Illegal instruction if not in S/M mode
    output reg         illegal_instr,

    // TLB/cache flush control
    output reg         tlb_flush,
    output reg         dcache_flush
);

    always @(*) begin
        illegal_instr = sfence_vma && (priv_mode == `PRIV_U);
        tlb_flush     = sfence_vma && !illegal_instr;
        dcache_flush  = sfence_vma && !illegal_instr;
    end

endmodule
