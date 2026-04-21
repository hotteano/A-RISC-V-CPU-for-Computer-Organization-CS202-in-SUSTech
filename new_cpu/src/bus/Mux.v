//============================================================================
// Bus Multiplexer - Selects slave response back to master
//============================================================================
`include "defines.vh"

module bus_mux (
    // Slave select signals (from decoder)
    input  wire        sel_mem,
    input  wire        sel_io,
    input  wire        sel_clint,
    input  wire        sel_plic,

    // Slave read data inputs
    input  wire [31:0] rdata_mem,
    input  wire [31:0] rdata_io,
    input  wire [31:0] rdata_clint,
    input  wire [31:0] rdata_plic,

    // Slave ready signals
    input  wire        ready_mem,
    input  wire        ready_io,
    input  wire        ready_clint,
    input  wire        ready_plic,

    // Master read data output
    output reg  [31:0] rdata,
    output reg         ready
);

    always @(*) begin
        if (sel_mem) begin
            rdata = rdata_mem;
            ready = ready_mem;
        end else if (sel_io) begin
            rdata = rdata_io;
            ready = ready_io;
        end else if (sel_clint) begin
            rdata = rdata_clint;
            ready = ready_clint;
        end else if (sel_plic) begin
            rdata = rdata_plic;
            ready = ready_plic;
        end else begin
            rdata = 32'd0;
            ready = 1'b0;
        end
    end

endmodule
