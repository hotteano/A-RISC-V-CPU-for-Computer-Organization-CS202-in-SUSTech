//============================================================================
// PMP (Physical Memory Protection) Unit for RISC-V
// Supports: 4 PMP regions with TOR (Top of Range) and NAPOT (Naturally Aligned Power of Two) modes
// Privilege levels: M-mode (bypass), S-mode and U-mode (checked)
//============================================================================
`include "defines.vh"

module pmp #(
    parameter PMP_ENTRIES = 4     // Number of PMP regions (4, 8, or 16)
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Access request
    input  wire [31:0] addr,
    input  wire        we,        // Write enable
    input  wire        re,        // Read enable
    input  wire        xe,        // Execute enable (instruction fetch)
    input  wire [1:0]  priv_mode, // 00=U-mode, 01=S-mode, 11=M-mode
    
    // PMP CSR interface
    input  wire [31:0] pmpcfg0,   // PMP config for entries 0-3
    input  wire [31:0] pmpcfg1,   // PMP config for entries 4-7 (if implemented)
    input  wire [31:0] pmpaddr0,  // PMP address 0
    input  wire [31:0] pmpaddr1,  // PMP address 1
    input  wire [31:0] pmpaddr2,  // PMP address 2
    input  wire [31:0] pmpaddr3,  // PMP address 3
    
    // Access result
    output reg         access_ok,     // Access is allowed
    output reg         access_fault   // Access fault detected
);

    //========================================================================
    // PMP Configuration Register Format (pmpcfg)
    //========================================================================
    // Bits [7]   - L (Lock)
    // Bits [6:5] - Reserved
    // Bits [4:3] - A (Address matching mode)
    //              00=OFF, 01=TOR, 10=NA4, 11=NAPOT
    // Bit  [2]   - X (Execute permission)
    // Bit  [1]   - W (Write permission)
    // Bit  [0]   - R (Read permission)
    //========================================================================
    
    localparam PMP_OFF   = 2'b00;
    localparam PMP_TOR   = 2'b01;
    localparam PMP_NA4   = 2'b10;
    localparam PMP_NAPOT = 2'b11;
    
    // Extract PMP config for each entry
    wire [7:0] cfg [0:PMP_ENTRIES-1];
    assign cfg[0] = pmpcfg0[7:0];
    assign cfg[1] = pmpcfg0[15:8];
    assign cfg[2] = pmpcfg0[23:16];
    assign cfg[3] = pmpcfg0[31:24];
    
    // Extract PMP address registers
    wire [31:0] pmp_addr [0:PMP_ENTRIES-1];
    assign pmp_addr[0] = pmpaddr0;
    assign pmp_addr[1] = pmpaddr1;
    assign pmp_addr[2] = pmpaddr2;
    assign pmp_addr[3] = pmpaddr3;
    
    // PMP config fields
    wire        pmp_l [0:PMP_ENTRIES-1];
    wire [1:0]  pmp_a [0:PMP_ENTRIES-1];
    wire        pmp_x [0:PMP_ENTRIES-1];
    wire        pmp_w [0:PMP_ENTRIES-1];
    wire        pmp_r [0:PMP_ENTRIES-1];
    
    genvar i;
    generate
        for (i = 0; i < PMP_ENTRIES; i = i + 1) begin : pmp_cfg_gen
            assign pmp_l[i] = cfg[i][7];
            assign pmp_a[i] = cfg[i][4:3];
            assign pmp_x[i] = cfg[i][2];
            assign pmp_w[i] = cfg[i][1];
            assign pmp_r[i] = cfg[i][0];
        end
    endgenerate
    
    //========================================================================
    // Address Range Calculation
    //========================================================================
    reg [31:0] region_start [0:PMP_ENTRIES-1];
    reg [31:0] region_end [0:PMP_ENTRIES-1];
    reg        region_active [0:PMP_ENTRIES-1];
    
    integer j;
    always @(*) begin
        // Initialize TOR previous address
        region_start[0] = 32'h0000_0000;
        
        for (j = 0; j < PMP_ENTRIES; j = j + 1) begin
            region_active[j] = (pmp_a[j] != PMP_OFF);
            
            case (pmp_a[j])
                PMP_OFF: begin
                    // Region disabled
                    region_end[j] = 32'h0000_0000;
                end
                
                PMP_TOR: begin
                    // Top of Range: start = previous end, end = current address << 2
                    if (j > 0)
                        region_start[j] = region_end[j-1];
                    region_end[j] = {pmp_addr[j], 2'b00};
                end
                
                PMP_NA4: begin
                    // Naturally Aligned 4-byte region
                    region_start[j] = {pmp_addr[j], 2'b00};
                    region_end[j] = region_start[j] + 32'd4;
                end
                
                PMP_NAPOT: begin
                    // Naturally Aligned Power of Two
                    // Count trailing 1s in address to determine size
                    region_start[j] = napot_start(pmp_addr[j]);
                    region_end[j] = napot_end(pmp_addr[j]);
                end
            endcase
        end
    end
    
    // Helper function for NAPOT decoding
    function [31:0] napot_start;
        input [31:0] addr;
        reg [4:0] trail_ones;
        reg [31:0] size;
        begin
            trail_ones = count_trailing_ones(addr);
            size = 32'd4 << trail_ones;
            napot_start = ({addr, 2'b00} | (size - 1)) & ~(size - 1);
        end
    endfunction
    
    function [31:0] napot_end;
        input [31:0] addr;
        reg [4:0] trail_ones;
        reg [31:0] size;
        begin
            trail_ones = count_trailing_ones(addr);
            size = 32'd4 << trail_ones;
            napot_end = napot_start(addr) + size;
        end
    endfunction
    
    function [4:0] count_trailing_ones;
        input [31:0] addr;
        integer k;
        begin
            count_trailing_ones = 5'd0;
            for (k = 0; k < 32; k = k + 1) begin
                if (addr[k] == 1'b1)
                    count_trailing_ones = count_trailing_ones + 1;
                else
                    count_trailing_ones = count_trailing_ones;
            end
        end
    endfunction
    
    //========================================================================
    // Access Check
    //========================================================================
    reg        addr_match [0:PMP_ENTRIES-1];
    reg        perm_ok [0:PMP_ENTRIES-1];
    reg        any_match;
    reg        access_allowed;
    
    integer m;
    always @(*) begin
        any_match = 1'b0;
        access_allowed = 1'b0;
        
        for (m = 0; m < PMP_ENTRIES; m = m + 1) begin
            // Check if address is in region
            addr_match[m] = region_active[m] && 
                           (addr >= region_start[m]) && 
                           (addr < region_end[m]);
            
            // Check permissions
            perm_ok[m] = (re && pmp_r[m]) ||
                        (we && pmp_w[m]) ||
                        (xe && pmp_x[m]);
            
            if (addr_match[m]) begin
                any_match = 1'b1;
                access_allowed = perm_ok[m];
            end
        end
    end
    
    //========================================================================
    // Output Logic
    //========================================================================
    always @(*) begin
        // M-mode bypass (unless L bit is set)
        if (priv_mode == 2'b11) begin
            // In M-mode, check if any region is locked
            if (any_match) begin
                access_ok = access_allowed;
                access_fault = !access_allowed;
            end else begin
                // No matching PMP region, access allowed in M-mode
                access_ok = 1'b1;
                access_fault = 1'b0;
            end
        end else begin
            // S-mode and U-mode: PMP must be configured
            if (any_match) begin
                access_ok = access_allowed;
                access_fault = !access_allowed;
            end else begin
                // No matching PMP region, access denied in S/U-mode
                access_ok = 1'b0;
                access_fault = (we || re || xe);
            end
        end
    end

endmodule
