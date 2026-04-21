//============================================================================
// AMO - Atomic Memory Operations Unit
//============================================================================
`include "defines.vh"

module amo_unit (
    input  wire        clk,
    input  wire        rst_n,

    // CPU request
    input  wire [5:0]  amo_op,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        req,
    output reg         ready,

    // Memory interface
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    output reg         mem_we,
    output reg         mem_re,
    input  wire        mem_ready,

    // Reservation station interface
    output reg         rs_set,
    output reg         rs_clear,
    input  wire        rs_valid,
    input  wire [31:0] rs_addr
);

    localparam ALU_LR      = 6'b011001;
    localparam ALU_SC      = 6'b011010;
    localparam ALU_AMOSWAP = 6'b011011;
    localparam ALU_AMOADD  = 6'b011100;
    localparam ALU_AMOXOR  = 6'b011101;
    localparam ALU_AMOAND  = 6'b011110;
    localparam ALU_AMOOR   = 6'b101000;
    localparam ALU_AMOMIN  = 6'b101001;
    localparam ALU_AMOMAX  = 6'b101010;
    localparam ALU_AMOMINU = 6'b101011;
    localparam ALU_AMOMAXU = 6'b101100;

    // State machine
    localparam IDLE  = 2'b00;
    localparam READ  = 2'b01;
    localparam WRITE = 2'b10;
    localparam DONE  = 2'b11;

    reg [1:0] state;
    reg [31:0] old_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            rdata      <= 32'd0;
            ready      <= 1'b0;
            mem_addr   <= 32'd0;
            mem_wdata  <= 32'd0;
            mem_we     <= 1'b0;
            mem_re     <= 1'b0;
            rs_set     <= 1'b0;
            rs_clear   <= 1'b0;
            old_data   <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    ready    <= 1'b0;
                    mem_we   <= 1'b0;
                    mem_re   <= 1'b0;
                    rs_set   <= 1'b0;
                    rs_clear <= 1'b0;
                    if (req) begin
                        mem_addr <= addr;
                        if (amo_op == ALU_LR) begin
                            // Load Reserved
                            mem_re <= 1'b1;
                            state  <= READ;
                        end else if (amo_op == ALU_SC) begin
                            // Store Conditional
                            if (rs_valid && rs_addr == addr) begin
                                mem_wdata <= wdata;
                                mem_we    <= 1'b1;
                                state     <= WRITE;
                                rs_clear  <= 1'b1;
                            end else begin
                                rdata <= 32'd1;  // SC failed
                                ready <= 1'b1;
                            end
                        end else begin
                            // AMO operations: read-modify-write
                            mem_re <= 1'b1;
                            state  <= READ;
                        end
                    end
                end
                READ: begin
                    if (mem_ready) begin
                        old_data <= mem_rdata;
                        mem_re   <= 1'b0;
                        if (amo_op == ALU_LR) begin
                            rdata  <= mem_rdata;
                            ready  <= 1'b1;
                            rs_set <= 1'b1;
                            state  <= IDLE;
                        end else begin
                            state <= WRITE;
                        end
                    end
                end
                WRITE: begin
                    mem_we <= 1'b1;
                    case (amo_op)
                        ALU_SC:       mem_wdata <= wdata;
                        ALU_AMOSWAP:  mem_wdata <= wdata;
                        ALU_AMOADD:   mem_wdata <= old_data + wdata;
                        ALU_AMOXOR:   mem_wdata <= old_data ^ wdata;
                        ALU_AMOAND:   mem_wdata <= old_data & wdata;
                        ALU_AMOOR:    mem_wdata <= old_data | wdata;
                        ALU_AMOMIN:   mem_wdata <= ($signed(old_data) < $signed(wdata)) ? old_data : wdata;
                        ALU_AMOMAX:   mem_wdata <= ($signed(old_data) > $signed(wdata)) ? old_data : wdata;
                        ALU_AMOMINU:  mem_wdata <= (old_data < wdata) ? old_data : wdata;
                        ALU_AMOMAXU:  mem_wdata <= (old_data > wdata) ? old_data : wdata;
                        default:      mem_wdata <= wdata;
                    endcase
                    if (mem_ready) begin
                        mem_we <= 1'b0;
                        rdata  <= old_data;
                        ready  <= 1'b1;
                        state  <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
