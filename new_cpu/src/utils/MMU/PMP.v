//============================================================================
// PMP - Physical Memory Protection Unit (4 regions)
//============================================================================
`include "defines.vh"

module pmp_unit (
    input  wire        clk,
    input  wire        rst_n,

    // Configuration registers
    input  wire [31:0] pmpcfg0,
    input  wire [31:0] pmpaddr0,
    input  wire [31:0] pmpaddr1,
    input  wire [31:0] pmpaddr2,
    input  wire [31:0] pmpaddr3,

    // Address to check
    input  wire [31:0] addr,
    input  wire [1:0]  priv_mode,
    input  wire        is_write,
    input  wire        is_exec,

    // PMP fault output
    output reg         pmp_fault
);

    // Extract 4 PMP region configs from pmpcfg0
    wire [7:0] cfg0 = pmpcfg0[7:0];
    wire [7:0] cfg1 = pmpcfg0[15:8];
    wire [7:0] cfg2 = pmpcfg0[23:16];
    wire [7:0] cfg3 = pmpcfg0[31:24];

    // Region check function
    function automatic check_region;
        input [7:0]  cfg;
        input [31:0] pmp_addr;
        input [31:0] check_addr;
        begin
            if (!cfg[0])  // L bit (lock) - if not locked, ignore in M-mode
                check_region = 1'b1;
            else begin
                // TOR mode (Top of Range)
                check_region = (check_addr < pmp_addr);
            end
        end
    endfunction

    // Permission check
    wire region0_match = check_region(cfg0, pmpaddr0, addr);
    wire region1_match = check_region(cfg1, pmpaddr1, addr);
    wire region2_match = check_region(cfg2, pmpaddr2, addr);
    wire region3_match = check_region(cfg3, pmpaddr3, addr);

    wire [3:0] match_vec = {region3_match, region2_match, region1_match, region0_match};

    // Find highest priority match
    reg [7:0] matched_cfg;
    always @(*) begin
        if (match_vec[0])      matched_cfg = cfg0;
        else if (match_vec[1]) matched_cfg = cfg1;
        else if (match_vec[2]) matched_cfg = cfg2;
        else if (match_vec[3]) matched_cfg = cfg3;
        else                   matched_cfg = 8'h0;
    end

    // Permission bits: [1]=W, [2]=R, [3]=X
    always @(*) begin
        // M-mode bypasses PMP if no region matches or region not locked
        if (priv_mode == `PRIV_M && !matched_cfg[7]) begin
            pmp_fault = 1'b0;
        end else if (match_vec == 4'b0000) begin
            // No match: fault for S/U mode
            pmp_fault = (priv_mode != `PRIV_M);
        end else begin
            // Check permission
            if (is_exec)
                pmp_fault = !matched_cfg[3];  // X bit
            else if (is_write)
                pmp_fault = !matched_cfg[2];  // W bit
            else
                pmp_fault = !matched_cfg[1];  // R bit
        end
    end

endmodule
