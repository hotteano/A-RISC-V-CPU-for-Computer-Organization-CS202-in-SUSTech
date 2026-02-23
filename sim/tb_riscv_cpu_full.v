//============================================================================
// Full RISC-V CPU Testbench - Comprehensive test suite
//============================================================================
`include "../src/defines.vh"
`timescale 1ns/1ps

module tb_riscv_cpu_full;

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
            imem[i] = 32'h00000013;
            dmem[i] = 32'd0;
        end
        
        //========================================================================
        // Test Group 1: Basic ALU (dmem[0-7])
        //========================================================================
        // ADD: 10+20=30 -> dmem[0]
        imem[0] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[1] = 32'h01400113;  // ADDI x2, x0, 20
        imem[2] = 32'h002081b3;  // ADD  x3, x1, x2
        imem[3] = 32'h00302023;  // SW   x3, 0(x0)
        
        // SUB: 10-20=-10 -> dmem[1]
        imem[4] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[5] = 32'h01400113;  // ADDI x2, x0, 20
        imem[6] = 32'h402081b3;  // SUB  x3, x1, x2
        imem[7] = 32'h00302223;  // SW   x3, 4(x0)
        
        // AND: 0xFF & 0xF0 = 0xF0 -> dmem[2]
        imem[8]  = 32'h0ff00093;  // ADDI x1, x0, 0xFF
        imem[9]  = 32'h0f000113;  // ADDI x2, x0, 0xF0
        imem[10] = 32'h0020f1b3;  // AND  x3, x1, x2
        imem[11] = 32'h00302423;  // SW   x3, 8(x0)
        
        // OR: 0xFF | 0xF0 = 0xFF -> dmem[3]
        imem[12] = 32'h0020e1b3;  // OR   x3, x1, x2
        imem[13] = 32'h00302623;  // SW   x3, 12(x0)
        
        // XOR: 0xFF ^ 0xF0 = 0x0F -> dmem[4]
        imem[14] = 32'h0020c1b3;  // XOR  x3, x1, x2
        imem[15] = 32'h00302823;  // SW   x3, 16(x0)
        
        // SLT: -8 < 10 = 1 -> dmem[5]
        imem[16] = 32'hff800093;  // ADDI x1, x0, -8
        imem[17] = 32'h00a00113;  // ADDI x2, x0, 10
        imem[18] = 32'h0020a1b3;  // SLT  x3, x1, x2
        imem[19] = 32'h00302a23;  // SW   x3, 20(x0)
        
        // SLLI: 0xFF << 1 = 0x1FE -> dmem[6]
        imem[20] = 32'h0ff00093;  // ADDI x1, x0, 0xFF
        imem[21] = 32'h00109193;  // SLLI x3, x1, 1
        imem[22] = 32'h00302c23;  // SW   x3, 24(x0)
        
        // SRLI: 0xFF >> 1 = 0x7F -> dmem[7]
        imem[23] = 32'h0010d193;  // SRLI x3, x1, 1
        imem[24] = 32'h00302e23;  // SW   x3, 28(x0)
        
        //========================================================================
        // Test Group 2: RV32M Multiply/Divide (dmem[8-10])
        //========================================================================
        // MUL: 10*7=70 -> dmem[8]
        imem[25] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[26] = 32'h00700213;  // ADDI x4, x0, 7
        imem[27] = 32'h024090b3;  // MUL  x1, x1, x4
        imem[28] = 32'h00103023;  // SW   x1, 32(x0)
        
        // DIV: 10/3=3 -> dmem[9]
        imem[29] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[30] = 32'h00300113;  // ADDI x2, x0, 3
        imem[31] = 32'h0220d1b3;  // DIV  x3, x1, x2
        imem[32] = 32'h00303223;  // SW   x3, 36(x0)
        
        // REM: 10%3=1 -> dmem[10]
        imem[33] = 32'h0220f1b3;  // REM  x3, x1, x2
        imem[34] = 32'h00303423;  // SW   x3, 40(x0)
        
        //========================================================================
        // Test Group 3: Load/Store (dmem[11-13])
        //========================================================================
        // Prepare data
        dmem[100] = 32'd100;
        dmem[101] = 32'h12345678;
        
        // LW: load 100 -> dmem[11]
        imem[35] = 32'h06402103;  // LW   x2, 100(x0)
        imem[36] = 32'h00203623;  // SW   x2, 44(x0)
        
        // Load-Use: 100+1=101 -> dmem[12]
        imem[37] = 32'h06402103;  // LW   x2, 100(x0)
        imem[38] = 32'h00110113;  // ADDI x2, x2, 1
        imem[39] = 32'h00203823;  // SW   x2, 48(x0)
        
        // LUI: 0x12345000 -> dmem[13]
        imem[40] = 32'h123450b7;  // LUI  x1, 0x12345
        imem[41] = 32'h00103a23;  // SW   x1, 52(x0)
        
        //========================================================================
        // Test Group 4: Forwarding (dmem[14-15])
        //========================================================================
        // EX-to-EX forwarding: 10+1+1=12 -> dmem[14]
        imem[42] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[43] = 32'h00108093;  // ADDI x1, x1, 1
        imem[44] = 32'h00108093;  // ADDI x1, x1, 1
        imem[45] = 32'h00103c23;  // SW   x1, 56(x0)
        
        //========================================================================
        // Test Group 5: Branch (dmem[16])
        //========================================================================
        // BEQ taken: x5=42 -> dmem[15]
        imem[46] = 32'h00500093;  // ADDI x1, x0, 5
        imem[47] = 32'h00500113;  // ADDI x2, x0, 5
        imem[48] = 32'h00208463;  // BEQ  x1, x2, 8
        imem[49] = 32'h00000293;  // ADDI x5, x0, 0 (skipped)
        imem[50] = 32'h02a00293;  // ADDI x5, x0, 42
        imem[51] = 32'h00503e23;  // SW   x5, 60(x0)
        
        // Halt
        imem[52] = 32'h0000006f;  // J    0
        
        $display("================================================================");
        $display("           RISC-V CPU Full System Test");
        $display("================================================================");
        
        #1500;
        
        $display("\n--- Test Results ---\n");
        
        // Check results
        $display("[ALU Tests]");
        if (dmem[0] === 32'd30) begin $display("  [PASS] ADD: 10+20=30"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] ADD: got %0d, exp 30", dmem[0]); fail_count = fail_count + 1; end
        
        if (dmem[1] === 32'hFFFFFFF6) begin $display("  [PASS] SUB: 10-20=-10"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] SUB: got %0d, exp -10", dmem[1]); fail_count = fail_count + 1; end
        
        if (dmem[2] === 32'hF0) begin $display("  [PASS] AND: 0xFF&0xF0=0xF0"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] AND: got %0h, exp F0", dmem[2]); fail_count = fail_count + 1; end
        
        if (dmem[3] === 32'hFF) begin $display("  [PASS] OR: 0xFF|0xF0=0xFF"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] OR: got %0h, exp FF", dmem[3]); fail_count = fail_count + 1; end
        
        if (dmem[4] === 32'h0F) begin $display("  [PASS] XOR: 0xFF^0xF0=0x0F"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] XOR: got %0h, exp 0F", dmem[4]); fail_count = fail_count + 1; end
        
        if (dmem[5] === 32'd1) begin $display("  [PASS] SLT: -8<10=1"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] SLT: got %0d, exp 1", dmem[5]); fail_count = fail_count + 1; end
        
        if (dmem[6] === 32'h1FE) begin $display("  [PASS] SLLI: 0xFF<<1=0x1FE"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] SLLI: got %0h, exp 1FE", dmem[6]); fail_count = fail_count + 1; end
        
        if (dmem[7] === 32'h7F) begin $display("  [PASS] SRLI: 0xFF>>1=0x7F"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] SRLI: got %0h, exp 7F", dmem[7]); fail_count = fail_count + 1; end
        
        $display("\n[RV32M Tests]");
        if (dmem[8] === 32'd70) begin $display("  [PASS] MUL: 10*7=70"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] MUL: got %0d, exp 70", dmem[8]); fail_count = fail_count + 1; end
        
        if (dmem[9] === 32'd3) begin $display("  [PASS] DIV: 10/3=3"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] DIV: got %0d, exp 3", dmem[9]); fail_count = fail_count + 1; end
        
        if (dmem[10] === 32'd1) begin $display("  [PASS] REM: 10%%3=1"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] REM: got %0d, exp 1", dmem[10]); fail_count = fail_count + 1; end
        
        $display("\n[Memory Tests]");
        if (dmem[11] === 32'd100) begin $display("  [PASS] LW: load 100"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] LW: got %0d, exp 100", dmem[11]); fail_count = fail_count + 1; end
        
        if (dmem[12] === 32'd101) begin $display("  [PASS] Load-Use: 100+1=101"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] Load-Use: got %0d, exp 101", dmem[12]); fail_count = fail_count + 1; end
        
        if (dmem[13] === 32'h12345000) begin $display("  [PASS] LUI: 0x12345000"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] LUI: got %0h, exp 12345000", dmem[13]); fail_count = fail_count + 1; end
        
        $display("\n[Forwarding Test]");
        if (dmem[14] === 32'd12) begin $display("  [PASS] Forwarding: 10+1+1=12"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] Forwarding: got %0d, exp 12", dmem[14]); fail_count = fail_count + 1; end
        
        $display("\n[Branch Test]");
        if (dmem[15] === 32'd42) begin $display("  [PASS] BEQ: branch taken"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] BEQ: got %0d, exp 42", dmem[15]); fail_count = fail_count + 1; end
        
        // Summary
        $display("\n================================================================");
        $display("  Total: %0d, Passed: %0d, Failed: %0d", 
                 pass_count + fail_count, pass_count, fail_count);
        if (fail_count == 0)
            $display("  STATUS: ALL TESTS PASSED! ✅");
        else
            $display("  STATUS: %0d TEST(S) FAILED ❌", fail_count);
        $display("================================================================");
        
        $finish;
    end
    
    // Timeout
    initial begin
        #3000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
