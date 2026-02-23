//============================================================================
// Bus Multiplexer - Connects selected slave to master
//============================================================================
`include "defines.vh"

module bus_mux #(
    parameter SLAVE_COUNT = 4,
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32
)(
    // Slave select from decoder
    input  wire [SLAVE_COUNT-1:0]  slave_sel,
    
    // Slave interfaces (from slaves)
    input  wire [DATA_WIDTH-1:0]   s_rdata [0:SLAVE_COUNT-1],
    input  wire [SLAVE_COUNT-1:0]  s_ack,
    input  wire [SLAVE_COUNT-1:0]  s_err,
    
    // Master interface (to master)
    output reg  [DATA_WIDTH-1:0]   m_rdata,
    output reg                     m_ack,
    output reg                     m_err,
    
    // Broadcast to all slaves
    input  wire                    master_req,
    output wire [SLAVE_COUNT-1:0]  slave_req
);

    assign slave_req = master_req ? slave_sel : {SLAVE_COUNT{1'b0}};
    
    integer i;
    
    always @(*) begin
        m_rdata = {DATA_WIDTH{1'b0}};
        m_ack = 1'b0;
        m_err = 1'b0;
        
        for (i = 0; i < SLAVE_COUNT; i = i + 1) begin
            if (slave_sel[i]) begin
                m_rdata = s_rdata[i];
                m_ack = s_ack[i];
                m_err = s_err[i];
            end
        end
    end

endmodule
