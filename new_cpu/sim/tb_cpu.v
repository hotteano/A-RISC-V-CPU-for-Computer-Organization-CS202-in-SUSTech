//============================================================================
// Testbench for RISC-V CPU
//============================================================================
`include "defines.vh"
`timescale 1ns / 1ps

module tb_cpu;

    // Clock and reset
    reg clk;
    reg rst_n;

    // Instruction memory signals
    wire [31:0] imem_addr;
    reg  [31:0] imem_data;
    wire        imem_re;
    reg         imem_ready;

    // Data memory signals
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;
    wire        dmem_we;
    wire        dmem_re;
    reg         dmem_ready;

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 100MHz
    end

    // Reset generation
    initial begin
        rst_n = 1'b0;
        #100 rst_n = 1'b1;
    end

    // DUT instantiation
    riscv_cpu_top u_cpu (
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

    // Instruction memory model
    always @(*) begin
        imem_ready = 1'b1;
        // Simple instruction memory (read combinational)
        case (imem_addr[15:0])
            16'h0000: imem_data = 32'h00000013;  // nop (addi x0, x0, 0)
            16'h0004: imem_data = 32'h00100093;  // addi x1, x0, 1
            16'h0008: imem_data = 32'h00200113;  // addi x2, x0, 2
            16'h000C: imem_data = 32'h002081B3;  // add x3, x1, x2
            default:  imem_data = 32'h00000013;  // nop
        endcase
    end

    // Data memory model
    always @(*) begin
        dmem_ready = 1'b1;
        dmem_rdata = 32'hDEADBEEF;  // Dummy read data
    end

    // Waveform dump
    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, tb_cpu);
    end

    // Test sequence
    initial begin
        $display("============================================");
        $display("RISC-V CPU Testbench");
        $display("============================================");

        // Wait for reset release
        @(posedge rst_n);
        $display("Reset released at time %0t", $time);

        // Run for some cycles
        repeat (20) @(posedge clk);

        $display("Test completed at time %0t", $time);
        $finish;
    end

endmodule
