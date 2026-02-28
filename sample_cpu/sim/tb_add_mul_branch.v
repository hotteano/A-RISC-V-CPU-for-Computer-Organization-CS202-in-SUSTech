//============================================================================
// ADD + MUL + Branch Test (no load)
//============================================================================
`include "../src/defines.vh"
`timescale 1ns/1ps

module tb_add_mul_branch;
    reg clk, rst_n;
    reg [31:0] imem [0:15];
    reg [31:0] dmem [0:15];
    wire [31:0] imem_addr, imem_data;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire dmem_we, dmem_re;
    integer i;
    
    assign imem_data = imem[imem_addr[11:2]];
    assign dmem_rdata = dmem[dmem_addr[11:2]];
    always @(posedge clk) if (dmem_we) dmem[dmem_addr[11:2]] <= dmem_wdata;
    
    initial begin clk = 0; forever #10 clk = ~clk; end
    initial begin rst_n = 0; #40 rst_n = 1; end
    
    riscv_cpu_top u_cpu (.clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata), .dmem_we(dmem_we), .dmem_re(dmem_re));
    
    initial begin
        for (i = 0; i < 16; i = i + 1) begin imem[i] = 32'h00000013; dmem[i] = 32'd0; end
        
        // Test 1: ADD
        imem[0] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[1] = 32'h01400113;  // ADDI x2, x0, 20
        imem[2] = 32'h002081b3;  // ADD  x3, x1, x2
        imem[3] = 32'h00302023;  // SW   x3, 0(x0)
        
        // Test 2: MUL
        imem[4] = 32'h00700213;  // ADDI x4, x0, 7
        imem[5] = 32'h02418233;  // MUL  x4, x3, x4
        imem[6] = 32'h00402223;  // SW   x4, 4(x0)
        
        // Test 3: Branch (BEQ)
        imem[7] = 32'h00108663;  // BEQ  x1, x1, 12 (branch to imem[10])
        imem[8] = 32'h00000293;  // ADDI x5, x0, 0  (skipped)
        imem[9] = 32'h02a00293;  // ADDI x5, x0, 42
        imem[10] = 32'h00502423; // SW   x5, 8(x0)
        
        imem[11] = 32'h0000006f; // J    0
        
        #800;
        
        $display("ADD=%d, MUL=%d, BEQ=%d", dmem[0], dmem[1], dmem[2]);
        if (dmem[0] === 32'd30 && dmem[1] === 32'd210 && dmem[2] === 32'd42)
            $display("[PASS] All tests");
        else
            $display("[FAIL] Expected: 30, 210, 42");
        $finish;
    end
endmodule
