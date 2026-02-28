//============================================================================
// I-Cache (Instruction Cache) - Simplified
// Direct mapped, 1KB, 16B line size
//============================================================================
`include "../defines.vh"
`include "cache_defs.vh"

module icache (
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU Interface
    input  wire [31:0] cpu_addr,
    output reg  [31:0] cpu_rdata,
    input  wire        cpu_re,
    output reg         cpu_ready,
    
    // Memory Interface
    output reg  [31:0] mem_addr,
    input  wire [31:0] mem_rdata,
    output reg         mem_re,
    input  wire        mem_ready
);

    // Cache Structure: 64 sets x 128 bits (16 bytes per line)
    // Address: [31:10] Tag (22 bits), [9:4] Index (6 bits), [3:0] Offset (4 bits)
    
    reg [21:0] tag_array [0:63];
    reg [127:0] data_array [0:63];
    reg valid_array [0:63];
    
    // Current request info
    reg [21:0] req_tag;
    reg [5:0]  req_index;
    reg [3:0]  req_offset;
    
    // Hit detection (combinational)
    wire hit = valid_array[req_index] && (tag_array[req_index] == req_tag);
    wire [127:0] hit_line = data_array[req_index];
    
    // State
    reg [1:0] state;
    localparam IDLE = 2'b00;
    localparam CHECK = 2'b01;
    localparam MISS = 2'b10;
    localparam REFILL = 2'b11;
    
    reg [1:0] refill_cnt;
    reg [127:0] refill_data;
    
    integer i;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cpu_ready <= 1'b0;
            mem_re <= 1'b0;
            refill_cnt <= 2'b00;
            
            for (i = 0; i < 64; i = i + 1) begin
                valid_array[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    cpu_ready <= 1'b0;
                    if (cpu_re) begin
                        req_tag <= cpu_addr[31:10];
                        req_index <= cpu_addr[9:4];
                        req_offset <= cpu_addr[3:0];
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    if (hit) begin
                        // Cache hit
                        case (req_offset[3:2])
                            2'b00: cpu_rdata <= hit_line[31:0];
                            2'b01: cpu_rdata <= hit_line[63:32];
                            2'b10: cpu_rdata <= hit_line[95:64];
                            2'b11: cpu_rdata <= hit_line[127:96];
                        endcase
                        cpu_ready <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // Cache miss
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
                    // Update cache
                    data_array[req_index] <= refill_data;
                    tag_array[req_index] <= req_tag;
                    valid_array[req_index] <= 1'b1;
                    
                    // Output data
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
