//============================================================================
// ALU Testbench - Verify all operations including RV32M
//============================================================================
`include "../src/defines.vh"
`timescale 1ns/1ps

module tb_alu;

    reg  [31:0] a, b;
    reg  [5:0]  alu_op;
    wire [31:0] result;
    
    integer pass_count, fail_count, test_num;
    
    // ALU opcodes
    localparam ALU_ADD = 6'b000000;
    localparam ALU_SUB = 6'b000001;
    localparam ALU_MUL = 6'b100000;
    localparam ALU_DIV = 6'b100100;
    localparam ALU_REM = 6'b100110;
    
    ALU u_alu (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result)
    );
    
    task check;
        input [31:0] expected;
        input [0:8*40-1] desc;
        begin
            if (result === expected) begin
                $display("[PASS] Test %0d: %s = %0d", test_num, desc, result);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s - Got %0d, Expected %0d", 
                    test_num, desc, result, expected);
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask
    
    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num = 0;
        
        $display("========================================");
        $display("  ALU Unit Test");
        $display("========================================");
        
        // Test ADD
        alu_op = ALU_ADD;
        a = 32'd10; b = 32'd20; #1;
        check(32'd30, "ADD 10+20");
        
        // Test SUB
        alu_op = ALU_SUB;
        a = 32'd50; b = 32'd20; #1;
        check(32'd30, "SUB 50-20");
        
        // Test MUL - 30 * 7 = 210
        alu_op = ALU_MUL;
        a = 32'd30; b = 32'd7; #1;
        check(32'd210, "MUL 30*7");
        
        // Test MUL - 10 * 12 = 120
        a = 32'd10; b = 32'd12; #1;
        check(32'd120, "MUL 10*12");
        
        // Test MUL - 0x10 * 0x10 = 256
        a = 32'h10; b = 32'h10; #1;
        check(32'h100, "MUL 0x10*0x10");
        
        // Test DIV - 120 / 10 = 12
        alu_op = ALU_DIV;
        a = 32'd120; b = 32'd10; #1;
        check(32'd12, "DIV 120/10");
        
        // Test DIV by zero - should return -1 (0xFFFFFFFF)
        a = 32'd100; b = 32'd0; #1;
        check(32'hFFFFFFFF, "DIV by 0");
        
        // Test REM - 120 % 10 = 0
        alu_op = ALU_REM;
        a = 32'd120; b = 32'd10; #1;
        check(32'd0, "REM 120%10");
        
        // Summary
        $display("\n========================================");
        $display("  Total: %0d, Passed: %0d, Failed: %0d", 
                 test_num, pass_count, fail_count);
        if (fail_count == 0)
            $display("  STATUS: ALL TESTS PASSED!");
        else
            $display("  STATUS: %0d TESTS FAILED", fail_count);
        $display("========================================");
        
        $finish;
    end

endmodule
