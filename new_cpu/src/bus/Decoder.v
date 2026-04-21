//============================================================================
// Bus Address Decoder - Routes transactions to appropriate slave
//============================================================================
`include "defines.vh"

module bus_decoder (
    input  wire [31:0] addr,

    // Slave select outputs
    output reg         sel_mem,       // Memory (0x0000_0000)
    output reg         sel_io,        // IO space (0x1000_0000)
    output reg         sel_clint,     // CLINT (0x0200_0000)
    output reg         sel_plic,      // PLIC (0x0C00_0000)

    // Address offset to slave
    output wire [31:0] slave_addr
);

    assign slave_addr = addr;

    always @(*) begin
        sel_mem   = 1'b0;
        sel_io    = 1'b0;
        sel_clint = 1'b0;
        sel_plic  = 1'b0;

        if (addr >= `MEM_BASE_ADDR && addr < `MEM_BASE_ADDR + `MEM_SIZE)
            sel_mem = 1'b1;
        else if (addr >= `IO_BASE_ADDR && addr < `IO_BASE_ADDR + `IO_SIZE)
            sel_io = 1'b1;
        else if (addr >= `CLINT_BASE_ADDR && addr < `CLINT_BASE_ADDR + `CLINT_SIZE)
            sel_clint = 1'b1;
        else if (addr >= `PLIC_BASE_ADDR && addr < `PLIC_BASE_ADDR + `PLIC_SIZE)
            sel_plic = 1'b1;
    end

endmodule
