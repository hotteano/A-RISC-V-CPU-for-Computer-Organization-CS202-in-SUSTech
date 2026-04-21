//============================================================================
// UART - Simple UART Controller (16550-like, placeholder)
//============================================================================
`include "defines.vh"

module uart_controller (
    input  wire        clk,
    input  wire        rst_n,

    // CPU bus interface
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        we,
    input  wire        re,
    output wire        ready,

    // UART signals
    output reg         tx,
    input  wire        rx,

    // Interrupt
    output reg         irq
);

    // Register map
    localparam REG_TXRX  = 3'b000;  // Transmit/Receive buffer
    localparam REG_IER   = 3'b001;  // Interrupt Enable
    localparam REG_IIR   = 3'b010;  // Interrupt Identification
    localparam REG_LCR   = 3'b011;  // Line Control
    localparam REG_LSR   = 3'b101;  // Line Status

    // Internal registers
    reg [7:0] tx_buffer;
    reg [7:0] rx_buffer;
    reg [2:0] ier;
    reg [7:0] lcr;
    reg       tx_busy;
    reg       rx_ready;

    // Baud rate generator (placeholder)
    reg [15:0] baud_div;
    reg [15:0] baud_cnt;

    assign ready = 1'b1;

    // CPU register access
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_buffer <= 8'd0;
            ier       <= 3'd0;
            lcr       <= 8'd0;
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            irq       <= 1'b0;
        end else begin
            if (we) begin
                case (addr[2:0])
                    REG_TXRX: begin
                        tx_buffer <= wdata[7:0];
                        tx_busy   <= 1'b1;
                    end
                    REG_IER: ier <= wdata[2:0];
                    REG_LCR: lcr <= wdata[7:0];
                endcase
            end

            // Interrupt logic
            irq <= (ier[0] && rx_ready) || (ier[1] && !tx_busy);
        end
    end

    // Read logic
    always @(*) begin
        case (addr[2:0])
            REG_TXRX: rdata = {24'd0, rx_buffer};
            REG_IER:  rdata = {29'd0, ier};
            REG_IIR:  rdata = 32'h01;  // No interrupt pending
            REG_LCR:  rdata = {24'd0, lcr};
            REG_LSR:  rdata = {30'd0, rx_ready, !tx_busy};
            default:  rdata = 32'd0;
        endcase
    end

endmodule
