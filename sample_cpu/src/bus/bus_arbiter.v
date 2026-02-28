//============================================================================
// Bus Arbiter - Simple Round-Robin Arbitration
// Supports: CPU (master 0), DMA (master 1)
//============================================================================
`include "defines.vh"

module bus_arbiter #(
    parameter MASTER_COUNT = 2,
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Master interfaces (from masters)
    input  wire [MASTER_COUNT-1:0] m_req,
    input  wire [MASTER_COUNT-1:0] m_we,
    input  wire [ADDR_WIDTH-1:0]   m_addr [0:MASTER_COUNT-1],
    input  wire [DATA_WIDTH-1:0]   m_wdata [0:MASTER_COUNT-1],
    input  wire [3:0]              m_be [0:MASTER_COUNT-1],  // Byte enable
    output reg  [DATA_WIDTH-1:0]   m_rdata [0:MASTER_COUNT-1],
    output reg  [MASTER_COUNT-1:0] m_ack,
    output reg  [MASTER_COUNT-1:0] m_err,
    
    // Slave interface (to slaves via decoder)
    output reg                     s_req,
    output reg                     s_we,
    output reg  [ADDR_WIDTH-1:0]   s_addr,
    output reg  [DATA_WIDTH-1:0]   s_wdata,
    output reg  [3:0]              s_be,
    input  wire [DATA_WIDTH-1:0]   s_rdata,
    input  wire                    s_ack,
    input  wire                    s_err
);

    // Arbiter state
    reg [$clog2(MASTER_COUNT)-1:0] current_master;
    reg [$clog2(MASTER_COUNT)-1:0] next_master;
    reg                            busy;
    
    integer i;
    
    // Round-robin arbitration
    always @(*) begin
        next_master = current_master;
        
        // Find next requesting master
        for (i = 1; i <= MASTER_COUNT; i = i + 1) begin
            if (m_req[(current_master + i) % MASTER_COUNT]) begin
                next_master = (current_master + i) % MASTER_COUNT;
            end
        end
    end
    
    // Arbiter FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_master <= {$clog2(MASTER_COUNT){1'b0}};
            busy <= 1'b0;
            m_ack <= {MASTER_COUNT{1'b0}};
            m_err <= {MASTER_COUNT{1'b0}};
        end else begin
            // Clear ack/err
            m_ack <= {MASTER_COUNT{1'b0}};
            m_err <= {MASTER_COUNT{1'b0}};
            
            if (!busy) begin
                // New transaction
                if (m_req[next_master]) begin
                    current_master <= next_master;
                    busy <= 1'b1;
                end
            end else begin
                // Wait for slave response
                if (s_ack || s_err) begin
                    m_ack[current_master] <= s_ack;
                    m_err[current_master] <= s_err;
                    m_rdata[current_master] <= s_rdata;
                    busy <= 1'b0;
                    
                    // Move to next master
                    current_master <= next_master;
                end
            end
        end
    end
    
    // Connect selected master to slave
    always @(*) begin
        if (busy) begin
            s_req   = 1'b1;
            s_we    = m_we[current_master];
            s_addr  = m_addr[current_master];
            s_wdata = m_wdata[current_master];
            s_be    = m_be[current_master];
        end else if (m_req[next_master]) begin
            s_req   = 1'b1;
            s_we    = m_we[next_master];
            s_addr  = m_addr[next_master];
            s_wdata = m_wdata[next_master];
            s_be    = m_be[next_master];
        end else begin
            s_req   = 1'b0;
            s_we    = 1'b0;
            s_addr  = {ADDR_WIDTH{1'b0}};
            s_wdata = {DATA_WIDTH{1'b0}};
            s_be    = 4'b0000;
        end
    end

endmodule
