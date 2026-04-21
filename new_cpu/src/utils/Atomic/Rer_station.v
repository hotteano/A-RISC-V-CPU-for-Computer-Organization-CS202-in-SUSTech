//============================================================================
// Reservation Station - for LR/SC atomic operations
//============================================================================
`include "defines.vh"

module reservation_station (
    input  wire        clk,
    input  wire        rst_n,

    // Set reservation (on LR)
    input  wire        set,
    input  wire [31:0] set_addr,

    // Clear reservation (on SC success, or external store to same line)
    input  wire        clear,
    input  wire        ext_clear,
    input  wire [31:0] ext_addr,

    // Status output
    output reg         valid,
    output reg  [31:0] addr
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
            addr  <= 32'd0;
        end else begin
            if (clear) begin
                valid <= 1'b0;
            end else if (ext_clear) begin
                // Clear if any store to same cache line
                if (addr[31:4] == ext_addr[31:4])
                    valid <= 1'b0;
            end else if (set) begin
                valid <= 1'b1;
                addr  <= set_addr;
            end
        end
    end

endmodule
