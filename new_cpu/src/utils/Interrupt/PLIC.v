//============================================================================
// PLIC - Platform Level Interrupt Controller (simplified)
//============================================================================
`include "defines.vh"

module plic (
    input  wire        clk,
    input  wire        rst_n,

    // Bus interface
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        we,
    input  wire        re,
    output wire        ready,

    // External interrupt sources (up to 32)
    input  wire [31:0] irq_src,

    // Interrupt outputs to hart
    output reg         meip,    // Machine external interrupt pending
    output reg         seip     // Supervisor external interrupt pending
);

    // PLIC registers
    reg [31:0] priority    [0:31];    // Interrupt priority
    reg [31:0] pending;                // Interrupt pending
    reg [31:0] enable_m;               // Enable for M-mode
    reg [31:0] enable_s;               // Enable for S-mode
    reg [31:0] threshold_m;            // Priority threshold M-mode
    reg [31:0] threshold_s;            // Priority threshold S-mode
    reg [4:0]  claim_m;                // Claim/complete M-mode
    reg [4:0]  claim_s;                // Claim/complete S-mode

    integer i;
    assign ready = 1'b1;

    // Pending detection
    always @(*) begin
        pending = irq_src;
    end

    // Claim logic: find highest priority pending interrupt
    function automatic [4:0] find_highest;
        input [31:0] enabled;
        input [31:0] thresh;
        reg [4:0]  best_id;
        reg [31:0] best_pri;
        integer j;
        begin
            best_id  = 5'd0;
            best_pri = 32'd0;
            for (j = 1; j < 32; j = j + 1) begin
                if (enabled[j] && pending[j] && priority[j] > best_pri && priority[j] > thresh) begin
                    best_pri = priority[j];
                    best_id  = j[4:0];
                end
            end
            find_highest = best_id;
        end
    endfunction

    wire [4:0] best_m = find_highest(enable_m, threshold_m);
    wire [4:0] best_s = find_highest(enable_s, threshold_s);

    always @(*) begin
        meip = (best_m != 5'd0);
        seip = (best_s != 5'd0);
    end

    // Register access
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending     <= 32'd0;
            enable_m    <= 32'd0;
            enable_s    <= 32'd0;
            threshold_m <= 32'd0;
            threshold_s <= 32'd0;
            claim_m     <= 5'd0;
            claim_s     <= 5'd0;
            for (i = 0; i < 32; i = i + 1)
                priority[i] <= 32'd0;
        end else begin
            if (we) begin
                case (addr[23:0])
                    // Priority registers (0x000000 - 0x00007C)
                    24'h0000: priority[0]  <= wdata;
                    24'h0004: priority[1]  <= wdata;
                    // ... (expand as needed)

                    // Pending bits (read-only in real HW)
                    24'h001000: ; // pending[31:0] - read only

                    // Enable registers
                    24'h002000: enable_m <= wdata;
                    24'h002080: enable_s <= wdata;

                    // Threshold
                    24'h200000: threshold_m <= wdata;
                    24'h201000: threshold_s <= wdata;

                    // Claim/complete
                    24'h200004: claim_m <= wdata[4:0];
                    24'h201004: claim_s <= wdata[4:0];
                endcase
            end

            if (re) begin
                case (addr[23:0])
                    24'h0000: rdata <= priority[0];
                    24'h001000: rdata <= pending;
                    24'h002000: rdata <= enable_m;
                    24'h002080: rdata <= enable_s;
                    24'h200000: rdata <= threshold_m;
                    24'h201000: rdata <= threshold_s;
                    24'h200004: rdata <= {27'd0, best_m};
                    24'h201004: rdata <= {27'd0, best_s};
                    default:    rdata <= 32'd0;
                endcase
            end
        end
    end

endmodule
