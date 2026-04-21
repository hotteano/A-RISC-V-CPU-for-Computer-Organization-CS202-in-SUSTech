//============================================================================
// LED Controller - Simple GPIO for LEDs
//============================================================================
`include "defines.vh"

module led_controller (
    input  wire        clk,
    input  wire        rst_n,

    // CPU bus interface
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        we,
    input  wire        re,
    output wire        ready,

    // LED outputs
    output reg  [7:0]  led
);

    assign ready = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led <= 8'd0;
        end else if (we) begin
            led <= wdata[7:0];
        end
    end

    always @(*) begin
        rdata = {24'd0, led};
    end

endmodule
