//============================================================================
// Load-Use Hazard Debug Testbench
//============================================================================
`include "../src/defines.vh"
`timescale 1ns/1ps

module tb_load_use_debug;

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
    
    // Debug: Access internal signals
    wire [31:0] if_id_instr = u_cpu.if_id_instr;
    wire [4:0]  if_id_rs1 = u_cpu.if_id_instr[19:15];
    wire [4:0]  if_id_rs2 = u_cpu.if_id_instr[24:20];
    wire [4:0]  if_id_rd  = u_cpu.if_id_instr[11:7];
    
    wire [4:0]  id_ex_rs1 = u_cpu.id_ex_rs1_addr;
    wire [4:0]  id_ex_rs2 = u_cpu.id_ex_rs2_addr;
    wire [4:0]  id_ex_rd  = u_cpu.id_ex_rd_addr;
    wire        id_ex_mem_read = u_cpu.id_ex_mem_read;
    wire [31:0] id_ex_rs1_data = u_cpu.id_ex_rs1_data;
    
    wire [4:0]  mem_wb_rd = u_cpu.mem_wb_rd_addr;
    wire        mem_wb_reg_write = u_cpu.mem_wb_reg_write;
    wire [31:0] rf_rd_data = u_cpu.rf_rd_data;
    
    wire [1:0]  forward_a_id = u_cpu.forward_a_id;
    wire [1:0]  forward_a_ex = u_cpu.forward_a_ex;
    wire        pc_stall = u_cpu.pc_stall;
    wire        if_id_stall = u_cpu.if_id_stall;
    wire        id_ex_flush = u_cpu.id_ex_flush;
    
    wire [31:0] x6_val = u_cpu.u_regfile.registers[6];
    wire [31:0] x7_val = u_cpu.u_regfile.registers[7];
    
    // ID stage forwarding
    wire [31:0] id_rs1_fwd = u_cpu.u_id_stage.rs1_data_fwd;
    wire [31:0] id_rs2_fwd = u_cpu.u_id_stage.rs2_data_fwd;
    wire [31:0] id_rs2_raw = u_cpu.u_id_stage.rs2_data;
    wire [4:0]  id_rs2_addr = u_cpu.u_id_stage.rs2_addr;
    
    // EX stage signals for SW
    wire [31:0] ex_rs2_data = u_cpu.id_ex_rs2_data;
    wire        ex_mem_write = u_cpu.id_ex_mem_write;
    wire [31:0] ex_rs2_fwd = u_cpu.u_ex_stage.rs2_fwd;
    wire [31:0] ex_forward_mem = u_cpu.u_ex_stage.forward_mem_data;
    wire [31:0] ex_forward_wb = u_cpu.u_ex_stage.forward_wb_data;
    
    // EX/MEM signals
    wire [31:0] ex_mem_rs2 = u_cpu.ex_mem_rs2_data;
    wire        ex_mem_mw = u_cpu.ex_mem_mem_write;
    
    // Hazard unit internal signals
    wire [4:0]  hu_if_id_rs1 = u_cpu.u_hazard_unit.if_id_rs1;
    wire [4:0]  hu_if_id_rs2 = u_cpu.u_hazard_unit.if_id_rs2;
    wire        hu_id_ex_mem_read = u_cpu.u_hazard_unit.id_ex_mem_read;
    wire [4:0]  hu_id_ex_rd = u_cpu.u_hazard_unit.id_ex_rd;
    wire        hu_stall = u_cpu.u_hazard_unit.pc_stall;
    
    // Test Program
    initial begin
        // Init memories
        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000013;  // NOP
            dmem[i] = 32'd0;
        end
        
        // Pre-load dmem[0] with 100
        dmem[0] = 32'd100;
        
        // Simple Load-Use test - same register for dest and src
        // LW x6, 0(x0)  - load 100 from dmem[0]
        // ADDI x6, x6, 10 - x6 = 100 + 10 = 110
        // SW x6, 4(x0)  - store to dmem[1]
        // NOP...
        imem[0] = 32'h00002303;  // LW   x6, 0(x0)
        imem[1] = 32'h00a30313;  // ADDI x6, x6, 10
        imem[2] = 32'h00602223;  // SW   x6, 4(x0)
        imem[3] = 32'h00000013;  // NOP
        imem[4] = 32'h00000013;  // NOP
        imem[5] = 32'h00000013;  // NOP
        imem[6] = 32'h00000013;  // NOP
        imem[7] = 32'h00000013;  // NOP
        
        $display("========================================");
        $display("  Load-Use Hazard Debug Test");
        $display("========================================");
        $display("Initial dmem[0] = 100");
        $display("Expected: x6=100, x7=110, dmem[1]=110");
        $display("");
        
        // Display cycle-by-cycle from reset release
        $display("Time=%0t: Starting trace", $time);
        
        repeat(30) begin
            @(posedge clk);
            #1;
            $display("T=%0t IFID=%h EX[r1=%h r1d=%h] ID[r1=%h r1d=%h f_id=%h f_ex=%h]", 
                $time, if_id_instr,
                id_ex_rs1, id_ex_rs1_data[7:0],
                u_cpu.u_id_stage.rs1_addr, u_cpu.u_id_stage.rs1_data[7:0], 
                u_cpu.forward_a_id, u_cpu.forward_a_ex);
        end
        
        // Check result
        #100;
        $display("");
        $display("--- Results ---");
        $display("x6 = %0d (expected 100)", x6_val);
        $display("x7 = %0d (expected 110)", x7_val);
        $display("dmem[1] = %0d (expected 110)", dmem[1]);
        
        if (dmem[1] == 110)
            $display("[PASS] Load-Use hazard handled correctly");
        else
            $display("[FAIL] Load-Use hazard - Got %0d, Expected 110", dmem[1]);
        
        $finish;
    end

endmodule
