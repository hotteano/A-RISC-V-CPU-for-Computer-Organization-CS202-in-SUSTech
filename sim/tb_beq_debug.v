//============================================================================
// BEQ Debug Testbench
//============================================================================
`include "../src/defines.vh"
`timescale 1ns/1ps

module tb_beq_debug;

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
    
    // Debug signals
    wire [31:0] if_id_instr = u_cpu.if_id_instr;
    wire [4:0]  id_ex_rd = u_cpu.id_ex_rd_addr;
    wire [31:0] x1_val = u_cpu.u_regfile.registers[1];
    wire [31:0] x5_val = u_cpu.u_regfile.registers[5];
    
    // Test Program
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;
            dmem[i] = 32'd0;
        end
        
        // BEQ test - BEQ offset is 16 bytes (4 instructions)
        imem[0] = 32'h00a00093;  // ADDI x1, x0, 10
        imem[1] = 32'h00108663;  // BEQ  x1, x1, 16 (branch to imem[5])
        imem[2] = 32'h00000293;  // ADDI x5, x0, 0  (skipped)
        imem[3] = 32'h00000293;  // ADDI x5, x0, 0  (skipped)
        imem[4] = 32'h00000293;  // ADDI x5, x0, 0  (skipped)
        imem[5] = 32'h02a00293;  // ADDI x5, x0, 42 (target - executes if branch taken)
        imem[6] = 32'h00502423;  // SW   x5, 8(x0)
        imem[7] = 32'h00000013;  // NOP
        
        $display("BEQ Debug Test");
        $display("Expected: x1=10, branch taken, x5=42, dmem[2]=42");
        
        repeat(20) begin
            @(posedge clk);
            #1;
            $display("T=%0t PC=%h IFID=%h x1=%h x5=%h dmem[2]=%h", 
                $time, imem_addr, if_id_instr, x1_val, x5_val, dmem[2]);
        end
        
        $display("\n--- Result ---");
        $display("x1 = %0d (expected 10)", x1_val);
        $display("x5 = %0d (expected 42)", x5_val);
        $display("dmem[2] = %0d (expected 42)", dmem[2]);
        
        if (dmem[2] == 42)
            $display("[PASS] BEQ test");
        else
            $display("[FAIL] BEQ test - Got %0d, Expected 42", dmem[2]);
        
        $finish;
    end

endmodule
