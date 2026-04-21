//============================================================================
// WFI - Wait For Interrupt Handler
//============================================================================
`include "defines.vh"

module wfi_handler (
    input  wire        clk,
    input  wire        rst_n,

    // WFI instruction detected
    input  wire        wfi_instr,

    // Interrupt pending signals
    input  wire        mip_msip,
    input  wire        mip_mtip,
    input  wire        mip_meip,
    input  wire        mip_ssip,
    input  wire        mip_stip,
    input  wire        mip_seip,

    // Interrupt enable
    input  wire        mstatus_mie,
    input  wire        mstatus_sie,
    input  wire [31:0] mie,

    // Current privilege
    input  wire [1:0]  priv_mode,

    // Pipeline control
    output reg         wfi_stall,
    output reg         wfi_wakeup
);

    reg wfi_active;

    // Interrupt pending with enable
    wire mip_any = (mip_msip && mie[`MIP_MSIP]) ||
                   (mip_mtip && mie[`MIP_MTIP]) ||
                   (mip_meip && mie[`MIP_MEIP]) ||
                   (mip_ssip && mie[`MIP_SSIP]) ||
                   (mip_stip && mie[`MIP_STIP]) ||
                   (mip_seip && mie[`MIP_SEIP]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wfi_active  <= 1'b0;
            wfi_stall   <= 1'b0;
            wfi_wakeup  <= 1'b0;
        end else begin
            wfi_wakeup <= 1'b0;

            if (wfi_instr && !wfi_active) begin
                wfi_active <= 1'b1;
                wfi_stall  <= 1'b1;
            end

            if (wfi_active) begin
                if (mip_any) begin
                    wfi_active <= 1'b0;
                    wfi_stall  <= 1'b0;
                    wfi_wakeup <= 1'b1;
                end
            end
        end
    end

endmodule
