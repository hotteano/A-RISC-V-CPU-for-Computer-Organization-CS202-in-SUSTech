//============================================================================
// DTB - Device Tree Blob (ROM)
// Contains platform description for Linux boot
//============================================================================
`include "defines.vh"

module dtb_rom #(
    parameter DTB_DEPTH = 512,
    parameter INIT_FILE = "dtb.bin"
)(
    input  wire        clk,

    // Read interface
    input  wire [31:0] addr,
    output reg  [7:0]  data
);

    localparam AW = $clog2(DTB_DEPTH);

    reg [7:0] dtb [0:DTB_DEPTH-1];
    wire [AW-1:0] byte_addr = addr[AW-1:0];

    always @(posedge clk) begin
        data <= dtb[byte_addr];
    end

endmodule
