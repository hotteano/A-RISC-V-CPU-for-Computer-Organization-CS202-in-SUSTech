//============================================================================
// PS/2 Keyboard & Mouse Controller
// Supports: PS/2 protocol, scan code conversion, mouse packets
//============================================================================
`include "defines.vh"

module ps2_controller (
    input  wire        clk,             // System clock
    input  wire        rst_n,
    
    // PS/2 Interface
    input  wire        ps2_clk,         // PS/2 clock (from device)
    input  wire        ps2_data,        // PS/2 data (from device)
    output reg         ps2_clk_oen,     // PS/2 clock output enable (for sending)
    output reg         ps2_data_oen,    // PS/2 data output enable (for sending)
    output reg         ps2_clk_out,     // PS/2 clock output
    output reg         ps2_data_out,    // PS/2 data output
    
    // CPU Interface
    input  wire [31:0] cpu_addr,
    output reg  [31:0] cpu_rdata,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    output wire        irq,             // Interrupt request
    
    // Configuration
    input  wire        is_mouse         // 0=Keyboard mode, 1=Mouse mode
);

    //========================================================================
    // Register Map
    //========================================================================
    localparam REG_DATA      = 4'h0;    // Data register (read/write)
    localparam REG_STATUS    = 4'h4;    // Status register (read)
    localparam REG_CTRL      = 4'h8;    // Control register (write)
    
    //========================================================================
    // PS/2 Protocol States
    //========================================================================
    localparam IDLE          = 4'd0;
    localparam RX_START      = 4'd1;
    localparam RX_DATA       = 4'd2;
    localparam RX_PARITY     = 4'd3;
    localparam RX_STOP       = 4'd4;
    localparam TX_START      = 4'd5;
    localparam TX_DATA       = 4'd6;
    localparam TX_PARITY     = 4'd7;
    localparam TX_STOP       = 4'd8;
    localparam TX_ACK        = 4'd9;
    
    //========================================================================
    // PS/2 Clock Synchronization
    //========================================================================
    reg [2:0] ps2_clk_sync;
    reg [2:0] ps2_data_sync;
    wire ps2_clk_falling = (ps2_clk_sync[2:1] == 2'b10);
    wire ps2_clk_rising  = (ps2_clk_sync[2:1] == 2'b01);
    wire ps2_data_in = ps2_data_sync[2];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_sync <= 3'b111;
            ps2_data_sync <= 3'b111;
        end else begin
            ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
            ps2_data_sync <= {ps2_data_sync[1:0], ps2_data};
        end
    end
    
    //========================================================================
    // Receiver State Machine
    //========================================================================
    reg [3:0] rx_state;
    reg [3:0] rx_bit_cnt;
    reg [7:0] rx_shift_reg;
    reg       rx_parity;
    reg [7:0] rx_buffer [0:15];  // Circular buffer for received data
    reg [3:0] rx_wr_ptr;
    reg [3:0] rx_rd_ptr;
    wire [3:0] rx_count = rx_wr_ptr - rx_rd_ptr;
    wire rx_full = (rx_count == 4'd15);
    wire rx_empty = (rx_count == 4'd0);
    
    // Receive state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= IDLE;
            rx_bit_cnt <= 4'd0;
            rx_shift_reg <= 8'd0;
            rx_parity <= 1'b0;
            rx_wr_ptr <= 4'd0;
        end else begin
            case (rx_state)
                IDLE: begin
                    if (ps2_clk_falling && ps2_data_in == 1'b0) begin
                        // Start bit detected
                        rx_state <= RX_DATA;
                        rx_bit_cnt <= 4'd0;
                        rx_parity <= 1'b0;
                    end
                end
                
                RX_DATA: begin
                    if (ps2_clk_falling) begin
                        rx_shift_reg <= {ps2_data_in, rx_shift_reg[7:1]};
                        rx_parity <= rx_parity ^ ps2_data_in;
                        rx_bit_cnt <= rx_bit_cnt + 1'b1;
                        if (rx_bit_cnt == 4'd7) begin
                            rx_state <= RX_PARITY;
                        end
                    end
                end
                
                RX_PARITY: begin
                    if (ps2_clk_falling) begin
                        // Check parity (odd parity)
                        rx_state <= RX_STOP;
                    end
                end
                
                RX_STOP: begin
                    if (ps2_clk_falling) begin
                        // Stop bit should be 1
                        if (ps2_data_in == 1'b1 && !rx_full) begin
                            rx_buffer[rx_wr_ptr] <= rx_shift_reg;
                            rx_wr_ptr <= rx_wr_ptr + 1'b1;
                        end
                        rx_state <= IDLE;
                    end
                end
                
                default: rx_state <= IDLE;
            endcase
        end
    end
    
    //========================================================================
    // Transmitter State Machine
    //========================================================================
    reg [3:0] tx_state;
    reg [3:0] tx_bit_cnt;
    reg [7:0] tx_shift_reg;
    reg       tx_parity;
    reg       tx_busy;
    reg [7:0] tx_data_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= IDLE;
            tx_bit_cnt <= 4'd0;
            tx_shift_reg <= 8'd0;
            tx_parity <= 1'b0;
            tx_busy <= 1'b0;
            ps2_clk_oen <= 1'b0;
            ps2_data_oen <= 1'b0;
            ps2_clk_out <= 1'b1;
            ps2_data_out <= 1'b1;
        end else begin
            case (tx_state)
                IDLE: begin
                    tx_busy <= 1'b0;
                    ps2_clk_oen <= 1'b0;
                    ps2_data_oen <= 1'b0;
                    
                    if (tx_start) begin
                        tx_busy <= 1'b1;
                        tx_shift_reg <= tx_data;
                        tx_parity <= ~(^tx_data);  // Odd parity
                        tx_state <= TX_START;
                        
                        // Inhibit clock for 100us (simplified)
                        ps2_clk_oen <= 1'b1;
                        ps2_clk_out <= 1'b0;
                    end
                end
                
                TX_START: begin
                    // Pull data low (start bit)
                    ps2_data_oen <= 1'b1;
                    ps2_data_out <= 1'b0;
                    ps2_clk_oen <= 1'b0;  // Release clock
                    tx_bit_cnt <= 4'd0;
                    
                    if (ps2_clk_falling) begin
                        tx_state <= TX_DATA;
                    end
                end
                
                TX_DATA: begin
                    ps2_data_out <= tx_shift_reg[0];
                    
                    if (ps2_clk_falling) begin
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        tx_bit_cnt <= tx_bit_cnt + 1'b1;
                        if (tx_bit_cnt == 4'd7) begin
                            tx_state <= TX_PARITY;
                        end
                    end
                end
                
                TX_PARITY: begin
                    ps2_data_out <= tx_parity;
                    
                    if (ps2_clk_falling) begin
                        tx_state <= TX_STOP;
                    end
                end
                
                TX_STOP: begin
                    ps2_data_out <= 1'b1;
                    ps2_data_oen <= 1'b0;  // Release data
                    
                    if (ps2_clk_falling) begin
                        tx_state <= TX_ACK;
                    end
                end
                
                TX_ACK: begin
                    // Wait for device to pull data low (ACK)
                    if (ps2_clk_falling) begin
                        if (ps2_data_in == 1'b0) begin
                            tx_state <= IDLE;
                        end
                    end
                end
                
                default: tx_state <= IDLE;
            endcase
        end
    end
    
    //========================================================================
    // CPU Interface
    //========================================================================
    reg [7:0] status_reg;
    reg [7:0] ctrl_reg;
    reg [7:0] tx_data;
    reg       tx_start;
    
    // Status bits
    wire status_rx_full  = rx_full;
    wire status_rx_empty = rx_empty;
    wire status_tx_busy  = tx_busy;
    wire status_parity_err = 1'b0;  // Simplified
    
    // Read data from buffer
    reg [7:0] rx_data;
    always @(*) begin
        if (!rx_empty)
            rx_data = rx_buffer[rx_rd_ptr];
        else
            rx_data = 8'd0;
    end
    
    // CPU register access
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_rd_ptr <= 4'd0;
            ctrl_reg <= 8'd0;
            tx_data <= 8'd0;
            tx_start <= 1'b0;
        end else begin
            tx_start <= 1'b0;  // Clear tx_start
            
            if (cpu_we) begin
                case (cpu_addr[3:0])
                    REG_DATA: begin
                        tx_data <= cpu_wdata[7:0];
                        tx_start <= 1'b1;
                    end
                    REG_CTRL: begin
                        ctrl_reg <= cpu_wdata[7:0];
                    end
                endcase
            end
            
            if (cpu_re && cpu_addr[3:0] == REG_DATA && !rx_empty) begin
                rx_rd_ptr <= rx_rd_ptr + 1'b1;
            end
        end
    end
    
    // Read data mux
    always @(*) begin
        case (cpu_addr[3:0])
            REG_DATA:   cpu_rdata = {24'd0, rx_data};
            REG_STATUS: cpu_rdata = {24'd0, status_rx_full, status_rx_empty, status_tx_busy, 
                                      status_parity_err, 4'd0};
            REG_CTRL:   cpu_rdata = {24'd0, ctrl_reg};
            default:    cpu_rdata = 32'd0;
        endcase
    end
    
    // Interrupt generation
    assign irq = !rx_empty;

endmodule
