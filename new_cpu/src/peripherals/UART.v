//============================================================================
// UART Controller - 16550-like with TX/RX shift logic
// Target: 50 MHz clk -> 115200 baud (div=434)
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
    localparam REG_IIR   = 3'b010;  // Interrupt Identification (read-only)
    localparam REG_LCR   = 3'b011;  // Line Control
    localparam REG_LSR   = 3'b101;  // Line Status

    //------------------------------------------------------------------------
    // Baud Rate Generator
    //------------------------------------------------------------------------
    // Default: 50 MHz / 115200 baud = 434.028
    localparam BAUD_DIV = 16'd434;

    reg [15:0] baud_cnt;
    reg        baud_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 16'd0;
            baud_tick <= 1'b0;
        end else begin
            if (baud_cnt >= BAUD_DIV - 1) begin
                baud_cnt <= 16'd0;
                baud_tick <= 1'b1;
            end else begin
                baud_cnt <= baud_cnt + 1'b1;
                baud_tick <= 1'b0;
            end
        end
    end

    //------------------------------------------------------------------------
    // TX Logic
    //------------------------------------------------------------------------
    localparam TX_IDLE  = 2'b00;
    localparam TX_START = 2'b01;
    localparam TX_DATA  = 2'b10;
    localparam TX_STOP  = 2'b11;

    reg [1:0]  tx_state;
    reg [7:0]  tx_shift;
    reg [2:0]  tx_bit_cnt;
    reg        tx_busy;
    reg        tx_done;         // Pulse when TX completes

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx        <= 1'b1;
            tx_state  <= TX_IDLE;
            tx_shift  <= 8'd0;
            tx_bit_cnt<= 3'd0;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            // Load new TX data from CPU
            if (we && (addr[2:0] == REG_TXRX) && !tx_busy) begin
                tx_shift <= wdata[7:0];
                tx_busy  <= 1'b1;
            end

            if (baud_tick) begin
                case (tx_state)
                    TX_IDLE: begin
                        if (tx_busy) begin
                            tx       <= 1'b0;      // Start bit
                            tx_state <= TX_START;
                        end else begin
                            tx <= 1'b1;
                        end
                    end
                    TX_START: begin
                        tx       <= tx_shift[0];
                        tx_state <= TX_DATA;
                        tx_bit_cnt <= 3'd0;
                    end
                    TX_DATA: begin
                        if (tx_bit_cnt == 3'd7) begin
                            tx       <= 1'b1;      // Stop bit
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1'b1;
                            tx       <= tx_shift[tx_bit_cnt + 1];
                        end
                    end
                    TX_STOP: begin
                        tx       <= 1'b1;
                        tx_state <= TX_IDLE;
                        tx_busy  <= 1'b0;
                        tx_done  <= 1'b1;
                    end
                endcase
            end
        end
    end

    //------------------------------------------------------------------------
    // RX Logic
    //------------------------------------------------------------------------
    localparam RX_IDLE  = 2'b00;
    localparam RX_START = 2'b01;
    localparam RX_DATA  = 2'b10;
    localparam RX_STOP  = 2'b11;

    reg [1:0]  rx_state;
    reg [7:0]  rx_shift;
    reg [2:0]  rx_bit_cnt;
    reg        rx_ready;
    reg        rx_ready_clear;
    reg [7:0]  rx_buffer;

    // Synchronize rx to avoid metastability
    reg        rx_sync1, rx_sync2;
    wire       rx_sync = rx_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state  <= RX_IDLE;
            rx_shift  <= 8'd0;
            rx_bit_cnt<= 3'd0;
            rx_ready  <= 1'b0;
            rx_buffer <= 8'd0;
        end else begin
            rx_ready_clear <= 1'b0;

            // CPU reads RX buffer -> clear ready
            if (re && (addr[2:0] == REG_TXRX)) begin
                rx_ready_clear <= 1'b1;
            end

            if (rx_ready_clear)
                rx_ready <= 1'b0;

            if (baud_tick) begin
                case (rx_state)
                    RX_IDLE: begin
                        if (!rx_sync) begin
                            // Start bit detected
                            rx_state <= RX_START;
                        end
                    end
                    RX_START: begin
                        if (!rx_sync) begin
                            // Confirm start bit
                            rx_state   <= RX_DATA;
                            rx_bit_cnt <= 3'd0;
                        end else begin
                            rx_state <= RX_IDLE;  // Glitch, abort
                        end
                    end
                    RX_DATA: begin
                        rx_shift[rx_bit_cnt] <= rx_sync;
                        if (rx_bit_cnt == 3'd7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 1'b1;
                        end
                    end
                    RX_STOP: begin
                        if (rx_sync) begin
                            rx_buffer <= rx_shift;
                            rx_ready  <= 1'b1;
                        end
                        rx_state <= RX_IDLE;
                    end
                endcase
            end
        end
    end

    //------------------------------------------------------------------------
    // CPU Register Access
    //------------------------------------------------------------------------
    reg [2:0] ier;
    reg [7:0] lcr;

    assign ready = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ier <= 3'd0;
            lcr <= 8'd0;
            irq <= 1'b0;
        end else begin
            if (we) begin
                case (addr[2:0])
                    REG_TXRX: begin
                        // TX load handled in TX logic above
                    end
                    REG_IER: ier <= wdata[2:0];
                    REG_LCR: lcr <= wdata[7:0];
                endcase
            end

            // Interrupt logic: IER[0]=RX ready, IER[1]=TX empty
            irq <= (ier[0] && rx_ready) || (ier[1] && !tx_busy);
        end
    end

    // Read logic
    always @(*) begin
        case (addr[2:0])
            REG_TXRX: rdata = {24'd0, rx_buffer};
            REG_IER:  rdata = {29'd0, ier};
            REG_IIR:  rdata = {30'd0, rx_ready, !tx_busy};
            REG_LCR:  rdata = {24'd0, lcr};
            REG_LSR:  rdata = {30'd0, rx_ready, !tx_busy};
            default:  rdata = 32'd0;
        endcase
    end

endmodule
