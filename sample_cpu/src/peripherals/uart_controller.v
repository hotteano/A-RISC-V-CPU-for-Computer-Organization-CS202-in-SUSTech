//============================================================================
// UART Controller
// Features: Configurable baud rate, 8N1 format, TX/RX FIFOs
//           Hardware flow control (RTS/CTS) - optional
//============================================================================
`include "defines.vh"

module uart_controller (
    input  wire        clk,             // System clock
    input  wire        rst_n,
    
    // UART Interface
    input  wire        uart_rx,         // Receive data
    output reg         uart_tx,         // Transmit data
    
    // CPU Interface
    input  wire [31:0] cpu_addr,
    output reg  [31:0] cpu_rdata,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    output wire        irq_rx,          // RX interrupt
    output wire        irq_tx,          // TX interrupt
    
    // Configuration (optional)
    input  wire [15:0] clk_div          // Clock divider for baud rate
);

    //========================================================================
    // Register Map
    //========================================================================
    localparam REG_TX_DATA   = 4'h0;    // Transmit data (write)
    localparam REG_RX_DATA   = 4'h0;    // Receive data (read)
    localparam REG_STATUS    = 4'h4;    // Status register
    localparam REG_CTRL      = 4'h8;    // Control register
    localparam REG_BAUD      = 4'hC;    // Baud rate divisor
    
    //========================================================================
    // UART Parameters
    //========================================================================
    localparam DEFAULT_DIV   = 16'd434; // 50MHz / 115200 baud = 434
    localparam TX_FIFO_DEPTH = 16;
    localparam RX_FIFO_DEPTH = 16;
    
    //========================================================================
    // Clock Divider for Baud Rate Generation
    //========================================================================
    reg [15:0] baud_div_reg;
    wire [15:0] baud_div = (baud_div_reg == 16'd0) ? DEFAULT_DIV : baud_div_reg;
    
    // TX baud tick
    reg [15:0] tx_baud_counter;
    reg        tx_baud_tick;
    
    // RX baud tick (oversampled by 16)
    reg [15:0] rx_baud_counter;
    reg        rx_baud_tick;
    reg [3:0]  rx_sample_count;
    
    // Baud rate generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_baud_counter <= 16'd0;
            tx_baud_tick <= 1'b0;
            rx_baud_counter <= 16'd0;
            rx_baud_tick <= 1'b0;
            rx_sample_count <= 4'd0;
        end else begin
            // TX baud tick
            if (tx_baud_counter >= baud_div - 1) begin
                tx_baud_counter <= 16'd0;
                tx_baud_tick <= 1'b1;
            end else begin
                tx_baud_counter <= tx_baud_counter + 1'b1;
                tx_baud_tick <= 1'b0;
            end
            
            // RX baud tick (16x oversampling)
            if (rx_baud_counter >= (baud_div >> 4) - 1) begin
                rx_baud_counter <= 16'd0;
                rx_baud_tick <= 1'b1;
                rx_sample_count <= rx_sample_count + 1'b1;
            end else begin
                rx_baud_counter <= rx_baud_counter + 1'b1;
                rx_baud_tick <= 1'b0;
            end
        end
    end
    
    //========================================================================
    // Transmitter State Machine
    //========================================================================
    localparam TX_IDLE   = 3'd0;
    localparam TX_START  = 3'd1;
    localparam TX_DATA   = 3'd2;
    localparam TX_STOP   = 3'd3;
    
    reg [2:0] tx_state;
    reg [2:0] tx_bit_cnt;
    reg [7:0] tx_shift_reg;
    reg       tx_busy;
    
    // TX FIFO
    reg [7:0] tx_fifo [0:TX_FIFO_DEPTH-1];
    reg [3:0] tx_wr_ptr;
    reg [3:0] tx_rd_ptr;
    wire [3:0] tx_fifo_count = tx_wr_ptr - tx_rd_ptr;
    wire tx_fifo_full = (tx_fifo_count == TX_FIFO_DEPTH);
    wire tx_fifo_empty = (tx_fifo_count == 4'd0);
    
    // TX State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_bit_cnt <= 3'd0;
            tx_shift_reg <= 8'd0;
            tx_busy <= 1'b0;
            uart_tx <= 1'b1;  // Idle high
            tx_rd_ptr <= 4'd0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    uart_tx <= 1'b1;
                    if (!tx_fifo_empty && tx_baud_tick) begin
                        tx_shift_reg <= tx_fifo[tx_rd_ptr];
                        tx_rd_ptr <= tx_rd_ptr + 1'b1;
                        tx_state <= TX_START;
                        tx_busy <= 1'b1;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end
                
                TX_START: begin
                    if (tx_baud_tick) begin
                        uart_tx <= 1'b0;  // Start bit
                        tx_bit_cnt <= 3'd0;
                        tx_state <= TX_DATA;
                    end
                end
                
                TX_DATA: begin
                    if (tx_baud_tick) begin
                        uart_tx <= tx_shift_reg[0];
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        tx_bit_cnt <= tx_bit_cnt + 1'b1;
                        if (tx_bit_cnt == 3'd7) begin
                            tx_state <= TX_STOP;
                        end
                    end
                end
                
                TX_STOP: begin
                    if (tx_baud_tick) begin
                        uart_tx <= 1'b1;  // Stop bit
                        tx_state <= TX_IDLE;
                    end
                end
                
                default: tx_state <= TX_IDLE;
            endcase
        end
    end
    
    //========================================================================
    // Receiver State Machine
    //========================================================================
    localparam RX_IDLE   = 3'd0;
    localparam RX_START  = 3'd1;
    localparam RX_DATA   = 3'd2;
    localparam RX_STOP   = 3'd3;
    
    reg [2:0] rx_state;
    reg [3:0] rx_sample_cnt;
    reg [2:0] rx_bit_cnt;
    reg [7:0] rx_shift_reg;
    reg       rx_busy;
    
    // RX FIFO
    reg [7:0] rx_fifo [0:RX_FIFO_DEPTH-1];
    reg [3:0] rx_wr_ptr;
    reg [3:0] rx_rd_ptr;
    wire [3:0] rx_fifo_count = rx_wr_ptr - rx_rd_ptr;
    wire rx_fifo_full = (rx_fifo_count == RX_FIFO_DEPTH);
    wire rx_fifo_empty = (rx_fifo_count == 4'd0);
    
    // RX synchronization
    reg [2:0] uart_rx_sync;
    wire uart_rx_in = uart_rx_sync[2];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            uart_rx_sync <= 3'b111;
        else
            uart_rx_sync <= {uart_rx_sync[1:0], uart_rx};
    end
    
    // RX State Machine (with oversampling)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_sample_cnt <= 4'd0;
            rx_bit_cnt <= 3'd0;
            rx_shift_reg <= 8'd0;
            rx_wr_ptr <= 4'd0;
        end else begin
            case (rx_state)
                RX_IDLE: begin
                    if (uart_rx_in == 1'b0 && rx_sample_count == 4'd8) begin
                        // Start bit detected at middle of bit period
                        rx_state <= RX_START;
                        rx_sample_cnt <= 4'd0;
                    end
                end
                
                RX_START: begin
                    if (rx_baud_tick) begin
                        rx_sample_cnt <= rx_sample_cnt + 1'b1;
                        if (rx_sample_cnt == 4'd15) begin
                            // Middle of start bit
                            rx_state <= RX_DATA;
                            rx_bit_cnt <= 3'd0;
                        end
                    end
                end
                
                RX_DATA: begin
                    if (rx_baud_tick) begin
                        rx_sample_cnt <= rx_sample_cnt + 1'b1;
                        if (rx_sample_cnt == 4'd7) begin
                            // Sample at middle of bit
                            rx_shift_reg <= {uart_rx_in, rx_shift_reg[7:1]};
                        end else if (rx_sample_cnt == 4'd15) begin
                            rx_bit_cnt <= rx_bit_cnt + 1'b1;
                            if (rx_bit_cnt == 3'd7) begin
                                rx_state <= RX_STOP;
                            end
                        end
                    end
                end
                
                RX_STOP: begin
                    if (rx_baud_tick) begin
                        rx_sample_cnt <= rx_sample_cnt + 1'b1;
                        if (rx_sample_cnt == 4'd15) begin
                            // Stop bit received
                            if (!rx_fifo_full) begin
                                rx_fifo[rx_wr_ptr] <= rx_shift_reg;
                                rx_wr_ptr <= rx_wr_ptr + 1'b1;
                            end
                            rx_state <= RX_IDLE;
                        end
                    end
                end
                
                default: rx_state <= RX_IDLE;
            endcase
        end
    end
    
    //========================================================================
    // CPU Interface
    //========================================================================
    reg [31:0] ctrl_reg;
    
    // Control bits
    wire ctrl_tx_irq_en = ctrl_reg[0];
    wire ctrl_rx_irq_en = ctrl_reg[1];
    wire ctrl_tx_enable = ctrl_reg[2];
    wire ctrl_rx_enable = ctrl_reg[3];
    
    // Status bits
    wire status_tx_empty = tx_fifo_empty;
    wire status_tx_full  = tx_fifo_full;
    wire status_rx_empty = rx_fifo_empty;
    wire status_rx_full  = rx_fifo_full;
    wire status_tx_busy  = tx_busy;
    
    // CPU register access
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg <= 32'h0000_000F;  // Enable TX/RX by default
            tx_wr_ptr <= 4'd0;
            rx_rd_ptr <= 4'd0;
            baud_div_reg <= DEFAULT_DIV;
        end else begin
            if (cpu_we) begin
                case (cpu_addr[3:0])
                    REG_TX_DATA: begin
                        if (!tx_fifo_full) begin
                            tx_fifo[tx_wr_ptr] <= cpu_wdata[7:0];
                            tx_wr_ptr <= tx_wr_ptr + 1'b1;
                        end
                    end
                    REG_CTRL: ctrl_reg <= cpu_wdata;
                    REG_BAUD: baud_div_reg <= cpu_wdata[15:0];
                endcase
            end
            
            if (cpu_re && cpu_addr[3:0] == REG_RX_DATA && !rx_fifo_empty) begin
                rx_rd_ptr <= rx_rd_ptr + 1'b1;
            end
        end
    end
    
    // Read data mux
    always @(*) begin
        case (cpu_addr[3:0])
            REG_RX_DATA:  cpu_rdata = {24'd0, rx_fifo_empty ? 8'd0 : rx_fifo[rx_rd_ptr]};
            REG_STATUS:   cpu_rdata = {24'd0, status_rx_full, status_rx_empty, 
                                        status_tx_full, status_tx_empty, 
                                        status_tx_busy, 3'd0};
            REG_CTRL:     cpu_rdata = ctrl_reg;
            REG_BAUD:     cpu_rdata = {16'd0, baud_div_reg};
            default:      cpu_rdata = 32'd0;
        endcase
    end
    
    // Interrupt generation
    assign irq_rx = ctrl_rx_irq_en && !rx_fifo_empty;
    assign irq_tx = ctrl_tx_irq_en && tx_fifo_empty && !tx_busy;

endmodule
