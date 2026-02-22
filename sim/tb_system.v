//============================================================================
// Testbench for RISC-V CPU with CSR, MMU, and PMP
//============================================================================
`include "defines.vh"
`timescale 1ns/1ps

module tb_system;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Instruction memory (4KB)
    reg [31:0] imem [0:1023];
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    
    // Data memory (4KB)
    reg [31:0] dmem [0:1023];
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire        dmem_re;
    
    // CSR test signals
    reg [31:0] csr_rdata;
    
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
    
    // Memory interfaces
    assign imem_data = imem[imem_addr[11:2]];
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
    
    //========================================================================
    // Test Program with CSR Instructions
    //========================================================================
    initial begin
        // Initialize memories
        integer i;
        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h0000_0000;
            dmem[i] = 32'd0;
        end
        
        //========================================================================
        // Test 1: Basic CSR Operations
        //========================================================================
        $display("=== Test 1: Basic CSR Operations ===");
        
        // Address 0: CSRRWI x1, mscratch, 0x5  (Write 5 to mscratch, read old value to x1)
        imem[0] = 32'h3400_10F3;
        
        // Address 4: CSRRSI x2, mscratch, 0x2  (Set bit 1, read to x2)
        imem[1] = 32'h3401_1173;
        
        // Address 8: CSRR x3, mscratch  (Read mscratch to x3)
        imem[2] = 32'h3400_21F3;
        
        //========================================================================
        // Test 2: Cycle Counter
        //========================================================================
        $display("=== Test 2: Cycle Counter ===");
        
        // Address 12: CSRR x4, mcycle  (Read cycle counter low)
        imem[3] = 32'hB000_22F3;
        
        // Address 16: NOP
        imem[4] = 32'h0000_0013;
        
        // Address 20: NOP
        imem[5] = 32'h0000_0013;
        
        // Address 24: CSRR x5, mcycle  (Read cycle counter again)
        imem[6] = 32'hB000_2333;
        
        //========================================================================
        // Test 3: Arithmetic with CSR
        //========================================================================
        $display("=== Test 3: Arithmetic with CSR ===");
        
        // Address 28: ADDI x6, x0, 100
        imem[7] = 32'h0640_0313;
        
        // Address 32: CSRW mscratch, x6  (Write x6 to mscratch)
        imem[8] = 32'h3403_1073;
        
        // Address 36: CSRR x7, mscratch  (Read back)
        imem[9] = 32'h3400_23B3;
        
        //========================================================================
        // Test 4: Exception Handling (ECALL)
        //========================================================================
        $display("=== Test 4: Exception Handling ===");
        
        // Address 40: CSRRW x0, mtvec, x0  (Set trap vector to 0x100)
        imem[10] = 32'h3050_00F3;
        
        // Address 44: LUI x8, 0x1  (x8 = 0x1000)
        imem[11] = 32'h0000_1437;
        
        // Address 48: SRLI x8, x8, 4  (x8 = 0x100)
        imem[12] = 32'h0044_5493;
        
        // Address 52: CSRW mtvec, x8  (Set mtvec to 0x100)
        imem[13] = 32'h3054_1073;
        
        // Address 56: ECALL  (Environment call - causes exception)
        imem[14] = 32'h0000_0073;
        
        //========================================================================
        // Trap Handler at address 0x100 (word index 64)
        //========================================================================
        
        // Address 0x100: CSRR x9, mcause  (Read exception cause)
        imem[64] = 32'h3420_24F3;
        
        // Address 0x104: CSRR x10, mepc  (Read exception PC)
        imem[65] = 32'h3410_2533;
        
        // Address 0x108: ADDI x11, x0, 1  (x11 = 1 - success flag)
        imem[66] = 32'h0010_0593;
        
        // Address 0x10C: MRET  (Return from trap)
        imem[67] = 32'h3020_0073;
        
        //========================================================================
        // Continue after exception
        //========================================================================
        
        // Address 60: ADDI x12, x0, 42  (x12 = 42)
        imem[15] = 32'h02A0_0633;
        
        // Address 64: SW x12, 0(x0)  (Store to memory)
        imem[16] = 32'h02C0_2023;
        
        // Address 68: LW x13, 0(x0)  (Load from memory)
        imem[17] = 32'h0000_26B3;
        
        // Address 72: Infinite loop
        imem[18] = 32'h0000_006F;
        
        // Run simulation
        $display("\n=== Starting RISC-V CPU System Test ===\n");
        $display("Time\tPC\t\tInstruction\tDescription");
        
        repeat(50) @(posedge clk);
        
        $display("\n=== Test Complete ===");
        $display("Data memory[0] = %d (expected: 42)", dmem[0]);
        $finish;
    end
    
    // Monitor
    always @(posedge clk) begin
        if (rst_n) begin
            $display("%0t\t%h\t%h\t", $time, imem_addr, imem_data);
        end
    end

endmodule
