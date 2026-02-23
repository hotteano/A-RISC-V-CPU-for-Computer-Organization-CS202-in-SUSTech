//============================================================================
// Full System Test for RISC-V CPU
// Tests all major functionality in a continuous program flow
//============================================================================
`include "../src/defines.vh"
`timescale 1ns/1ps

module tb_riscv_cpu_full_system;

    reg clk;
    reg rst_n;
    reg [31:0] imem [0:4095];
    reg [31:0] dmem [0:4095];
    
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
    integer total_tests;
    integer expected_val;
    
    // Memory access
    assign imem_data = imem[imem_addr[13:2]];
    assign dmem_rdata = dmem[dmem_addr[13:2]];
    always @(posedge clk) begin
        if (dmem_we) dmem[dmem_addr[13:2]] <= dmem_wdata;
    end
    
    // Clock
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    // Reset
    initial begin
        rst_n = 0;
        #60 rst_n = 1;
    end
    
    // DUT
    riscv_cpu_top u_cpu (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata), .dmem_we(dmem_we), .dmem_re(dmem_re)
    );
    
    // Check result task
    task check_result;
        input [31:0] mem_addr;
        input [31:0] expected;
        input [255*8:1] test_name;
        reg [31:0] actual;
        begin
            actual = dmem[mem_addr];
            total_tests = total_tests + 1;
            if (actual === expected) begin
                $display("  [PASS] %s: addr=%0d, val=%0d", test_name, mem_addr, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %s: addr=%0d, got=%0d(0x%h), exp=%0d(0x%h)", 
                    test_name, mem_addr, actual, actual, expected, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    //========================================================================
    // Main Test
    //========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        total_tests = 0;
        
        // Initialize memories
        for (i = 0; i < 4096; i = i + 1) begin
            imem[i] = 32'h00000013;  // NOP
            dmem[i] = 32'd0;
        end
        
        // Prepare test data
        dmem[1000] = 32'h12345678;
        dmem[1001] = 32'h000000FF;
        dmem[1002] = 32'hFFFFFF80;  // For signed byte test
        
        $display("================================================================");
        $display("         RISC-V CPU Full System Test Suite");
        $display("================================================================");
        $display("");
        
        //================================================================
        // Continuous Test Program
        //================================================================
        
        i = 0;  // Program counter index
        
        //--------------------------------------------------
        // Test 1: Basic ALU - ADD/SUB
        //--------------------------------------------------
        $display("[Test 1] ADD and SUB operations");
        imem[i++] = 32'h00a00093;  // ADDI x1, x0, 10      (x1 = 10)
        imem[i++] = 32'h01400113;  // ADDI x2, x0, 20      (x2 = 20)
        imem[i++] = 32'h002081b3;  // ADD  x3, x1, x2      (x3 = 30)
        imem[i++] = 32'h00302023;  // SW   x3, 0(x0)       // Store to dmem[0]
        imem[i++] = 32'h402081b3;  // SUB  x3, x1, x2      (x3 = -10)
        imem[i++] = 32'h00302223;  // SW   x3, 4(x0)       // Store to dmem[1]
        
        //--------------------------------------------------
        // Test 2: Logical operations
        //--------------------------------------------------
        $display("[Test 2] Logical operations");
        imem[i++] = 32'h0ff00093;  // ADDI x1, x0, 255     (x1 = 0xFF)
        imem[i++] = 32'h0f000113;  // ADDI x2, x0, 240     (x2 = 0xF0)
        imem[i++] = 32'h0020f1b3;  // AND  x3, x1, x2      (x3 = 0xF0)
        imem[i++] = 32'h00302423;  // SW   x3, 8(x0)       // dmem[2]
        imem[i++] = 32'h0020e1b3;  // OR   x3, x1, x2      (x3 = 0xFF)
        imem[i++] = 32'h00302623;  // SW   x3, 12(x0)      // dmem[3]
        imem[i++] = 32'h0020c1b3;  // XOR  x3, x1, x2      (x3 = 0x0F)
        imem[i++] = 32'h00302823;  // SW   x3, 16(x0)      // dmem[4]
        
        //--------------------------------------------------
        // Test 3: SLT and SLTU
        //--------------------------------------------------
        $display("[Test 3] Set Less Than");
        imem[i++] = 32'hff800093;  // ADDI x1, x0, -8      (x1 = -8)
        imem[i++] = 32'h00a00113;  // ADDI x2, x0, 10      (x2 = 10)
        imem[i++] = 32'h0020a1b3;  // SLT  x3, x1, x2      (x3 = 1)
        imem[i++] = 32'h00302a23;  // SW   x3, 20(x0)      // dmem[5]
        imem[i++] = 32'h0020b1b3;  // SLTU x3, x1, x2      (x3 = 0, 0xFFFFFFF8 > 10 unsigned)
        imem[i++] = 32'h00302c23;  // SW   x3, 24(x0)      // dmem[6]
        
        //--------------------------------------------------
        // Test 4: Shifts
        //--------------------------------------------------
        $display("[Test 4] Shift operations");
        imem[i++] = 32'h00a00093;  // ADDI x1, x0, 10      (x1 = 10)
        imem[i++] = 32'h00109193;  // SLLI x3, x1, 1       (x3 = 20)
        imem[i++] = 32'h00302e23;  // SW   x3, 28(x0)      // dmem[7]
        imem[i++] = 32'h00200113;  // ADDI x2, x0, 2
        imem[i++] = 32'h0020d1b3;  // SRL  x3, x1, x2      (x3 = 2)
        imem[i++] = 32'h00303023;  // SW   x3, 32(x0)      // dmem[8]
        
        //--------------------------------------------------
        // Test 5: RV32M Multiply
        //--------------------------------------------------
        $display("[Test 5] RV32M Multiply");
        imem[i++] = 32'h00700093;  // ADDI x1, x0, 7
        imem[i++] = 32'h00900113;  // ADDI x2, x0, 9
        imem[i++] = 32'h022091b3;  // MUL  x3, x1, x2      (x3 = 63)
        imem[i++] = 32'h00303223;  // SW   x3, 36(x0)      // dmem[9]
        
        //--------------------------------------------------
        // Test 6: RV32M Divide and Remainder
        //--------------------------------------------------
        $display("[Test 6] RV32M Divide and Remainder");
        imem[i++] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[i++] = 32'h00300113;  // ADDI x2, x0, 3
        imem[i++] = 32'h0220d1b3;  // DIV  x3, x1, x2      (x3 = 3)
        imem[i++] = 32'h00303423;  // SW   x3, 40(x0)      // dmem[10]
        imem[i++] = 32'h0220f1b3;  // REM  x3, x1, x2      (x3 = 1)
        imem[i++] = 32'h00303623;  // SW   x3, 44(x0)      // dmem[11]
        
        //--------------------------------------------------
        // Test 7: BEQ (Branch if Equal)
        //--------------------------------------------------
        $display("[Test 7] BEQ Branch");
        imem[i++] = 32'h00500093;  // ADDI x1, x0, 5
        imem[i++] = 32'h00500113;  // ADDI x2, x0, 5
        imem[i++] = 32'h00208663;  // BEQ  x1, x2, 12    (branch to PC+12, taken)
        imem[i++] = 32'h00000293;  // ADDI x5, x0, 0     (skipped)
        imem[i++] = 32'h02a00293;  // ADDI x5, x0, 42    (executed)
        imem[i++] = 32'h00503823;  // SW   x5, 48(x0)    // dmem[12], expect 42
        
        //--------------------------------------------------
        // Test 8: BNE (Branch if Not Equal)
        //--------------------------------------------------
        $display("[Test 8] BNE Branch");
        imem[i++] = 32'h00500093;  // ADDI x1, x0, 5
        imem[i++] = 32'h00a00113;  // ADDI x2, x0, 10
        imem[i++] = 32'h00209663;  // BNE  x1, x2, 12    (branch to PC+12, taken)
        imem[i++] = 32'h00000313;  // ADDI x6, x0, 0     (skipped)
        imem[i++] = 32'h03700313;  // ADDI x6, x0, 55    (executed)
        imem[i++] = 32'h00603a23;  // SW   x6, 52(x0)    // dmem[13], expect 55
        
        //--------------------------------------------------
        // Test 9: JAL (Jump and Link)
        //--------------------------------------------------
        $display("[Test 9] JAL Jump");
        imem[i++] = 32'h0140006f;  // JAL  x0, 20        (jump to PC+20)
        imem[i++] = 32'h00000293;  // ADDI x5, x0, 0     (skipped)
        imem[i++] = 32'h00000293;  // ADDI x5, x0, 0     (skipped)
        imem[i++] = 32'h00000293;  // ADDI x5, x0, 0     (skipped)
        imem[i++] = 32'h00000293;  // ADDI x5, x0, 0     (skipped)
        imem[i++] = 32'h06400293;  // ADDI x5, x0, 100   (target, executed)
        imem[i++] = 32'h00503c23;  // SW   x5, 56(x0)    // dmem[14], expect 100
        
        //--------------------------------------------------
        // Test 10: JALR (Jump and Link Register)
        //--------------------------------------------------
        $display("[Test 10] JALR Jump");
        // Calculate target address (current PC + 16)
        imem[i++] = 32'h01000093;  // ADDI x1, x0, 16
        imem[i++] = 32'h00008113;  // ADDI x2, x1, 0     (x2 = address of target)
        // Note: JALR target = (x2 + 0) & ~1
        imem[i++] = 32'h00010167;  // JALR x2, 0(x2)     (jump to target)
        imem[i++] = 32'h00000313;  // ADDI x6, x0, 0     (skipped)
        imem[i++] = 32'h06e00313;  // ADDI x6, x0, 110   (target, executed)
        imem[i++] = 32'h00603e23;  // SW   x6, 60(x0)    // dmem[15], expect 110
        
        //--------------------------------------------------
        // Test 11: Load-Store Word
        //--------------------------------------------------
        $display("[Test 11] LW and SW");
        // dmem[1000] = 0x12345678
        imem[i++] = 32'h3e802083;  // LW   x1, 1000(x0)  (load 0x12345678)
        imem[i++] = 32'h00104223;  // SW   x1, 64(x0)    // dmem[16], expect 0x12345678
        
        //--------------------------------------------------
        // Test 12: Load Halfword
        //--------------------------------------------------
        $display("[Test 12] LH and LHU");
        // dmem[1000] = 0x12345678
        imem[i++] = 32'h3e801083;  // LH   x1, 1000(x0)  (load 0x5678, sign extend)
        imem[i++] = 32'h00104423;  // SW   x1, 68(x0)    // dmem[17], expect 0x00005678
        imem[i++] = 32'h3e805083;  // LHU  x1, 1000(x0)  (load 0x5678, zero extend)
        imem[i++] = 32'h00104623;  // SW   x1, 72(x0)    // dmem[18], expect 0x00005678
        
        //--------------------------------------------------
        // Test 13: Load-Use Hazard
        //--------------------------------------------------
        $display("[Test 13] Load-Use Hazard");
        // dmem[1001] = 0xFF
        imem[i++] = 32'h3e902103;  // LW   x2, 1001(x0)  (load 255)
        imem[i++] = 32'h00110113;  // ADDI x2, x2, 1     (x2 = 256, should stall 1 cycle)
        imem[i++] = 32'h00204823;  // SW   x2, 76(x0)    // dmem[19], expect 256
        
        //--------------------------------------------------
        // Test 14: Data Forwarding EX-to-EX
        //--------------------------------------------------
        $display("[Test 14] EX-to-EX Forwarding");
        imem[i++] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[i++] = 32'h00108093;  // ADDI x1, x1, 1     (forward from EX/MEM, x1=11)
        imem[i++] = 32'h00104a23;  // SW   x1, 80(x0)    // dmem[20], expect 11
        
        //--------------------------------------------------
        // Test 15: Data Forwarding MEM-to-EX
        //--------------------------------------------------
        $display("[Test 15] MEM-to-EX Forwarding");
        imem[i++] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[i++] = 32'h00000013;  // NOP
        imem[i++] = 32'h00108093;  // ADDI x1, x1, 1     (forward from MEM/WB, x1=11)
        imem[i++] = 32'h00104c23;  // SW   x1, 84(x0)    // dmem[21], expect 11
        
        //--------------------------------------------------
        // Test 16: LUI
        //--------------------------------------------------
        $display("[Test 16] LUI");
        imem[i++] = 32'h123450b7;  // LUI  x1, 0x12345   (x1 = 0x12345000)
        imem[i++] = 32'h00104e23;  // SW   x1, 88(x0)    // dmem[22], expect 0x12345000
        
        //--------------------------------------------------
        // Test 17: AUIPC
        //--------------------------------------------------
        $display("[Test 17] AUIPC");
        imem[i++] = 32'h00001097;  // AUIPC x1, 0x1      (x1 = PC + 0x1000)
        imem[i++] = 32'h00105023;  // SW   x1, 92(x0)    // dmem[23], store result
        
        //--------------------------------------------------
        // Test 18: Complex Forwarding
        //--------------------------------------------------
        $display("[Test 18] Complex Forwarding");
        imem[i++] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[i++] = 32'h01400113;  // ADDI x2, x0, 20
        imem[i++] = 32'h002081b3;  // ADD  x3, x1, x2    (forward both operands)
        imem[i++] = 32'h00305223;  // SW   x3, 96(x0)    // dmem[24], expect 30
        
        //--------------------------------------------------
        // Test 19: BLT (Branch Less Than)
        //--------------------------------------------------
        $display("[Test 19] BLT Branch");
        imem[i++] = 32'hff800093;  // ADDI x1, x0, -8    (x1 = -8)
        imem[i++] = 32'h00a00113;  // ADDI x2, x0, 10    (x2 = 10)
        imem[i++] = 32'h0020c663;  // BLT  x1, x2, 12    (branch if -8 < 10, taken)
        imem[i++] = 32'h00000393;  // ADDI x7, x0, 0     (skipped)
        imem[i++] = 32'h04400393;  // ADDI x7, x0, 68    (executed)
        imem[i++] = 32'h00705423;  // SW   x7, 100(x0)   // dmem[25], expect 68
        
        //--------------------------------------------------
        // Test 20: XOR with immediate
        //--------------------------------------------------
        $display("[Test 20] XORI");
        imem[i++] = 32'h0ff00093;  // ADDI x1, x0, 255   (x1 = 0xFF)
        imem[i++] = 32'h00f0c093;  // XORI x1, x1, 15    (x1 = 0xFF ^ 0x0F = 0xF0)
        imem[i++] = 32'h00105623;  // SW   x1, 104(x0)   // dmem[26], expect 0xF0
        
        // End of test - infinite loop
        imem[i++] = 32'h0000006f;  // J    0
        
        // Wait for completion
        #3000;
        
        // Check all results
        $display("");
        $display("================================================================");
        $display("                    Test Results");
        $display("================================================================");
        
        // Group 1: ALU
        check_result(0,  32'd30,         "ADD: 10 + 20");
        check_result(1,  32'hFFFFFFF6,   "SUB: 10 - 20 = -10");
        
        // Group 2: Logical
        check_result(2,  32'hF0,         "AND: 0xFF & 0xF0");
        check_result(3,  32'hFF,         "OR: 0xFF | 0xF0");
        check_result(4,  32'h0F,         "XOR: 0xFF ^ 0xF0");
        
        // Group 3: SLT
        check_result(5,  32'd1,          "SLT: -8 < 10 (signed)");
        check_result(6,  32'd0,          "SLTU: 0xFFFFFFF8 > 10 (unsigned)");
        
        // Group 4: Shifts
        check_result(7,  32'd20,         "SLLI: 10 << 1");
        check_result(8,  32'd2,          "SRL: 10 >> 2");
        
        // Group 5-6: RV32M
        check_result(9,  32'd63,         "MUL: 7 * 9");
        check_result(10, 32'd3,          "DIV: 10 / 3");
        check_result(11, 32'd1,          "REM: 10 % 3");
        
        // Group 7-8: Branch
        check_result(12, 32'd42,         "BEQ: branch taken when equal");
        check_result(13, 32'd55,         "BNE: branch taken when not equal");
        
        // Group 9-10: Jump
        check_result(14, 32'd100,        "JAL: jump and link");
        check_result(15, 32'd110,        "JALR: jump and link register");
        
        // Group 11-12: Load
        check_result(16, 32'h12345678,   "LW: load word");
        check_result(17, 32'h00005678,   "LH: load halfword with sign extend");
        check_result(18, 32'h00005678,   "LHU: load unsigned halfword");
        
        // Group 13: Load-Use
        check_result(19, 32'd256,        "Load-Use hazard: LW + ADDI");
        
        // Group 14-15: Forwarding
        check_result(20, 32'd11,         "EX-to-EX forwarding");
        check_result(21, 32'd11,         "MEM-to-EX forwarding");
        
        // Group 16-17: LUI/AUIPC
        check_result(22, 32'h12345000,   "LUI: load upper immediate");
        // AUIPC result depends on PC, just verify it's not 0
        expected_val = dmem[23];
        total_tests = total_tests + 1;
        if (expected_val !== 32'd0) begin
            $display("  [PASS] AUIPC: result = 0x%h (non-zero)", expected_val);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] AUIPC: result is zero");
            fail_count = fail_count + 1;
        end
        
        // Group 18: Complex forwarding
        check_result(24, 32'd30,         "Complex forwarding: ADD with both operands");
        
        // Group 19: BLT
        check_result(25, 32'd68,         "BLT: branch less than signed");
        
        // Group 20: XORI
        check_result(26, 32'hF0,         "XORI: 0xFF ^ 0x0F");
        
        //================================================================
        // Final Summary
        //================================================================
        $display("");
        $display("================================================================");
        $display("                    Final Summary");
        $display("================================================================");
        $display("  Total Tests:  %0d", total_tests);
        $display("  Passed:       %0d", pass_count);
        $display("  Failed:       %0d", fail_count);
        if (total_tests > 0)
            $display("  Pass Rate:    %0d%%", (pass_count * 100) / total_tests);
        $display("");
        if (fail_count == 0) begin
            $display("  STATUS: ALL TESTS PASSED! ✅");
        end else begin
            $display("  STATUS: %0d TEST(S) FAILED ❌", fail_count);
        end
        $display("================================================================");
        
        $finish;
    end

endmodule
