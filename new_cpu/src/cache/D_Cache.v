//============================================================================
// D-Cache - Data Cache (Direct Mapped, Write-Through, placeholder)
//============================================================================
`include "defines.vh"

module dcache (
    input  wire        clk,
    input  wire        rst_n,

    // CPU interface
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    output reg  [31:0] cpu_rdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    output reg         cpu_ready,
    input  wire [3:0]  cpu_wstrb,     // Write byte enable

    // Memory interface (to data BRAM)
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    output reg         mem_we,
    output reg         mem_re,
    input  wire        mem_ready
);

    // Cache parameters
    localparam CACHE_SETS = `DCACHE_SETS;
    localparam LINE_SIZE  = `CACHE_LINE_SIZE;
    localparam TAG_BITS   = 32 - $clog2(CACHE_SETS) - $clog2(LINE_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_SETS);
    localparam OFFSET_BITS= $clog2(LINE_SIZE);

    // Cache line structure
    reg valid [0:CACHE_SETS-1];
    reg [TAG_BITS-1:0] tag   [0:CACHE_SETS-1];
    reg [31:0]         data  [0:CACHE_SETS-1];

    // Address decomposition
    wire [TAG_BITS-1:0]   addr_tag    = cpu_addr[31:INDEX_BITS+OFFSET_BITS];
    wire [INDEX_BITS-1:0] addr_index  = cpu_addr[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];

    // Cache hit detection
    wire cache_hit;
    assign cache_hit = valid[addr_index] && (tag[addr_index] == addr_tag) && (cpu_re || cpu_we);

    integer i;

    // Write data with byte enable
    wire [31:0] write_data;
    assign write_data = {
        cpu_wstrb[3] ? cpu_wdata[31:24] : data[addr_index][31:24],
        cpu_wstrb[2] ? cpu_wdata[23:16] : data[addr_index][23:16],
        cpu_wstrb[1] ? cpu_wdata[15:8]  : data[addr_index][15:8],
        cpu_wstrb[0] ? cpu_wdata[7:0]   : data[addr_index][7:0]
    };

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_rdata  <= 32'd0;
            cpu_ready  <= 1'b0;
            mem_addr   <= 32'd0;
            mem_wdata  <= 32'd0;
            mem_we     <= 1'b0;
            mem_re     <= 1'b0;
            for (i = 0; i < CACHE_SETS; i = i + 1) begin
                valid[i] <= 1'b0;
            end
        end else begin
            if (cpu_we) begin
                // Write operation (write-through)
                if (cache_hit) begin
                    data[addr_index] <= write_data;
                end
                // Always write to memory
                mem_addr  <= cpu_addr;
                mem_wdata <= cpu_wdata;
                mem_we    <= 1'b1;
                cpu_ready <= mem_ready;
            end else if (cpu_re) begin
                // Read operation
                if (cache_hit) begin
                    cpu_rdata <= data[addr_index];
                    cpu_ready <= 1'b1;
                    mem_re    <= 1'b0;
                end else begin
                    // Cache miss
                    cpu_ready <= 1'b0;
                    if (mem_ready) begin
                        data[addr_index]  <= mem_rdata;
                        tag[addr_index]   <= addr_tag;
                        valid[addr_index] <= 1'b1;
                        cpu_rdata         <= mem_rdata;
                        cpu_ready         <= 1'b1;
                        mem_re            <= 1'b0;
                    end else begin
                        mem_addr <= cpu_addr;
                        mem_re   <= 1'b1;
                    end
                end
            end else begin
                cpu_ready <= 1'b0;
                mem_we    <= 1'b0;
                mem_re    <= 1'b0;
            end
        end
    end

endmodule
