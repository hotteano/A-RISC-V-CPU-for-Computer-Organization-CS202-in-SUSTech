//============================================================================
// Testbench for RISC-V CPU
//============================================================================
`include "defines.vh"
`timescale 1ns/1ps

module tb_riscv_cpu;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Instruction memory
    reg [31:0] imem [0:1023];
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    
    // Data memory
    reg [31:0] dmem [0:1023];
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire        dmem_re;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Reset generation
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end
    
    // Instruction memory read
    assign imem_data = imem[imem_addr[11:2]];
    
    // Data memory read/write
    assign dmem_rdata = dmem[dmem_addr[11:2]];
    always @(posedge clk) begin
        if (dmem_we)
            dmem[dmem_addr[11:2]] <= dmem_wdata;
    end
    
    // DUT instantiation
    riscv_cpu_top u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_re(dmem_re)
    );
    
    // Test program - Simple test
    integer i;
    
    initial begin
        // Initialize instruction memory with a simple test program
        // Test: x1 = 10, x2 = 20, x3 = x1 + x2
        
        // Address 0: ADDI x1, x0, 10  (x1 = 10)
        imem[0] = 32'h00a00093;
        
        // Address 4: ADDI x2, x0, 20  (x2 = 20)
        imem[1] = 32'h01400113;
        
        // Address 8: ADD x3, x1, x2   (x3 = x1 + x2 = 30)
        imem[2] = 32'h002081b3;
        
        // Address 12: ADDI x4, x0, 5  (x4 = 5)
        imem[3] = 32'h00500213;
        
        // Address 16: SUB x5, x3, x4  (x5 = x3 - x4 = 25)
        imem[4] = 32'h0041c2b3;
        
        // Address 20: SW x5, 0(x0)    (Store x5 to memory address 0)
        imem[5] = 32'h00502023;
        
        // Address 24: LW x6, 0(x0)    (Load from memory address 0 to x6)
        imem[6] = 32'h00002303;
        
        // Address 28: JAL x7, 8       (Jump to address 36, x7 = 32)
        imem[7] = 32'h008003ef;
        
        // Address 32: ADDI x8, x0, 99 (Should be skipped)
        imem[8] = 32'h06300413;
        
        // Address 36: ADDI x9, x0, 42 (x9 = 42)
        imem[9] = 32'h02a00493;
        
        // Address 40: Infinite loop (JAL x0, -4)
        imem[10] = 32'hffdff06f;
        
        // Initialize data memory
        for (i = 0; i < 1024; i = i + 1)
            dmem[i] = 32'd0;
        
        // Run simulation
        $display("Starting RISC-V CPU Simulation...");
        $display("Time\tPC\t\tInstruction");
        
        // Monitor PC
        repeat(20) @(posedge clk);
        
        $display("Simulation completed!");
        $display("Data memory[0] = %d", dmem[0]);
        $finish;
    end
    
    // Monitor
    always @(posedge clk) begin
        if (rst_n)
            $display("%0t\t%h\t%h", $time, imem_addr, imem_data);
    end

endmodule
