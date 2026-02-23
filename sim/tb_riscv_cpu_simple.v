//============================================================================
// Simple RISC-V CPU Testbench - Tests basic operations
//============================================================================
`include "../src/defines.vh"
`timescale 1ns/1ps

module tb_riscv_cpu_simple;

    reg clk;
    reg rst_n;
    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];
    
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire        dmem_re;
    
    integer i;
    integer pass_count;
    integer fail_count;
    
    // Clock
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    // Reset
    initial begin
        rst_n = 0;
        #40 rst_n = 1;
    end
    
    // Memories
    assign imem_data = imem[imem_addr[11:2]];
    assign dmem_rdata = dmem[dmem_addr[11:2]];
    always @(posedge clk) begin
        if (dmem_we) dmem[dmem_addr[11:2]] <= dmem_wdata;
    end
    
    // DUT
    riscv_cpu_top u_cpu (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata), .dmem_we(dmem_we), .dmem_re(dmem_re)
    );
    
    // Test Program
    initial begin
        pass_count = 0;
        fail_count = 0;
        
        // Init memories
        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;  // NOP
            dmem[i] = 32'd0;
        end
        
        // Test 1: Basic ALU
        // x1=10, x2=20, x3=x1+x2=30, store to dmem[0]
        imem[0] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[1] = 32'h01400113;  // ADDI x2, x0, 20
        imem[2] = 32'h002081b3;  // ADD  x3, x1, x2
        imem[3] = 32'h00302023;  // SW   x3, 0(x0)  ; dmem[0] = 30
        
        // Test 2: Multiply (RV32M)
        // x4=7, x4=x3*x4=210, store to dmem[1]
        imem[4] = 32'h00700213;  // ADDI x4, x0, 7
        // MUL x4, x3, x4: funct7=0000001, rs2=x4, rs1=x3, funct3=000, rd=x4
        // Binary: 0000001_00100_00011_000_00100_0110011 = 0x02418233
        imem[5] = 32'h02418233;  // MUL  x4, x3, x4 (30*7=210)
        imem[6] = 32'h00402223;  // SW   x4, 4(x0)  ; dmem[1] = 210
        
        // Test 3: Branch
        // BEQ x1, x1, taken -> x5=42, store to dmem[2]
        imem[7]  = 32'h00108663;  // BEQ  x1, x1, 12 (branch to imem[10])
        imem[8]  = 32'h00000293;  // ADDI x5, x0, 0  (skipped)
        imem[9]  = 32'h02a00293;  // ADDI x5, x0, 42 (target, x5=42)
        imem[10] = 32'h00502423;  // SW   x5, 8(x0)  ; dmem[2] = 42
        
        // Test 4: Load-Use
        // Load from dmem[0], add, store to dmem[3]
        imem[11] = 32'h00002303;  // LW   x6, 0(x0)  (load 30)
        // ADDI x6, x6, 10: imm=10, rs1=x6, funct3=000, rd=x6, opcode=0010011
        // Binary: 000000001010_00110_000_00110_0010011 = 0x00a30313
        imem[12] = 32'h00a30313;  // ADDI x6, x6, 10 (30+10=40)
        imem[13] = 32'h00602623;  // SW   x6, 12(x0) ; dmem[3] = 40
        
        // Infinite loop
        imem[14] = 32'h0000006f;  // J    0
        
        $display("========================================");
        $display("  RISC-V CPU Simple Test");
        $display("========================================");
        
        // Wait for execution
        #800;
        
        // Check results
        $display("\n--- Results ---");
        
        // Check Test 1: dmem[0] should be 30
        if (dmem[0] === 32'd30) begin
            $display("[PASS] Test 1: ADD 10+20=30");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 1: ADD - Got %0d, Expected 30", dmem[0]);
            fail_count = fail_count + 1;
        end
        
        // Check Test 2: dmem[1] should be 210
        if (dmem[1] === 32'd210) begin
            $display("[PASS] Test 2: MUL 30*7=210");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 2: MUL - Got %0d, Expected 210", dmem[1]);
            fail_count = fail_count + 1;
        end
        
        // Check Test 3: dmem[2] should be 42
        if (dmem[2] === 32'd42) begin
            $display("[PASS] Test 3: BEQ branch taken");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 3: BEQ - Got %0d, Expected 42", dmem[2]);
            fail_count = fail_count + 1;
        end
        
        // Check Test 4: dmem[3] should be 40
        if (dmem[3] === 32'd40) begin
            $display("[PASS] Test 4: Load-Use hazard");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 4: LW-ADD - Got %0d, Expected 40", dmem[3]);
            fail_count = fail_count + 1;
        end
        
        // Summary
        $display("\n========================================");
        $display("  Total: %0d, Passed: %0d, Failed: %0d", 
                 pass_count + fail_count, pass_count, fail_count);
        if (fail_count == 0)
            $display("  STATUS: ALL TESTS PASSED!");
        else
            $display("  STATUS: %0d TESTS FAILED", fail_count);
        $display("========================================");
        
        $finish;
    end
    
    // Timeout
    initial begin
        #2000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
