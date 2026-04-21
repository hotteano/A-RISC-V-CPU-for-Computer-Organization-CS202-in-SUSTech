//============================================================================
// D_BRam - Data BRAM for RISC-V CPU
// 16KB dual-port Block RAM (port A: CPU read/write, port B: DMA/program)
//============================================================================
`include "defines.vh"

module D_BRam #(
    parameter ADDR_WIDTH = 14,          // 14 = 16KB
    parameter DATA_WIDTH = 32,
    parameter INIT_FILE  = ""
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Port A: CPU interface
    input  wire [`DATA_ADDR_BUS] addr_a,
    output wire [`DATA_DATA_BUS] dout_a,
    input  wire [`DATA_DATA_BUS] din_a,
    input  wire                  we_a,
    input  wire [3:0]            be_a,      // Byte enable
    input  wire                  re_a,

    // Port B: DMA / programming interface
    input  wire [`DATA_ADDR_BUS] addr_b,
    output wire [`DATA_DATA_BUS] dout_b,
    input  wire [`DATA_DATA_BUS] din_b,
    input  wire                  we_b,
    input  wire [3:0]            be_b
);

    localparam MEM_SIZE  = 1 << ADDR_WIDTH;     // Total bytes
    localparam MEM_DEPTH = 1 << (ADDR_WIDTH - 2); // Word depth
    localparam AW        = ADDR_WIDTH - 2;

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    wire [AW-1:0] word_addr_a = addr_a[ADDR_WIDTH-1:2];
    wire [AW-1:0] word_addr_b = addr_b[ADDR_WIDTH-1:2];

    // Byte-wise write for Port A
    always @(posedge clk) begin
        if (we_a) begin
            if (be_a[0]) mem[word_addr_a][7:0]   <= din_a[7:0];
            if (be_a[1]) mem[word_addr_a][15:8]  <= din_a[15:8];
            if (be_a[2]) mem[word_addr_a][23:16] <= din_a[23:16];
            if (be_a[3]) mem[word_addr_a][31:24] <= din_a[31:24];
        end
    end

    // Byte-wise write for Port B
    always @(posedge clk) begin
        if (we_b) begin
            if (be_b[0]) mem[word_addr_b][7:0]   <= din_b[7:0];
            if (be_b[1]) mem[word_addr_b][15:8]  <= din_b[15:8];
            if (be_b[2]) mem[word_addr_b][23:16] <= din_b[23:16];
            if (be_b[3]) mem[word_addr_b][31:24] <= din_b[31:24];
        end
    end

    assign dout_a = mem[word_addr_a];
    assign dout_b = mem[word_addr_b];

endmodule
