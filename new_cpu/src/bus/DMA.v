//============================================================================
// DMA Controller - Simple memory-to-memory DMA
//============================================================================
`include "defines.vh"

module dma_controller (
    input  wire        clk,
    input  wire        rst_n,

    // Control interface (CPU register access)
    input  wire [31:0] ctrl_addr,
    input  wire [31:0] ctrl_wdata,
    output reg  [31:0] ctrl_rdata,
    input  wire        ctrl_we,
    input  wire        ctrl_re,
    output wire        ctrl_ready,

    // DMA bus master interface (to arbiter)
    output reg  [31:0] dma_addr,
    output reg  [31:0] dma_wdata,
    input  wire [31:0] dma_rdata,
    output reg         dma_we,
    output reg         dma_re,
    input  wire        dma_ready,

    // DMA request/acknowledge
    input  wire        dma_start,
    output reg         dma_done,
    output reg         dma_irq
);

    // DMA control registers
    reg [31:0] src_addr;
    reg [31:0] dst_addr;
    reg [31:0] transfer_len;
    reg [31:0] ctrl_reg;

    // DMA state machine
    localparam IDLE     = 2'b00;
    localparam READ     = 2'b01;
    localparam WRITE    = 2'b10;
    localparam DONE     = 2'b11;

    reg [1:0] state;
    reg [31:0] count;
    reg [31:0] buffer;

    assign ctrl_ready = 1'b1;

    // Control register access
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_addr     <= 32'd0;
            dst_addr     <= 32'd0;
            transfer_len <= 32'd0;
            ctrl_reg     <= 32'd0;
        end else if (ctrl_we) begin
            case (ctrl_addr[3:0])
                4'h0: src_addr     <= ctrl_wdata;
                4'h4: dst_addr     <= ctrl_wdata;
                4'h8: transfer_len <= ctrl_wdata;
                4'hC: ctrl_reg     <= ctrl_wdata;
            endcase
        end
    end

    always @(*) begin
        case (ctrl_addr[3:0])
            4'h0: ctrl_rdata = src_addr;
            4'h4: ctrl_rdata = dst_addr;
            4'h8: ctrl_rdata = transfer_len;
            4'hC: ctrl_rdata = ctrl_reg;
            default: ctrl_rdata = 32'd0;
        endcase
    end

    // DMA state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            count    <= 32'd0;
            buffer   <= 32'd0;
            dma_addr <= 32'd0;
            dma_wdata<= 32'd0;
            dma_we   <= 1'b0;
            dma_re   <= 1'b0;
            dma_done <= 1'b0;
            dma_irq  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    dma_done <= 1'b0;
                    dma_irq  <= 1'b0;
                    if (dma_start) begin
                        state <= READ;
                        count <= 32'd0;
                    end
                end
                READ: begin
                    if (count < transfer_len) begin
                        dma_addr <= src_addr + (count << 2);
                        dma_re   <= 1'b1;
                        if (dma_ready) begin
                            buffer <= dma_rdata;
                            dma_re <= 1'b0;
                            state  <= WRITE;
                        end
                    end else begin
                        state    <= DONE;
                    end
                end
                WRITE: begin
                    dma_addr  <= dst_addr + (count << 2);
                    dma_wdata <= buffer;
                    dma_we    <= 1'b1;
                    if (dma_ready) begin
                        dma_we <= 1'b0;
                        count  <= count + 1;
                        state  <= READ;
                    end
                end
                DONE: begin
                    dma_done <= 1'b1;
                    dma_irq  <= ctrl_reg[0];
                    state    <= IDLE;
                end
            endcase
        end
    end

endmodule
