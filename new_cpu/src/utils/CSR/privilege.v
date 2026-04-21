//============================================================================
// Privilege Control - RISC-V Privilege Mode Manager
//============================================================================
`include "defines.vh"

module privilege_control (
    input  wire        clk,
    input  wire        rst_n,

    // Current privilege output
    output reg  [1:0]  priv_mode,

    // Trap handling
    input  wire        trap_enter,
    input  wire [1:0]  trap_target_priv,   // Target privilege for trap

    // Trap return
    input  wire        mret,
    input  wire        sret,
    input  wire        uret,

    // MSTATUS MPP/SPP fields (from CSR)
    input  wire [1:0]  mstatus_mpp,
    input  wire        mstatus_spp,

    // Illegal privilege access flag
    output reg         illegal_priv_access
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            priv_mode          <= `PRIV_M;
            illegal_priv_access<= 1'b0;
        end else begin
            illegal_priv_access <= 1'b0;

            if (trap_enter) begin
                priv_mode <= trap_target_priv;
            end else if (mret) begin
                priv_mode <= mstatus_mpp;
            end else if (sret) begin
                if (priv_mode == `PRIV_S)
                    priv_mode <= {1'b0, mstatus_spp};
                else
                    illegal_priv_access <= 1'b1;
            end else if (uret) begin
                if (priv_mode == `PRIV_U)
                    priv_mode <= `PRIV_U;
                else
                    illegal_priv_access <= 1'b1;
            end
        end
    end

endmodule
