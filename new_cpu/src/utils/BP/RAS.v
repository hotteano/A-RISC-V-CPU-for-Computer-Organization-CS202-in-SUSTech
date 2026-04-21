//============================================================================
// RAS - Return Address Stack
//============================================================================
`include "defines.vh"

module return_address_stack (
    input  wire        clk,
    input  wire        rst_n,

    // Call/return detection
    input  wire        call,       // JAL/JALR to register other than x1/x5
    input  wire        ret,        // JALR to x1/x5 (return)
    input  wire [31:0] call_pc,    // PC of call instruction
    input  wire [31:0] return_addr, // Return address (PC+4)

    // Prediction output
    output reg  [31:0] ras_top,
    output reg         valid
);

    localparam RAS_DEPTH = 8;
    localparam RAS_PTR_W = $clog2(RAS_DEPTH);

    reg [31:0] stack [0:RAS_DEPTH-1];
    reg [RAS_PTR_W:0] sp;  // Stack pointer (extra bit for full/empty)

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sp    <= {RAS_PTR_W+1{1'b0}};
            valid <= 1'b0;
            for (i = 0; i < RAS_DEPTH; i = i + 1)
                stack[i] <= 32'd0;
        end else begin
            valid <= 1'b0;
            if (call) begin
                // Push
                stack[sp[RAS_PTR_W-1:0]] <= return_addr;
                sp <= sp + 1;
            end else if (ret && sp != 0) begin
                // Pop
                sp    <= sp - 1;
                valid <= 1'b1;
            end
        end
    end

    always @(*) begin
        if (sp != 0)
            ras_top = stack[(sp - 1)[RAS_PTR_W-1:0]];
        else
            ras_top = 32'd0;
    end

endmodule
