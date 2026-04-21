//============================================================================
// I-Cache - Instruction Cache (Direct Mapped, placeholder)
//============================================================================
`include "defines.vh"

module icache (
    input  wire        clk,
    input  wire        rst_n,

    // CPU interface
    input  wire [31:0] cpu_addr,
    output reg  [31:0] cpu_rdata,
    input  wire        cpu_re,
    output reg         cpu_ready,

    // Memory interface (to instruction BRAM)
    output reg  [31:0] mem_addr,
    input  wire [31:0] mem_rdata,
    output reg         mem_re,
    input  wire        mem_ready
);

    // Cache parameters
    localparam CACHE_SETS = `ICACHE_SETS;
    localparam LINE_SIZE  = `CACHE_LINE_SIZE;
    localparam TAG_BITS   = 32 - $clog2(CACHE_SETS) - $clog2(LINE_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_SETS);
    localparam OFFSET_BITS= $clog2(LINE_SIZE);

    // Cache line structure
    // valid | tag | data
    reg valid [0:CACHE_SETS-1];
    reg [TAG_BITS-1:0] tag   [0:CACHE_SETS-1];
    reg [31:0]         data  [0:CACHE_SETS-1];

    // Address decomposition
    wire [TAG_BITS-1:0]   addr_tag   = cpu_addr[31:INDEX_BITS+OFFSET_BITS];
    wire [INDEX_BITS-1:0] addr_index = cpu_addr[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];
    wire [OFFSET_BITS-1:0] addr_offset= cpu_addr[OFFSET_BITS-1:0];

    // Cache hit detection
    wire cache_hit;
    assign cache_hit = valid[addr_index] && (tag[addr_index] == addr_tag) && cpu_re;

    integer i;

    // Sequential logic: cache update and CPU interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_rdata  <= 32'd0;
            cpu_ready  <= 1'b0;
            mem_addr   <= 32'd0;
            mem_re     <= 1'b0;
            for (i = 0; i < CACHE_SETS; i = i + 1) begin
                valid[i] <= 1'b0;
            end
        end else begin
            if (cpu_re) begin
                if (cache_hit) begin
                    // Cache hit
                    cpu_rdata <= data[addr_index];
                    cpu_ready <= 1'b1;
                    mem_re    <= 1'b0;
                end else begin
                    // Cache miss: fetch from memory
                    cpu_ready <= 1'b0;
                    if (mem_ready) begin
                        // Memory data ready, update cache
                        data[addr_index]  <= mem_rdata;
                        tag[addr_index]   <= addr_tag;
                        valid[addr_index] <= 1'b1;
                        cpu_rdata         <= mem_rdata;
                        cpu_ready         <= 1'b1;
                        mem_re            <= 1'b0;
                    end else begin
                        // Request memory read
                        mem_addr <= cpu_addr;
                        mem_re   <= 1'b1;
                    end
                end
            end else begin
                cpu_ready <= 1'b0;
                mem_re    <= 1'b0;
            end
        end
    end

endmodule
