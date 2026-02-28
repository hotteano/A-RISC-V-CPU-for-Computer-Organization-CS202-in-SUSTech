//============================================================================
// DMA Controller - Direct Memory Access
// Features: Memory-to-memory, memory-to-peripheral, peripheral-to-memory
//           Circular buffer mode, chaining support
//============================================================================
`include "defines.vh"

module dma_controller #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter CHANNELS    = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // CPU Configuration Interface
    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    output reg  [DATA_WIDTH-1:0] cpu_rdata,
    input  wire [DATA_WIDTH-1:0] cpu_wdata,
    input  wire                  cpu_we,
    input  wire                  cpu_re,
    output wire                  irq,           // DMA completion interrupt
    
    // Bus Master Interface (for DMA transfers)
    output reg                   dma_req,
    output reg                   dma_we,
    output reg  [ADDR_WIDTH-1:0] dma_addr,
    output reg  [DATA_WIDTH-1:0] dma_wdata,
    output reg  [3:0]            dma_be,
    input  wire [DATA_WIDTH-1:0] dma_rdata,
    input  wire                  dma_ack,
    input  wire                  dma_err,
    
    // Peripheral request signals (for peripheral DMA)
    input  wire [CHANNELS-1:0]   periph_req,
    output wire [CHANNELS-1:0]   periph_ack
);

    //========================================================================
    // Register Map
    //========================================================================
    // Channel 0: 0x00 - 0x1F
    // Channel 1: 0x20 - 0x3F
    // Channel 2: 0x40 - 0x5F
    // Channel 3: 0x60 - 0x7F
    // Global: 0x80 - 0xFF
    
    localparam REG_SRC_ADDR  = 8'h00;  // Source address
    localparam REG_DST_ADDR  = 8'h04;  // Destination address
    localparam REG_SIZE      = 8'h08;  // Transfer size (bytes)
    localparam REG_CTRL      = 8'h0C;  // Control register
    localparam REG_STATUS    = 8'h10;  // Status register
    
    localparam REG_GLOBAL_STATUS = 8'h80;  // Global status
    localparam REG_GLOBAL_IE     = 8'h84;  // Global interrupt enable
    
    //========================================================================
    // DMA Channel Registers
    //========================================================================
    reg [ADDR_WIDTH-1:0] ch_src_addr [0:CHANNELS-1];
    reg [ADDR_WIDTH-1:0] ch_dst_addr [0:CHANNELS-1];
    reg [ADDR_WIDTH-1:0] ch_size [0:CHANNELS-1];
    reg [31:0]           ch_ctrl [0:CHANNELS-1];
    reg [31:0]           ch_status [0:CHANNELS-1];
    
    // Control bits
    wire [CHANNELS-1:0] ch_enable;
    wire [CHANNELS-1:0] ch_dir;         // 0=mem-to-mem, 1=periph-to-mem or mem-to-periph
    wire [CHANNELS-1:0] ch_mode;        // 0=normal, 1=circular
    wire [CHANNELS-1:0] ch_size_byte;   // 0=word, 1=byte
    wire [CHANNELS-1:0] ch_inc_src;     // Increment source address
    wire [CHANNELS-1:0] ch_inc_dst;     // Increment destination address
    wire [CHANNELS-1:0] ch_tc_ie;       // Transfer complete interrupt enable
    
    genvar g;
    generate
        for (g = 0; g < CHANNELS; g = g + 1) begin : ch_ctrl_extract
            assign ch_enable[g]    = ch_ctrl[g][0];
            assign ch_dir[g]       = ch_ctrl[g][1];
            assign ch_mode[g]      = ch_ctrl[g][2];
            assign ch_size_byte[g] = ch_ctrl[g][3];
            assign ch_inc_src[g]   = ch_ctrl[g][4];
            assign ch_inc_dst[g]   = ch_ctrl[g][5];
            assign ch_tc_ie[g]     = ch_ctrl[g][6];
        end
    endgenerate
    
    //========================================================================
    // DMA State Machine
    //========================================================================
    localparam IDLE     = 3'd0;
    localparam ARB      = 3'd1;  // Arbitration
    localparam READ     = 3'd2;  // Read from source
    localparam WRITE    = 3'd3;  // Write to destination
    localparam UPDATE   = 3'd4;  // Update addresses
    localparam DONE     = 3'd5;  // Transfer complete
    
    reg [2:0] state;
    reg [$clog2(CHANNELS)-1:0] active_ch;
    reg [ADDR_WIDTH-1:0] current_src;
    reg [ADDR_WIDTH-1:0] current_dst;
    reg [ADDR_WIDTH-1:0] remaining;
    reg [DATA_WIDTH-1:0] read_buffer;
    
    wire [CHANNELS-1:0] ch_active = ch_enable & (ch_size > 0);
    wire any_channel_active = |ch_active;
    
    // Round-robin arbiter for channels
    reg [$clog2(CHANNELS)-1:0] last_ch;
    wire [$clog2(CHANNELS)-1:0] next_ch;
    
    assign next_ch = (last_ch + 1'b1) % CHANNELS;
    
    // Channel selection
    reg [$clog2(CHANNELS)-1:0] selected_ch;
    reg found_active;
    
    integer idx;
    always @(*) begin
        selected_ch = last_ch;
        found_active = 1'b0;
        
        for (idx = 0; idx < CHANNELS; idx = idx + 1) begin
            if (!found_active && ch_active[(next_ch + idx) % CHANNELS]) begin
                selected_ch = (next_ch + idx) % CHANNELS;
                found_active = 1'b1;
            end
        end
    end
    
    // Peripheral ack
    assign periph_ack = (state == WRITE && ch_dir[active_ch]) ? (1'b1 << active_ch) : {CHANNELS{1'b0}};
    
    // DMA State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            active_ch <= {$clog2(CHANNELS){1'b0}};
            last_ch <= {$clog2(CHANNELS){1'b0}};
            current_src <= {ADDR_WIDTH{1'b0}};
            current_dst <= {ADDR_WIDTH{1'b0}};
            remaining <= {ADDR_WIDTH{1'b0}};
            read_buffer <= {DATA_WIDTH{1'b0}};
            dma_req <= 1'b0;
            dma_we <= 1'b0;
            dma_addr <= {ADDR_WIDTH{1'b0}};
            dma_wdata <= {DATA_WIDTH{1'b0}};
            dma_be <= 4'b0000;
        end else begin
            case (state)
                IDLE: begin
                    dma_req <= 1'b0;
                    if (any_channel_active) begin
                        state <= ARB;
                    end
                end
                
                ARB: begin
                    if (found_active) begin
                        active_ch <= selected_ch;
                        last_ch <= selected_ch;
                        current_src <= ch_src_addr[selected_ch];
                        current_dst <= ch_dst_addr[selected_ch];
                        remaining <= ch_size[selected_ch];
                        state <= READ;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                READ: begin
                    dma_req <= 1'b1;
                    dma_we <= 1'b0;
                    dma_addr <= current_src;
                    dma_be <= 4'b1111;
                    
                    if (dma_ack) begin
                        read_buffer <= dma_rdata;
                        dma_req <= 1'b0;
                        state <= WRITE;
                    end else if (dma_err) begin
                        // Error handling
                        ch_status[active_ch][1] <= 1'b1;  // Error flag
                        state <= DONE;
                    end
                end
                
                WRITE: begin
                    dma_req <= 1'b1;
                    dma_we <= 1'b1;
                    dma_addr <= current_dst;
                    dma_wdata <= read_buffer;
                    dma_be <= 4'b1111;
                    
                    if (dma_ack) begin
                        dma_req <= 1'b0;
                        state <= UPDATE;
                    end else if (dma_err) begin
                        ch_status[active_ch][1] <= 1'b1;
                        state <= DONE;
                    end
                end
                
                UPDATE: begin
                    // Update addresses
                    if (ch_inc_src[active_ch])
                        ch_src_addr[active_ch] <= current_src + (ch_size_byte[active_ch] ? 32'd1 : 32'd4);
                    if (ch_inc_dst[active_ch])
                        ch_dst_addr[active_ch] <= current_dst + (ch_size_byte[active_ch] ? 32'd1 : 32'd4);
                    
                    // Update remaining size
                    if (remaining <= (ch_size_byte[active_ch] ? 32'd1 : 32'd4)) begin
                        ch_size[active_ch] <= 32'd0;
                        state <= DONE;
                    end else begin
                        ch_size[active_ch] <= remaining - (ch_size_byte[active_ch] ? 32'd1 : 32'd4);
                        
                        // Continue or re-arbitrate
                        if (any_channel_active && selected_ch != active_ch) begin
                            state <= ARB;  // Let other channels have a turn
                        end else begin
                            // Continue with same channel
                            current_src <= current_src + (ch_size_byte[active_ch] ? 32'd1 : 32'd4);
                            current_dst <= current_dst + (ch_size_byte[active_ch] ? 32'd1 : 32'd4);
                            remaining <= remaining - (ch_size_byte[active_ch] ? 32'd1 : 32'd4);
                            state <= READ;
                        end
                    end
                end
                
                DONE: begin
                    ch_status[active_ch][0] <= 1'b1;  // Transfer complete flag
                    ch_ctrl[active_ch][0] <= 1'b0;    // Disable channel
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    //========================================================================
    // CPU Interface
    //========================================================================
    reg [31:0] global_ie;
    wire [CHANNELS-1:0] tc_flags;
    
    generate
        for (g = 0; g < CHANNELS; g = g + 1) begin : tc_flag_gen
            assign tc_flags[g] = ch_status[g][0];
        end
    endgenerate
    
    assign irq = |(tc_flags & global_ie[CHANNELS-1:0]);
    
    wire [7:0] reg_addr = cpu_addr[7:0];
    wire [$clog2(CHANNELS)-1:0] ch_sel = reg_addr[6:5];  // Channel select from address
    
    integer ch_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (ch_idx = 0; ch_idx < CHANNELS; ch_idx = ch_idx + 1) begin
                ch_src_addr[ch_idx] <= {ADDR_WIDTH{1'b0}};
                ch_dst_addr[ch_idx] <= {ADDR_WIDTH{1'b0}};
                ch_size[ch_idx] <= {ADDR_WIDTH{1'b0}};
                ch_ctrl[ch_idx] <= 32'd0;
                ch_status[ch_idx] <= 32'd0;
            end
            global_ie <= 32'd0;
        end else begin
            if (cpu_we) begin
                case (reg_addr)
                    // Channel 0-3 registers
                    8'h00, 8'h20, 8'h40, 8'h60: begin
                        ch_src_addr[ch_sel] <= cpu_wdata;
                    end
                    8'h04, 8'h24, 8'h44, 8'h64: begin
                        ch_dst_addr[ch_sel] <= cpu_wdata;
                    end
                    8'h08, 8'h28, 8'h48, 8'h68: begin
                        ch_size[ch_sel] <= cpu_wdata;
                    end
                    8'h0C, 8'h2C, 8'h4C, 8'h6C: begin
                        ch_ctrl[ch_sel] <= cpu_wdata;
                        if (cpu_wdata[0])  // Clear status on enable
                            ch_status[ch_sel] <= 32'd0;
                    end
                    8'h10, 8'h30, 8'h50, 8'h70: begin
                        // Status is read-only, but write clears flags
                        ch_status[ch_sel] <= ch_status[ch_sel] & ~cpu_wdata;
                    end
                    
                    // Global registers
                    8'h84: global_ie <= cpu_wdata;
                endcase
            end
        end
    end
    
    // Read mux
    always @(*) begin
        case (reg_addr)
            8'h00, 8'h20, 8'h40, 8'h60: cpu_rdata = ch_src_addr[ch_sel];
            8'h04, 8'h24, 8'h44, 8'h64: cpu_rdata = ch_dst_addr[ch_sel];
            8'h08, 8'h28, 8'h48, 8'h68: cpu_rdata = ch_size[ch_sel];
            8'h0C, 8'h2C, 8'h4C, 8'h6C: cpu_rdata = ch_ctrl[ch_sel];
            8'h10, 8'h30, 8'h50, 8'h70: cpu_rdata = ch_status[ch_sel];
            8'h80: cpu_rdata = {{32-CHANNELS{1'b0}}, ch_active};
            8'h84: cpu_rdata = global_ie;
            default: cpu_rdata = 32'd0;
        endcase
    end

endmodule
