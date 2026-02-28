//============================================================================
// D-Cache (Data Cache) - Simplified
// Direct mapped, 1KB, 16B line size, Write-through policy for simplicity
//============================================================================
`include "../defines.vh"
`include "cache_defs.vh"

module dcache (
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU Interface
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    output reg  [31:0] cpu_rdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    output reg         cpu_ready,
    input  wire [3:0]  cpu_wstrb,
    
    // Memory Interface
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    output reg         mem_we,
    output reg         mem_re,
    input  wire        mem_ready
);

    // Cache Structure: 64 sets x 128 bits
    // Address: [31:10] Tag (22 bits), [9:4] Index (6 bits), [3:0] Offset (4 bits)
    
    reg [21:0] tag_array [0:63];
    reg [127:0] data_array [0:63];
    reg valid_array [0:63];
    reg dirty_array [0:63];
    
    // Request info
    reg [21:0] req_tag;
    reg [5:0]  req_index;
    reg [3:0]  req_offset;
    reg [31:0] req_wdata;
    reg [3:0]  req_wstrb;
    reg        req_we;
    
    // State
    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam CHECK = 3'b001;
    localparam MISS = 3'b010;
    localparam REFILL = 3'b011;
    localparam UPDATE = 3'b100;
    
    reg [1:0] refill_cnt;
    reg [127:0] refill_data;
    
    // Hit detection
    wire hit = valid_array[req_index] && (tag_array[req_index] == req_tag);
    wire [127:0] hit_line = data_array[req_index];
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cpu_ready <= 1'b0;
            mem_we <= 1'b0;
            mem_re <= 1'b0;
            refill_cnt <= 2'b00;
            
            for (i = 0; i < 64; i = i + 1) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    cpu_ready <= 1'b0;
                    mem_we <= 1'b0;
                    mem_re <= 1'b0;
                    
                    if (cpu_re || cpu_we) begin
                        req_tag <= cpu_addr[31:10];
                        req_index <= cpu_addr[9:4];
                        req_offset <= cpu_addr[3:0];
                        req_wdata <= cpu_wdata;
                        req_wstrb <= cpu_wstrb;
                        req_we <= cpu_we;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    if (hit) begin
                        // Cache hit
                        if (req_we) begin
                            // Write hit
                            case (req_offset[3:2])
                                2'b00: begin
                                    if (req_wstrb[0]) data_array[req_index][7:0] <= req_wdata[7:0];
                                    if (req_wstrb[1]) data_array[req_index][15:8] <= req_wdata[15:8];
                                    if (req_wstrb[2]) data_array[req_index][23:16] <= req_wdata[23:16];
                                    if (req_wstrb[3]) data_array[req_index][31:24] <= req_wdata[31:24];
                                end
                                2'b01: begin
                                    if (req_wstrb[0]) data_array[req_index][39:32] <= req_wdata[7:0];
                                    if (req_wstrb[1]) data_array[req_index][47:40] <= req_wdata[15:8];
                                    if (req_wstrb[2]) data_array[req_index][55:48] <= req_wdata[23:16];
                                    if (req_wstrb[3]) data_array[req_index][63:56] <= req_wdata[31:24];
                                end
                                2'b10: begin
                                    if (req_wstrb[0]) data_array[req_index][71:64] <= req_wdata[7:0];
                                    if (req_wstrb[1]) data_array[req_index][79:72] <= req_wdata[15:8];
                                    if (req_wstrb[2]) data_array[req_index][87:80] <= req_wdata[23:16];
                                    if (req_wstrb[3]) data_array[req_index][95:88] <= req_wdata[31:24];
                                end
                                2'b11: begin
                                    if (req_wstrb[0]) data_array[req_index][103:96] <= req_wdata[7:0];
                                    if (req_wstrb[1]) data_array[req_index][111:104] <= req_wdata[15:8];
                                    if (req_wstrb[2]) data_array[req_index][119:112] <= req_wdata[23:16];
                                    if (req_wstrb[3]) data_array[req_index][127:120] <= req_wdata[31:24];
                                end
                            endcase
                            dirty_array[req_index] <= 1'b1;
                            cpu_rdata <= req_wdata;
                        end else begin
                            // Read hit
                            case (req_offset[3:2])
                                2'b00: cpu_rdata <= hit_line[31:0];
                                2'b01: cpu_rdata <= hit_line[63:32];
                                2'b10: cpu_rdata <= hit_line[95:64];
                                2'b11: cpu_rdata <= hit_line[127:96];
                            endcase
                        end
                        cpu_ready <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // Cache miss - go to refill
                        state <= MISS;
                        mem_addr <= {req_tag, req_index, 4'b0000};
                        mem_re <= 1'b1;
                        refill_cnt <= 2'b00;
                    end
                end
                
                MISS: begin
                    if (mem_ready) begin
                        case (refill_cnt)
                            2'b00: refill_data[31:0] <= mem_rdata;
                            2'b01: refill_data[63:32] <= mem_rdata;
                            2'b10: refill_data[95:64] <= mem_rdata;
                            2'b11: refill_data[127:96] <= mem_rdata;
                        endcase
                        
                        if (refill_cnt == 2'b11) begin
                            mem_re <= 1'b0;
                            state <= REFILL;
                        end else begin
                            refill_cnt <= refill_cnt + 1;
                            mem_addr <= mem_addr + 4;
                        end
                    end
                end
                
                REFILL: begin
                    // Update cache with new data
                    if (req_we) begin
                        // Merge write data with fetched line
                        case (req_offset[3:2])
                            2'b00: begin
                                if (req_wstrb[0]) refill_data[7:0] <= req_wdata[7:0];
                                if (req_wstrb[1]) refill_data[15:8] <= req_wdata[15:8];
                                if (req_wstrb[2]) refill_data[23:16] <= req_wdata[23:16];
                                if (req_wstrb[3]) refill_data[31:24] <= req_wdata[31:24];
                            end
                            2'b01: begin
                                if (req_wstrb[0]) refill_data[39:32] <= req_wdata[7:0];
                                if (req_wstrb[1]) refill_data[47:40] <= req_wdata[15:8];
                                if (req_wstrb[2]) refill_data[55:48] <= req_wdata[23:16];
                                if (req_wstrb[3]) refill_data[63:56] <= req_wdata[31:24];
                            end
                            2'b10: begin
                                if (req_wstrb[0]) refill_data[71:64] <= req_wdata[7:0];
                                if (req_wstrb[1]) refill_data[79:72] <= req_wdata[15:8];
                                if (req_wstrb[2]) refill_data[87:80] <= req_wdata[23:16];
                                if (req_wstrb[3]) refill_data[95:88] <= req_wdata[31:24];
                            end
                            2'b11: begin
                                if (req_wstrb[0]) refill_data[103:96] <= req_wdata[7:0];
                                if (req_wstrb[1]) refill_data[111:104] <= req_wdata[15:8];
                                if (req_wstrb[2]) refill_data[119:112] <= req_wdata[23:16];
                                if (req_wstrb[3]) refill_data[127:120] <= req_wdata[31:24];
                            end
                        endcase
                    end
                    
                    data_array[req_index] <= refill_data;
                    tag_array[req_index] <= req_tag;
                    valid_array[req_index] <= 1'b1;
                    dirty_array[req_index] <= req_we;
                    
                    // Output
                    case (req_offset[3:2])
                        2'b00: cpu_rdata <= refill_data[31:0];
                        2'b01: cpu_rdata <= refill_data[63:32];
                        2'b10: cpu_rdata <= refill_data[95:64];
                        2'b11: cpu_rdata <= refill_data[127:96];
                    endcase
                    cpu_ready <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
