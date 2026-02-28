//============================================================================
// Testbench for MMU (Memory Management Unit) Module
// Tests: Page table walk, page fault detection, permission checking
//============================================================================
`include "../src/defines.vh"
`timescale 1ns/1ps

module tb_mmu;

    // Testbench signals
    reg         clk;
    reg         rst_n;
    
    // CPU interface
    reg  [31:0] va;
    wire [31:0] pa;
    reg         we;
    reg         re;
    wire        page_fault;
    wire        access_fault;
    
    // CSR interface
    reg  [31:0] satp;
    reg         mprv;
    reg  [1:0]  priv_mode;
    
    // Memory interface
    wire [31:0] mem_addr;
    reg  [31:0] mem_rdata;
    wire        mem_re;
    wire        mem_we;
    wire        mem_busy;
    
    // Page table walk interface
    wire [31:0] pt_addr;
    reg  [31:0] pt_data;
    wire        pt_re;
    
    // Test result tracking
    integer     test_num;
    integer     pass_count;
    integer     fail_count;
    
    // Page table entries
    reg [31:0] page_table [0:1023];  // Simulated page table in memory
    
    // Loop variable
    integer i;
    
    // PTE bits
    localparam PTE_V = 0;
    localparam PTE_R = 1;
    localparam PTE_W = 2;
    localparam PTE_X = 3;
    localparam PTE_U = 4;
    localparam PTE_G = 5;
    localparam PTE_A = 6;
    localparam PTE_D = 7;
    
    // DUT instantiation
    mmu u_mmu (
        .clk(clk),
        .rst_n(rst_n),
        .va(va),
        .pa(pa),
        .we(we),
        .re(re),
        .page_fault(page_fault),
        .access_fault(access_fault),
        .satp(satp),
        .mprv(mprv),
        .priv_mode(priv_mode),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_re(mem_re),
        .mem_we(mem_we),
        .mem_busy(mem_busy),
        .pt_addr(pt_addr),
        .pt_data(pt_data),
        .pt_re(pt_re)
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
    
    // Page table memory read
    always @(*) begin
        if (pt_re) begin
            pt_data = page_table[pt_addr[11:2]];
        end
    end
    
    // Task: Wait for MMU to complete
    task wait_mmu_done;
        begin
            while (mem_busy) @(posedge clk);
            @(posedge clk);
        end
    endtask
    
    // Task: Setup page table entry
    task setup_pte;
        input [9:0]  vpn1;
        input [9:0]  vpn0;
        input [21:0] ppn;
        input [7:0]  flags;
        begin
            page_table[{vpn1, 2'b00}] = {ppn, 10'b0, flags};
        end
    endtask
    
    // Task: Test address translation
    task test_translation;
        input [31:0] virtual_addr;
        input        is_write;
        input [31:0] expected_pa;
        input        expect_fault;
        begin
            @(posedge clk);
            va <= virtual_addr;
            we <= is_write;
            re <= ~is_write;
            @(posedge clk);
            we <= 1'b0;
            re <= 1'b0;
            
            wait_mmu_done();
            @(negedge clk);
            
            if (expect_fault) begin
                if (!page_fault && !access_fault) begin
                    $display("[FAIL] Test %0d: VA=0x%08X, expected fault but none occurred",
                        test_num, virtual_addr);
                    fail_count = fail_count + 1;
                end else begin
                    $display("[PASS] Test %0d: VA=0x%08X, fault correctly detected", 
                        test_num, virtual_addr);
                    pass_count = pass_count + 1;
                end
            end else begin
                if (page_fault || access_fault) begin
                    $display("[FAIL] Test %0d: VA=0x%08X, unexpected fault", 
                        test_num, virtual_addr);
                    fail_count = fail_count + 1;
                end else if (pa !== expected_pa) begin
                    $display("[FAIL] Test %0d: VA=0x%08X, PA=0x%08X, expected 0x%08X",
                        test_num, virtual_addr, pa, expected_pa);
                    fail_count = fail_count + 1;
                end else begin
                    $display("[PASS] Test %0d: VA=0x%08X -> PA=0x%08X",
                        test_num, virtual_addr, pa);
                    pass_count = pass_count + 1;
                end
            end
            test_num = test_num + 1;
        end
    endtask
    
    // Test stimulus
    initial begin
        // Initialize signals
        va = 32'd0;
        we = 1'b0;
        re = 1'b0;
        satp = 32'd0;
        mprv = 1'b0;
        priv_mode = 2'b00;  // User mode
        mem_rdata = 32'd0;
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Initialize page table
        for (i = 0; i < 1024; i = i + 1)
            page_table[i] = 32'd0;
        
        // Wait for reset
        @(posedge rst_n);
        #10;
        
        $display("\n==============================================");
        $display("       MMU Module Test Start");
        $display("==============================================\n");
        
        //====================================================================
        // Test 1: Bare mode (MMU disabled)
        //====================================================================
        $display("\n--- Test Group 1: Bare Mode (MMU disabled) ---");
        satp = 32'h0000_0000;  // Mode = 0 (Bare)
        priv_mode = 2'b00;      // User mode
        
        test_translation(32'h0000_1000, 1'b0, 32'h0000_1000, 1'b0);
        test_translation(32'h0000_2000, 1'b1, 32'h0000_2000, 1'b0);
        test_translation(32'h8000_0000, 1'b0, 32'h8000_0000, 1'b0);
        
        //====================================================================
        // Test 2: Sv32 mode with valid 4KB page
        //====================================================================
        $display("\n--- Test Group 2: Sv32 Mode with 4KB Page ---");
        
        // Setup SATP: Mode=1 (Sv32), PPN=0x100 (root page table at 0x100*4096)
        satp = 32'h8000_0100;  // Mode=1, PPN=0x100
        
        // Setup page table:
        // VPN1=0, VPN0=1 -> PPN=0x2000 (physical page at 0x2000*4096)
        // PTE: V=1, R=1, W=1, X=1, U=1
        page_table[0] = {22'h0000_01, 10'b0, 8'b0000_1111};  // Level 1: points to level 0 table at PPN=1
        page_table[1] = {22'h0000_10, 10'b0, 8'b0000_1111};  // Level 0: 4KB page at PPN=0x10
        
        // VA: VPN1=0, VPN0=1, offset=0x234 -> PA: PPN=0x10, offset=0x234
        test_translation(32'h0000_1234, 1'b0, 32'h0001_0234, 1'b0);
        
        // Same page, write access
        test_translation(32'h0000_1FFF, 1'b1, 32'h0001_0FFF, 1'b0);
        
        //====================================================================
        // Test 3: Page fault - invalid PTE
        //====================================================================
        $display("\n--- Test Group 3: Page Fault (Invalid PTE) ---");
        
        // VA: VPN1=0, VPN0=2 -> PTE is invalid (V=0)
        page_table[2] = {22'h0000_20, 10'b0, 8'b0000_0000};  // Invalid PTE
        test_translation(32'h0000_2000, 1'b0, 32'd0, 1'b1);  // Should fault
        
        //====================================================================
        // Test 4: Access fault - no read permission
        //====================================================================
        $display("\n--- Test Group 4: Access Fault (No Read Permission) ---");
        
        // Setup page with only write permission (unusual but valid test)
        page_table[3] = {22'h0000_30, 10'b0, 8'b0000_0110};  // V=1, W=1, no R
        test_translation(32'h0000_3000, 1'b0, 32'd0, 1'b1);  // Read should fault
        
        // But write should succeed
        test_translation(32'h0000_3000, 1'b1, 32'h0003_0000, 1'b0);
        
        //====================================================================
        // Test 5: Megapage (4MB page at level 1)
        //====================================================================
        $display("\n--- Test Group 5: Megapage (4MB) ---");
        
        // VPN1=1 -> Leaf PTE at level 1 (megapage)
        // PPN=0x40, covers 4MB range (VPN1=1 maps to 0x0040_0000 - 0x0043_FFFF)
        page_table[4] = {22'h0000_40, 10'b0, 8'b0000_1111};  // V=1, R=1, W=1, X=1
        
        // VA: VPN1=1, VPN0=0, offset=0x5678 -> PA: PPN[19:0]=0x40, VPN0=0, offset=0x5678
        // But wait, for megapage, PPN is 22 bits, VPN0 becomes part of offset
        // Actually for megapage: PA = {PPN[19:0], VPN0[9:0], offset[11:0]}
        test_translation(32'h0040_5678, 1'b0, 32'h0040_5678, 1'b0);
        
        //====================================================================
        // Test 6: M-mode bypass (MMU disabled in M-mode)
        //====================================================================
        $display("\n--- Test Group 6: M-mode Bypass ---");
        
        priv_mode = 2'b11;  // Machine mode
        // Even with SATP enabled, M-mode should bypass MMU
        test_translation(32'h0000_ABCD, 1'b0, 32'h0000_ABCD, 1'b0);
        
        //====================================================================
        // Test 7: MPRV (Modify Privilege)
        //====================================================================
        $display("\n--- Test Group 7: MPRV Mode ---");
        
        priv_mode = 2'b11;  // Machine mode
        mprv = 1'b1;        // But access as if in user mode
        
        // This should now use MMU translation
        test_translation(32'h0000_1234, 1'b0, 32'h0001_0234, 1'b0);
        
        mprv = 1'b0;
        
        //====================================================================
        // Test 8: Two-level page table walk
        //====================================================================
        $display("\n--- Test Group 8: Two-level Page Table Walk ---");
        
        priv_mode = 2'b00;  // Back to user mode
        
        // Setup a more complex page table structure
        // Root at PPN=0x100 (set in SATP)
        // Level 1 entry 5 points to another page table at PPN=0x50
        page_table[5] = {22'h0000_50, 10'b0, 8'b0000_0001};  // Pointer to level 0 table
        
        // Level 0 table at PPN=0x50 (array indices 0x50*1024/4 to ...)
        // Actually our page_table is indexed by word address
        // PPN=0x50 means page table at physical address 0x50*4096 = 0x50000
        // In our simulation, we use indices differently
        
        // Simplified: Setup level 0 entry at index corresponding to PPN=0x50
        page_table[8'd80] = {22'h0000_A0, 10'b0, 8'b0000_1111};  // Points to physical page 0xA0 (index 80 = 0x50)
        
        // VA with VPN1=5, VPN0=0 -> should translate to PA 0xA0_0000
        test_translation(32'h0050_0000, 1'b0, 32'h00A0_0000, 1'b0);
        
        //====================================================================
        // Test Summary
        //====================================================================
        $display("\n==============================================");
        $display("       MMU Module Test Complete");
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
