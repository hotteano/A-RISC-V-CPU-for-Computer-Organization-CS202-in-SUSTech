//============================================================================
// Bootloader - Simple ROM bootloader
//============================================================================
`include "defines.vh"

module bootloader #(
    parameter ROM_DEPTH = 256,
    parameter INIT_FILE = ""
)(
    input  wire        clk,
    input  wire        rst_n,

    // CPU fetch interface
    input  wire [31:0] addr,
    output wire [31:0] data,

    // Boot control
    output wire        boot_done,
    input  wire        cpu_ready
);

    localparam AW = $clog2(ROM_DEPTH);

    reg [31:0] rom [0:ROM_DEPTH-1];
    wire [AW-1:0] word_addr = addr[AW+1:2];

    // Bootloader active during first cycles or until CPU takes over
    reg [7:0] boot_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            boot_cnt <= 8'd0;
        end else if (!boot_done) begin
            boot_cnt <= boot_cnt + 1;
        end
    end

    assign boot_done = (boot_cnt >= 8'd10);  // Short boot phase
    assign data = rom[word_addr];

endmodule
