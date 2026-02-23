//============================================================================
// LED Controller
// Features: GPIO for LEDs, switches, buttons
//           PWM dimming support, pattern generation
//============================================================================
`include "defines.vh"

module led_controller (
    input  wire        clk,
    input  wire        rst_n,
    
    // LED Outputs (16 LEDs)
    output reg  [15:0] leds,
    
    // Switch Inputs (16 switches)
    input  wire [15:0] switches,
    
    // Button Inputs (5 buttons: up, down, left, right, center)
    input  wire [4:0]  buttons,
    
    // 7-Segment Display Outputs (8 digits, 8 segments each)
    output reg  [7:0]  seg_display [0:7],  // Segment data for each digit
    output reg  [7:0]  seg_enable,         // Digit enable signals
    
    // CPU Interface
    input  wire [31:0] cpu_addr,
    output reg  [31:0] cpu_rdata,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    output wire        irq_buttons         // Button press interrupt
);

    //========================================================================
    // Register Map
    //========================================================================
    localparam REG_LED_DATA     = 4'h0;     // LED output data
    localparam REG_LED_PWM      = 4'h4;     // LED PWM duty cycle
    localparam REG_SWITCH_DATA  = 4'h8;     // Switch input data
    localparam REG_BUTTON_DATA  = 4'hC;     // Button input data
    localparam REG_BUTTON_EDGE  = 4'h10;    // Button edge detection
    localparam REG_BUTTON_MASK  = 4'h14;    // Button interrupt mask
    localparam REG_SEG_DATA_0   = 4'h20;    // 7-segment digit 0-1
    localparam REG_SEG_DATA_1   = 4'h24;    // 7-segment digit 2-3
    localparam REG_SEG_DATA_2   = 4'h28;    // 7-segment digit 4-5
    localparam REG_SEG_DATA_3   = 4'h2C;    // 7-segment digit 6-7
    localparam REG_SEG_CTRL     = 4'h30;    // 7-segment control
    
    //========================================================================
    // LED Control with PWM
    //========================================================================
    reg [15:0] led_data_reg;
    reg [7:0]  led_pwm_duty;    // PWM duty cycle (0-255)
    reg [7:0]  pwm_counter;
    wire       pwm_out = (pwm_counter < led_pwm_duty);
    
    // PWM counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_counter <= 8'd0;
        else
            pwm_counter <= pwm_counter + 1'b1;
    end
    
    // LED output with PWM
    always @(*) begin
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            leds[i] = led_data_reg[i] && pwm_out;
        end
    end
    
    //========================================================================
    // Button Debounce and Edge Detection
    //========================================================================
    reg [4:0]  button_sync [0:2];
    reg [4:0]  button_debounced;
    reg [4:0]  button_last;
    reg [4:0]  button_edge;
    reg [4:0]  button_irq_mask;
    reg [15:0] debounce_counter [0:4];
    
    wire [4:0] button_raw = buttons;
    
    integer b;
    
    // Button synchronization and debounce
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (b = 0; b < 3; b = b + 1)
                button_sync[b] <= 5'b00000;
            button_debounced <= 5'b00000;
            button_last <= 5'b00000;
            button_edge <= 5'b00000;
            for (b = 0; b < 5; b = b + 1)
                debounce_counter[b] <= 16'd0;
        end else begin
            // Synchronize buttons
            button_sync[0] <= button_raw;
            button_sync[1] <= button_sync[0];
            button_sync[2] <= button_sync[1];
            
            // Debounce (10ms at 50MHz = 500000 cycles, simplified to 50000)
            for (b = 0; b < 5; b = b + 1) begin
                if (button_sync[2][b] != button_debounced[b]) begin
                    if (debounce_counter[b] >= 16'd50000) begin
                        button_debounced[b] <= button_sync[2][b];
                        debounce_counter[b] <= 16'd0;
                    end else begin
                        debounce_counter[b] <= debounce_counter[b] + 1'b1;
                    end
                end else begin
                    debounce_counter[b] <= 16'd0;
                end
            end
            
            // Edge detection (rising edge)
            button_last <= button_debounced;
            button_edge <= button_debounced & ~button_last;
        end
    end
    
    //========================================================================
    // 7-Segment Display Controller
    //========================================================================
    reg [7:0]  seg_data [0:7];      // Segment patterns (a-g, dp)
    reg        seg_scanning;
    reg [2:0]  seg_scan_counter;
    reg [19:0] seg_refresh_counter;
    
    // Segment encoding (common cathode: 1=on, 0=off)
    // Format: {dp, g, f, e, d, c, b, a}
    function [7:0] digit_to_seg;
        input [3:0] digit;
        begin
            case (digit)
                4'h0: digit_to_seg = 8'b0011_1111;
                4'h1: digit_to_seg = 8'b0000_0110;
                4'h2: digit_to_seg = 8'b0101_1011;
                4'h3: digit_to_seg = 8'b0100_1111;
                4'h4: digit_to_seg = 8'b0110_0110;
                4'h5: digit_to_seg = 8'b0110_1101;
                4'h6: digit_to_seg = 8'b0111_1101;
                4'h7: digit_to_seg = 8'b0000_0111;
                4'h8: digit_to_seg = 8'b0111_1111;
                4'h9: digit_to_seg = 8'b0110_1111;
                4'hA: digit_to_seg = 8'b0111_0111;
                4'hB: digit_to_seg = 8'b0111_1100;
                4'hC: digit_to_seg = 8'b0011_1001;
                4'hD: digit_to_seg = 8'b0101_1110;
                4'hE: digit_to_seg = 8'b0111_1001;
                4'hF: digit_to_seg = 8'b0111_0001;
            endcase
        end
    endfunction
    
    // 7-segment refresh (scanning display)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seg_refresh_counter <= 20'd0;
            seg_scan_counter <= 3'd0;
            seg_enable <= 8'b1111_1111;
            for (b = 0; b < 8; b = b + 1)
                seg_display[b] <= 8'd0;
        end else begin
            // Refresh rate: 50MHz / 2^13 = ~6kHz per digit
            seg_refresh_counter <= seg_refresh_counter + 1'b1;
            
            if (seg_refresh_counter[12:0] == 13'd0) begin
                // Move to next digit
                seg_scan_counter <= seg_scan_counter + 1'b1;
                
                // Enable current digit only
                seg_enable <= ~(8'b1 << seg_scan_counter);
                
                // Output segment data for current digit
                for (b = 0; b < 8; b = b + 1)
                    seg_display[b] <= seg_data[b];
            end
        end
    end
    
    //========================================================================
    // CPU Interface
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_data_reg <= 16'd0;
            led_pwm_duty <= 8'd255;  // Full brightness
            button_irq_mask <= 5'b00000;
            for (b = 0; b < 8; b = b + 1)
                seg_data[b] <= 8'd0;
        end else begin
            if (cpu_we) begin
                case (cpu_addr[3:0])
                    REG_LED_DATA:    led_data_reg <= cpu_wdata[15:0];
                    REG_LED_PWM:     led_pwm_duty <= cpu_wdata[7:0];
                    REG_BUTTON_MASK: button_irq_mask <= cpu_wdata[4:0];
                    REG_SEG_DATA_0:  begin
                        seg_data[0] <= digit_to_seg(cpu_wdata[3:0]);
                        seg_data[1] <= digit_to_seg(cpu_wdata[11:8]);
                    end
                    REG_SEG_DATA_1:  begin
                        seg_data[2] <= digit_to_seg(cpu_wdata[3:0]);
                        seg_data[3] <= digit_to_seg(cpu_wdata[11:8]);
                    end
                    REG_SEG_DATA_2:  begin
                        seg_data[4] <= digit_to_seg(cpu_wdata[3:0]);
                        seg_data[5] <= digit_to_seg(cpu_wdata[11:8]);
                    end
                    REG_SEG_DATA_3:  begin
                        seg_data[6] <= digit_to_seg(cpu_wdata[3:0]);
                        seg_data[7] <= digit_to_seg(cpu_wdata[11:8]);
                    end
                    REG_SEG_CTRL:    begin
                        // Direct segment data write
                        for (b = 0; b < 8; b = b + 1)
                            if (cpu_wdata[b])
                                seg_data[b] <= cpu_wdata[15:8];
                    end
                endcase
            end
        end
    end
    
    // Read data mux
    always @(*) begin
        case (cpu_addr[3:0])
            REG_LED_DATA:    cpu_rdata = {16'd0, led_data_reg};
            REG_LED_PWM:     cpu_rdata = {24'd0, led_pwm_duty};
            REG_SWITCH_DATA: cpu_rdata = {16'd0, switches};
            REG_BUTTON_DATA: cpu_rdata = {27'd0, button_debounced};
            REG_BUTTON_EDGE: cpu_rdata = {27'd0, button_edge};
            REG_BUTTON_MASK: cpu_rdata = {27'd0, button_irq_mask};
            default:         cpu_rdata = 32'd0;
        endcase
    end
    
    // Interrupt generation (button press)
    assign irq_buttons = |(button_edge & button_irq_mask);

endmodule
