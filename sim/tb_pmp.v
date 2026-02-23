//============================================================================
// Testbench for PMP (Physical Memory Protection) Module
// Tests: TOR mode, NAPOT mode, permission checking, M-mode bypass
//============================================================================
`include "../src/defines.vh"
`timescale 1ns/1ps

module tb_pmp;

    // Testbench signals
    reg         clk;
    reg         rst_n;
    
    // Access request
    reg  [31:0] addr;
    reg         we;
    reg         re;
    reg         xe;
    reg  [1:0]  priv_mode;
    
    // PMP CSR interface
    reg  [31:0] pmpcfg0;
    reg  [31:0] pmpcfg1;
    reg  [31:0] pmpaddr0;
    reg  [31:0] pmpaddr1;
    reg  [31:0] pmpaddr2;
    reg  [31:0] pmpaddr3;
    
    // Access result
    wire        access_ok;
    wire        access_fault;
    
    // Test result tracking
    integer     test_num;
    integer     pass_count;
    integer     fail_count;
    
    // PMP configuration bits
    localparam PMP_L = 7;   // Lock
    localparam PMP_A_HI = 4; // Address mode high
    localparam PMP_A_LO = 3; // Address mode low
    localparam PMP_X = 2;   // Execute
    localparam PMP_W = 1;   // Write
    localparam PMP_R = 0;   // Read
    
    // Address matching modes
    localparam PMP_OFF   = 2'b00;
    localparam PMP_TOR   = 2'b01;
    localparam PMP_NA4   = 2'b10;
    localparam PMP_NAPOT = 2'b11;
    
    // DUT instantiation
    pmp #(
        .PMP_ENTRIES(4)
    ) u_pmp (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .we(we),
        .re(re),
        .xe(xe),
        .priv_mode(priv_mode),
        .pmpcfg0(pmpcfg0),
        .pmpcfg1(pmpcfg1),
        .pmpaddr0(pmpaddr0),
        .pmpaddr1(pmpaddr1),
        .pmpaddr2(pmpaddr2),
        .pmpaddr3(pmpaddr3),
        .access_ok(access_ok),
        .access_fault(access_fault)
    );
    
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
    
    // Task: Configure PMP entry
    task config_pmp;
        input [1:0]  entry;
        input [7:0]  cfg;
        input [31:0] addr_val;
        begin
            case (entry)
                2'd0: begin
                    pmpcfg0[7:0] <= cfg;
                    pmpaddr0 <= addr_val;
                end
                2'd1: begin
                    pmpcfg0[15:8] <= cfg;
                    pmpaddr1 <= addr_val;
                end
                2'd2: begin
                    pmpcfg0[23:16] <= cfg;
                    pmpaddr2 <= addr_val;
                end
                2'd3: begin
                    pmpcfg0[31:24] <= cfg;
                    pmpaddr3 <= addr_val;
                end
            endcase
        end
    endtask
    
    // Task: Test PMP access
    task test_access;
        input [31:0] test_addr;
        input        test_we;
        input        test_re;
        input        test_xe;
        input        expect_ok;
        begin
            @(posedge clk);
            addr <= test_addr;
            we <= test_we;
            re <= test_re;
            xe <= test_xe;
            @(negedge clk);
            
            if (expect_ok) begin
                if (!access_ok || access_fault) begin
                    $display("[FAIL] Test %0d: Addr=0x%08X %s%s%s, expected OK but faulted",
                        test_num, test_addr, 
                        test_re ? "R" : "", test_we ? "W" : "", test_xe ? "X" : "");
                    fail_count = fail_count + 1;
                end else begin
                    $display("[PASS] Test %0d: Addr=0x%08X %s%s%s access allowed",
                        test_num, test_addr,
                        test_re ? "R" : "", test_we ? "W" : "", test_xe ? "X" : "");
                    pass_count = pass_count + 1;
                end
            end else begin
                if (access_ok || !access_fault) begin
                    $display("[FAIL] Test %0d: Addr=0x%08X %s%s%s, expected fault but OK",
                        test_num, test_addr,
                        test_re ? "R" : "", test_we ? "W" : "", test_xe ? "X" : "");
                    fail_count = fail_count + 1;
                end else begin
                    $display("[PASS] Test %0d: Addr=0x%08X %s%s%s access correctly denied",
                        test_num, test_addr,
                        test_re ? "R" : "", test_we ? "W" : "", test_xe ? "X" : "");
                    pass_count = pass_count + 1;
                end
            end
            test_num = test_num + 1;
            
            // Reset access signals
            we <= 1'b0;
            re <= 1'b0;
            xe <= 1'b0;
        end
    endtask
    
    // Test stimulus
    initial begin
        // Initialize signals
        addr = 32'd0;
        we = 1'b0;
        re = 1'b0;
        xe = 1'b0;
        priv_mode = 2'b00;  // User mode
        pmpcfg0 = 32'd0;
        pmpcfg1 = 32'd0;
        pmpaddr0 = 32'd0;
        pmpaddr1 = 32'd0;
        pmpaddr2 = 32'd0;
        pmpaddr3 = 32'd0;
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Wait for reset
        @(posedge rst_n);
        #10;
        
        $display("\n==============================================");
        $display("       PMP Module Test Start");
        $display("==============================================\n");
        
        //====================================================================
        // Test 1: M-mode bypass (no PMP regions configured)
        //====================================================================
        $display("\n--- Test Group 1: M-mode Bypass ---");
        priv_mode = 2'b11;  // Machine mode
        
        // Without any PMP regions, M-mode should have full access
        test_access(32'h0000_0000, 1'b1, 1'b0, 1'b0, 1'b1);  // Write OK
        test_access(32'h0000_0000, 1'b0, 1'b1, 1'b0, 1'b1);  // Read OK
        test_access(32'h0000_0000, 1'b0, 1'b0, 1'b1, 1'b1);  // Execute OK
        test_access(32'hFFFF_FFFF, 1'b1, 1'b0, 1'b0, 1'b1);  // Any address OK
        
        //====================================================================
        // Test 2: U-mode with no PMP regions (all accesses denied)
        //====================================================================
        $display("\n--- Test Group 2: U-mode No PMP Regions ---");
        priv_mode = 2'b00;  // User mode
        
        test_access(32'h0000_0000, 1'b0, 1'b1, 1'b0, 1'b0);  // Read denied
        test_access(32'h0000_0000, 1'b1, 1'b0, 1'b0, 1'b0);  // Write denied
        test_access(32'h0000_0000, 1'b0, 1'b0, 1'b1, 1'b0);  // Execute denied
        
        //====================================================================
        // Test 3: NA4 mode (4-byte region)
        //====================================================================
        $display("\n--- Test Group 3: NA4 Mode (4-byte region) ---");
        
        // Configure entry 0: NA4 at address 0x1000, R+W enabled
        config_pmp(2'd0, (PMP_NA4 << 3) | (1 << PMP_W) | (1 << PMP_R), 32'h0000_0400);  // 0x1000 >> 2
        
        // Wait for config to apply
        @(posedge clk);
        
        // Access within region (0x1000 - 0x1003)
        test_access(32'h0000_1000, 1'b0, 1'b1, 1'b0, 1'b1);  // Read OK
        test_access(32'h0000_1000, 1'b1, 1'b0, 1'b0, 1'b1);  // Write OK
        test_access(32'h0000_1003, 1'b0, 1'b1, 1'b0, 1'b1);  // Read at boundary OK
        
        // Access outside region
        test_access(32'h0000_1004, 1'b0, 1'b1, 1'b0, 1'b0);  // Read denied
        test_access(32'h0000_0FFF, 1'b0, 1'b1, 1'b0, 1'b0);  // Read denied
        
        // Execute not allowed
        test_access(32'h0000_1000, 1'b0, 1'b0, 1'b1, 1'b0);  // Execute denied
        
        //====================================================================
        // Test 4: TOR mode (Top of Range)
        //====================================================================
        $display("\n--- Test Group 4: TOR Mode (Top of Range) ---");
        
        // Configure entry 1: TOR, covers 0x2000 - 0x3000, R+X enabled
        // Start address comes from previous entry's end (pmpaddr0 << 2)
        // End address is pmpaddr1 << 2
        config_pmp(2'd1, (PMP_TOR << 3) | (1 << PMP_X) | (1 << PMP_R), 32'h0000_0C00);  // End at 0x3000 >> 2
        
        @(posedge clk);
        
        // Access within region (0x1004 - 0x3000, since entry 0 ended at 0x1004)
        test_access(32'h0000_2000, 1'b0, 1'b1, 1'b0, 1'b1);  // Read OK
        test_access(32'h0000_2000, 1'b0, 1'b0, 1'b1, 1'b1);  // Execute OK
        test_access(32'h0000_2FFF, 1'b0, 1'b1, 1'b0, 1'b1);  // Read at boundary OK
        
        // Write not allowed
        test_access(32'h0000_2000, 1'b1, 1'b0, 1'b0, 1'b0);  // Write denied
        
        // Access outside region
        test_access(32'h0000_3000, 1'b0, 1'b1, 1'b0, 1'b0);  // Read denied (at end boundary)
        
        //====================================================================
        // Test 5: NAPOT mode (Power of 2 region)
        //====================================================================
        $display("\n--- Test Group 5: NAPOT Mode (Power of 2) ---");
        
        // NAPOT encoding: address with trailing 1s
        // 0x0000_1FFF in pmpaddr2 with NAPOT mode -> 64KB region starting at 0x0000_0000
        // Actually: addr with n trailing 1s = 2^(n+3) byte region
        // pmpaddr = 0x0000_1FFF = 0b0001_1111_1111_1111 (13 trailing 1s)
        // Region size = 2^(13+3) = 2^16 = 64KB
        // Region base = 0 (since all lower bits are 1)
        
        config_pmp(2'd2, (PMP_NAPOT << 3) | (1 << PMP_W) | (1 << PMP_R) | (1 << PMP_X), 
                   32'h0000_07FF);  // 8KB region (10 trailing 1s -> 2^13 = 8KB)
        
        @(posedge clk);
        
        // Access within 8KB region starting at 0x0000_0000
        test_access(32'h0000_0000, 1'b0, 1'b1, 1'b0, 1'b1);  // Read OK
        test_access(32'h0000_1FFF, 1'b1, 1'b0, 1'b0, 1'b1);  // Write at end OK
        test_access(32'h0000_1000, 1'b0, 1'b0, 1'b1, 1'b1);  // Execute OK
        
        // Access outside region (note: NAPOT region size may vary based on encoding)
        // 0x2000 is at the boundary - may be inside or outside depending on exact calculation
        test_access(32'h0000_4000, 1'b0, 1'b1, 1'b0, 1'b0);  // Read denied (far outside)
        
        //====================================================================
        // Test 6: M-mode with locked region
        //====================================================================
        $display("\n--- Test Group 6: M-mode with Locked Region ---");
        
        priv_mode = 2'b11;  // Machine mode
        
        // Configure entry 3: TOR, covers 0x8000_0000 - 0x9000_0000, L=1 (locked), R only
        config_pmp(2'd3, (1 << PMP_L) | (PMP_TOR << 3) | (1 << PMP_R), 32'h2400_0000);  // End at 0x9000_0000
        
        @(posedge clk);
        
        // Access within locked region - M-mode must follow PMP rules when L=1
        test_access(32'h8000_0000, 1'b0, 1'b1, 1'b0, 1'b1);  // Read OK
        test_access(32'h8000_0000, 1'b1, 1'b0, 1'b0, 1'b0);  // Write denied (no W permission)
        test_access(32'h8000_0000, 1'b0, 1'b0, 1'b1, 1'b0);  // Execute denied (no X permission)
        
        // Access outside locked region - M-mode bypass applies
        test_access(32'h0000_0000, 1'b1, 1'b0, 1'b0, 1'b1);  // Write OK (outside locked region)
        
        //====================================================================
        // Test 7: Multiple matching regions (first match wins)
        //====================================================================
        $display("\n--- Test Group 7: Multiple Matching Regions ---");
        
        priv_mode = 2'b00;  // User mode
        
        // Clear previous config and setup new regions
        pmpcfg0 = 32'd0;
        
        // Entry 0: 0x0000_0000 - 0x0000_1000, R+W (no X)
        config_pmp(2'd0, (PMP_TOR << 3) | (1 << PMP_W) | (1 << PMP_R), 32'h0000_0400);
        
        // Entry 1: 0x0000_0000 - 0x0000_2000, X only (overlaps with entry 0)
        // But since entry 0 matches first, entry 1's permissions don't matter
        config_pmp(2'd1, (PMP_TOR << 3) | (1 << PMP_X), 32'h0000_0800);
        
        @(posedge clk);
        
        // At 0x800, entry 0 matches (0x0000 - 0x1000), so R+W is allowed, X is not
        test_access(32'h0000_0800, 1'b0, 1'b1, 1'b0, 1'b1);  // Read OK (from entry 0)
        test_access(32'h0000_0800, 1'b1, 1'b0, 1'b0, 1'b1);  // Write OK (from entry 0)
        test_access(32'h0000_0800, 1'b0, 1'b0, 1'b1, 1'b0);  // Execute denied (entry 0 has no X)
        
        // At 0x1800, only entry 1 matches (0x1000 - 0x2000)
        test_access(32'h0000_1800, 1'b0, 1'b0, 1'b1, 1'b1);  // Execute OK (from entry 1)
        test_access(32'h0000_1800, 1'b0, 1'b1, 1'b0, 1'b0);  // Read denied (entry 1 has no R)
        
        //====================================================================
        // Test 8: S-mode access
        //====================================================================
        $display("\n--- Test Group 8: S-mode Access ---");
        
        priv_mode = 2'b01;  // Supervisor mode
        
        // Clear all PMP configs first
        pmpcfg0 = 32'd0;
        pmpaddr0 = 32'd0;
        pmpaddr1 = 32'd0;
        pmpaddr2 = 32'd0;
        pmpaddr3 = 32'd0;
        @(posedge clk);
        
        // Configure one region for S-mode testing: 0x0000 - 0x1000
        config_pmp(2'd0, (PMP_TOR << 3) | (1 << PMP_W) | (1 << PMP_R) | (1 << PMP_X), 
                   32'h0000_0400);  // End at 0x1000
        
        @(posedge clk);
        @(posedge clk);
        
        // S-mode follows same rules as U-mode for PMP
        test_access(32'h0000_0800, 1'b0, 1'b1, 1'b0, 1'b1);  // Read OK
        test_access(32'h0000_3000, 1'b0, 1'b1, 1'b0, 1'b0);  // Read denied (far outside)
        
        //====================================================================
        // Test Summary
        //====================================================================
        $display("\n==============================================");
        $display("       PMP Module Test Complete");
        $display("==============================================");
        $display("Total Tests: %0d", test_num);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        if (fail_count == 0)
            $display("STATUS: ALL TESTS PASSED!");
        else
            $display("STATUS: SOME TESTS FAILED!");
        $display("==============================================\n");
        
        #100;
        $finish;
    end

endmodule
