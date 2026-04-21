//============================================================================
// Bus Arbiter - Round-robin arbitration for multiple bus masters
//============================================================================
`include "defines.vh"

module bus_arbiter #(
    parameter NUM_MASTERS = 2
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Master request/grant signals
    input  wire [NUM_MASTERS-1:0] req,
    output reg  [NUM_MASTERS-1:0] grant,

    // Arbitration control
    output wire                  bus_busy
);

    reg [$clog2(NUM_MASTERS)-1:0] current_master;
    reg [$clog2(NUM_MASTERS)-1:0] next_master;

    assign bus_busy = |req;

    // Round-robin arbitration
    always @(*) begin
        next_master = current_master;
        if (req[current_master]) begin
            // Current master still requesting
            next_master = current_master;
        end else begin
            // Find next requesting master
            integer i;
            for (i = 1; i < NUM_MASTERS; i = i + 1) begin
                if (req[(current_master + i) % NUM_MASTERS]) begin
                    next_master = (current_master + i) % NUM_MASTERS;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_master <= 0;
            grant          <= 0;
        end else begin
            current_master <= next_master;
            grant          <= 0;
            grant[next_master] <= req[next_master];
        end
    end

endmodule
