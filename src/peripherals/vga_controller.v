//============================================================================
// VGA Controller
// Supports: 640x480 @ 60Hz standard timing, 8-color output
// Features: Text mode and Graphics mode, Hardware scrolling
//============================================================================
`include "defines.vh"

module vga_controller (
    input  wire        clk,             // System clock (50MHz)
    input  wire        rst_n,
    
    // VGA Interface
    output reg  [3:0]  vga_r,           // Red (4 bits)
    output reg  [3:0]  vga_g,           // Green (4 bits)
    output reg  [3:0]  vga_b,           // Blue (4 bits)
    output reg         vga_hsync,       // Horizontal sync
    output reg         vga_vsync,       // Vertical sync
    
    // CPU Interface
    input  wire [31:0] cpu_addr,
    output reg  [31:0] cpu_rdata,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    output wire        irq_vsync,       // VSync interrupt
    
    // Framebuffer Memory Interface (Dual-port RAM)
    output wire [18:0] fb_read_addr,    // Framebuffer read address
    input  wire [7:0]  fb_read_data,    // Framebuffer pixel data (8-bit color index)
    output wire [18:0] fb_write_addr,   // Framebuffer write address (for CPU)
    output wire [7:0]  fb_write_data,   // Framebuffer write data
    output wire        fb_write_en      // Framebuffer write enable
);

    //========================================================================
    // VGA Timing Parameters (640x480 @ 60Hz)
    //========================================================================
    localparam H_VISIBLE    = 640;      // Horizontal visible area
    localparam H_FRONT      = 16;       // Horizontal front porch
    localparam H_SYNC       = 96;       // Horizontal sync pulse
    localparam H_BACK       = 48;       // Horizontal back porch
    localparam H_TOTAL      = 800;      // Total horizontal pixels
    
    localparam V_VISIBLE    = 480;      // Vertical visible area
    localparam V_FRONT      = 10;       // Vertical front porch
    localparam V_SYNC       = 2;        // Vertical sync pulse
    localparam V_BACK       = 33;       // Vertical back porch
    localparam V_TOTAL      = 525;      // Total vertical lines
    
    //========================================================================
    // Register Map
    //========================================================================
    localparam REG_CTRL         = 4'h0;     // Control register
    localparam REG_STATUS       = 4'h4;     // Status register
    localparam REG_FB_ADDR      = 4'h8;     // Framebuffer base address
    localparam REG_SCROLL_X     = 4'hC;     // Horizontal scroll offset
    localparam REG_SCROLL_Y     = 4'h10;    // Vertical scroll offset
    localparam REG_PALETTE_0    = 4'h20;    // Palette entry 0 (16 palette entries total)
    
    //========================================================================
    // Clock Divider (50MHz -> 25MHz Pixel Clock)
    //========================================================================
    reg clk_div;
    wire pixel_clk = clk_div;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_div <= 1'b0;
        else
            clk_div <= ~clk_div;
    end
    
    //========================================================================
    // VGA Timing Generator
    //========================================================================
    reg [9:0] h_counter;    // Horizontal counter (0-799)
    reg [9:0] v_counter;    // Vertical counter (0-524)
    
    wire h_active = (h_counter < H_VISIBLE);
    wire v_active = (v_counter < V_VISIBLE);
    wire active = h_active && v_active;
    
    // Horizontal timing
    wire h_sync_start = (h_counter == H_VISIBLE + H_FRONT);
    wire h_sync_end   = (h_counter == H_VISIBLE + H_FRONT + H_SYNC - 1);
    wire h_end        = (h_counter == H_TOTAL - 1);
    
    // Vertical timing
    wire v_sync_start = (v_counter == V_VISIBLE + V_FRONT) && h_end;
    wire v_sync_end   = (v_counter == V_VISIBLE + V_FRONT + V_SYNC - 1) && h_end;
    wire v_end        = (v_counter == V_TOTAL - 1) && h_end;
    
    // Counters
    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            h_counter <= 10'd0;
            v_counter <= 10'd0;
        end else begin
            if (h_end) begin
                h_counter <= 10'd0;
                if (v_end)
                    v_counter <= 10'd0;
                else
                    v_counter <= v_counter + 1'b1;
            end else begin
                h_counter <= h_counter + 1'b1;
            end
        end
    end
    
    // Sync signals
    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            vga_hsync <= 1'b1;
            vga_vsync <= 1'b1;
        end else begin
            // Horizontal sync (active low)
            if (h_sync_start)
                vga_hsync <= 1'b0;
            else if (h_sync_end)
                vga_hsync <= 1'b1;
            
            // Vertical sync (active low)
            if (v_sync_start)
                vga_vsync <= 1'b0;
            else if (v_sync_end)
                vga_vsync <= 1'b1;
        end
    end
    
    //========================================================================
    // Framebuffer Address Generation
    //========================================================================
    reg [18:0] fb_base_addr;
    reg [9:0]  scroll_x;
    reg [9:0]  scroll_y;
    
    // Calculate effective coordinates with scroll
    wire [9:0] h_pos = h_counter + scroll_x;
    wire [9:0] v_pos = v_counter + scroll_y;
    
    // Pixel address in framebuffer (640x480 = 307200 pixels)
    // Each pixel is 1 byte (8-bit color index)
    assign fb_read_addr = fb_base_addr + ({9'd0, v_pos} * 19'd640) + {9'd0, h_pos};
    
    //========================================================================
    // Color Palette (256 colors, 12-bit RGB)
    //========================================================================
    reg [11:0] palette [0:255];
    reg [11:0] current_color;
    
    // Default palette (basic 16 colors in lower entries)
    integer i;
    initial begin
        // Standard 16 colors
        palette[0]  = 12'h000;  // Black
        palette[1]  = 12'h00A;  // Blue
        palette[2]  = 12'h0A0;  // Green
        palette[3]  = 12'h0AA;  // Cyan
        palette[4]  = 12'hA00;  // Red
        palette[5]  = 12'hA0A;  // Magenta
        palette[6]  = 12'hAA0;  // Yellow/Brown
        palette[7]  = 12'hAAA;  // Light Gray
        palette[8]  = 12'h555;  // Dark Gray
        palette[9]  = 12'h55F;  // Light Blue
        palette[10] = 12'h5F5;  // Light Green
        palette[11] = 12'h5FF;  // Light Cyan
        palette[12] = 12'hF55;  // Light Red
        palette[13] = 12'hF5F;  // Light Magenta
        palette[14] = 12'hFF5;  // Light Yellow
        palette[15] = 12'hFFF;  // White
        
        // Initialize rest with grayscale
        for (i = 16; i < 256; i = i + 1)
            palette[i] = {i[3:0], i[3:0], i[3:0]};
    end
    
    // Get color from palette
    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n)
            current_color <= 12'h000;
        else if (active)
            current_color <= palette[fb_read_data];
        else
            current_color <= 12'h000;
    end
    
    // Output color
    always @(*) begin
        if (active) begin
            vga_r = current_color[11:8];
            vga_g = current_color[7:4];
            vga_b = current_color[3:0];
        end else begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end
    end
    
    //========================================================================
    // CPU Interface
    //========================================================================
    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg        vsync_irq_en;
    reg        vsync_irq_pending;
    
    // Control bits
    wire ctrl_enable = ctrl_reg[0];
    wire ctrl_text_mode = ctrl_reg[1];
    
    // CPU register access
    assign fb_write_addr = cpu_addr[20:2];  // Word address to byte address
    assign fb_write_data = cpu_wdata[7:0];
    assign fb_write_en = cpu_we && (cpu_addr[3:0] >= 4'h8);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg <= 32'd0;
            fb_base_addr <= 19'd0;
            scroll_x <= 10'd0;
            scroll_y <= 10'd0;
            vsync_irq_en <= 1'b0;
            vsync_irq_pending <= 1'b0;
        end else begin
            // VSync interrupt
            if (v_sync_start) begin
                vsync_irq_pending <= 1'b1;
            end
            
            if (cpu_we) begin
                case (cpu_addr[3:0])
                    REG_CTRL: begin
                        ctrl_reg <= cpu_wdata;
                        vsync_irq_en <= cpu_wdata[2];
                    end
                    REG_FB_ADDR: fb_base_addr <= cpu_wdata[18:0];
                    REG_SCROLL_X: scroll_x <= cpu_wdata[9:0];
                    REG_SCROLL_Y: scroll_y <= cpu_wdata[9:0];
                    default: begin
                        // Palette access
                        if (cpu_addr[3:0] >= REG_PALETTE_0 && cpu_addr[3:0] < REG_PALETTE_0 + 16'h40) begin
                            palette[cpu_addr[7:2]] <= cpu_wdata[11:0];
                        end
                    end
                endcase
            end
            
            if (cpu_re && cpu_addr[3:0] == REG_STATUS) begin
                // Clear VSync interrupt on status read
                vsync_irq_pending <= 1'b0;
            end
        end
    end
    
    // Read data mux
    always @(*) begin
        case (cpu_addr[3:0])
            REG_CTRL:     cpu_rdata = ctrl_reg;
            REG_STATUS:   cpu_rdata = {30'd0, vsync_irq_pending, ctrl_enable};
            REG_FB_ADDR:  cpu_rdata = {13'd0, fb_base_addr};
            REG_SCROLL_X: cpu_rdata = {22'd0, scroll_x};
            REG_SCROLL_Y: cpu_rdata = {22'd0, scroll_y};
            default: begin
                if (cpu_addr[3:0] >= REG_PALETTE_0 && cpu_addr[3:0] < REG_PALETTE_0 + 16'h40)
                    cpu_rdata = {20'd0, palette[cpu_addr[7:2]]};
                else
                    cpu_rdata = 32'd0;
            end
        endcase
    end
    
    // Interrupt output
    assign irq_vsync = vsync_irq_pending && vsync_irq_en;

endmodule
