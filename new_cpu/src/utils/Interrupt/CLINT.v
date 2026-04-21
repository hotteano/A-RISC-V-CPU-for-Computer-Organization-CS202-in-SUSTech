//============================================================================
// CLINT - Core Local Interruptor (Timer + Software interrupts)
//============================================================================
`include "defines.vh"

module clint (
    input  wire        clk,
    input  wire        rst_n,

    // Bus interface
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        we,
    input  wire        re,
    output wire        ready,

    // Timer outputs
    output reg  [63:0] mtime,
    output reg  [63:0] mtimecmp,

    // Interrupt outputs
    output reg         mtip,    // Machine timer interrupt pending
    output reg         msip     // Machine software interrupt pending
);

    // CLINT memory map offsets
    localparam OFF_MSIP      = 16'h0000;  // MSIP (per hart)
    localparam OFF_MTIMECMP  = 16'h4000;  // MTIMECMP (per hart)
    localparam OFF_MTIME     = 16'hBFF8;  // MTIME (shared)

    assign ready = 1'b1;

    // Timer interrupt logic
    always @(*) begin
        mtip = (mtime >= mtimecmp);
    end

    // Register access
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime    <= 64'd0;
            mtimecmp <= 64'hFFFFFFFFFFFFFFFF;
            msip     <= 1'b0;
            rdata    <= 32'd0;
        end else begin
            // Increment timer
            mtime <= mtime + 1;

            if (we) begin
                case (addr[15:0])
                    OFF_MSIP:     msip <= wdata[0];
                    OFF_MTIMECMP: mtimecmp[31:0]  <= wdata;
                    OFF_MTIMECMP + 4: mtimecmp[63:32] <= wdata;
                    OFF_MTIME:    mtime[31:0]    <= wdata;
                    OFF_MTIME + 4:  mtime[63:32]   <= wdata;
                endcase
            end

            if (re) begin
                case (addr[15:0])
                    OFF_MSIP:     rdata <= {31'd0, msip};
                    OFF_MTIMECMP: rdata <= mtimecmp[31:0];
                    OFF_MTIMECMP + 4: rdata <= mtimecmp[63:32];
                    OFF_MTIME:    rdata <= mtime[31:0];
                    OFF_MTIME + 4:  rdata <= mtime[63:32];
                    default:      rdata <= 32'd0;
                endcase
            end
        end
    end

endmodule
