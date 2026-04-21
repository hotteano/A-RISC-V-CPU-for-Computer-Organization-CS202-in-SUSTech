//============================================================================
// PS/2 Keyboard Controller
//============================================================================
`include "defines.vh"

module ps2_controller (
    input  wire        clk,
    input  wire        rst_n,

    // CPU bus interface
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        we,
    input  wire        re,
    output wire        ready,

    // PS/2 signals
    input  wire        ps2_clk,
    input  wire        ps2_data,

    // Interrupt
    output reg         irq
);

    // PS/2 shift register
    reg [10:0] ps2_shift;
    reg [3:0]  bit_count;
    reg        ps2_clk_prev;
    reg [7:0]  scancode;
    reg        scancode_ready;

    // FIFO (4-entry simple buffer)
    reg [7:0] fifo [0:3];
    reg [1:0] wr_ptr;
    reg [1:0] rd_ptr;
    wire      fifo_empty;
    wire      fifo_full;

    assign fifo_empty = (wr_ptr == rd_ptr);
    assign fifo_full  = ((wr_ptr + 1) == rd_ptr);
    assign ready      = 1'b1;

    // PS/2 data reception (synchronous to clk)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_shift      <= 11'd0;
            bit_count      <= 4'd0;
            ps2_clk_prev   <= 1'b1;
            scancode       <= 8'd0;
            scancode_ready <= 1'b0;
            wr_ptr         <= 2'd0;
            irq            <= 1'b0;
        end else begin
            ps2_clk_prev <= ps2_clk;
            scancode_ready <= 1'b0;

            // Detect falling edge of PS/2 clock
            if (ps2_clk_prev && !ps2_clk) begin
                ps2_shift <= {ps2_data, ps2_shift[10:1]};
                if (bit_count < 10)
                    bit_count <= bit_count + 1;
                else begin
                    // Full frame received: start bit + 8 data + parity + stop
                    bit_count <= 4'd0;
                    scancode <= ps2_shift[8:1];
                    scancode_ready <= 1'b1;
                end
            end

            // Push to FIFO
            if (scancode_ready && !fifo_full) begin
                fifo[wr_ptr] <= scancode;
                wr_ptr <= wr_ptr + 1;
            end

            // Interrupt when data available
            irq <= !fifo_empty;
        end
    end

    // CPU read
    always @(*) begin
        if (addr[2:0] == 3'b000)
            rdata = fifo_empty ? 32'd0 : {24'd0, fifo[rd_ptr]};
        else if (addr[2:0] == 3'b100)
            rdata = {30'd0, fifo_full, !fifo_empty};
        else
            rdata = 32'd0;
    end

    // Pop from FIFO on read
    always @(posedge clk) begin
        if (re && addr[2:0] == 3'b000 && !fifo_empty)
            rd_ptr <= rd_ptr + 1;
    end

endmodule
