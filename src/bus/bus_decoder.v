//============================================================================
// Bus Address Decoder
// Maps address ranges to slave select signals
// Memory Map:
//   0x0000_0000 - 0x0FFF_FFFF : Memory (Instruction/Data BRAM)
//   0x1000_0000 - 0x1FFF_FFFF : IO Peripherals
//   0x2000_0000 - 0x2FFF_FFFF : VGA Framebuffer
//   0x3000_0000 - 0x3FFF_FFFF : DMA
//============================================================================
`include "defines.vh"

module bus_decoder #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter SLAVE_COUNT = 4
)(
    input  wire [ADDR_WIDTH-1:0]   addr,
    output reg  [SLAVE_COUNT-1:0]  slave_sel,
    
    // Address range configuration
    input  wire [ADDR_WIDTH-1:0]   slave_base [0:SLAVE_COUNT-1],
    input  wire [ADDR_WIDTH-1:0]   slave_mask [0:SLAVE_COUNT-1]
);

    integer i;
    
    always @(*) begin
        slave_sel = {SLAVE_COUNT{1'b0}};
        
        for (i = 0; i < SLAVE_COUNT; i = i + 1) begin
            if ((addr & ~slave_mask[i]) == slave_base[i]) begin
                slave_sel[i] = 1'b1;
            end
        end
    end

endmodule
