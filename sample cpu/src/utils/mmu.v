//============================================================================
// MMU (Memory Management Unit) - Simplified Paging for RISC-V
// Supports: Basic page table walk, TLB for acceleration
// Page size: 4KB, Virtual/Physical address: 32-bit
//============================================================================
`include "defines.vh"

module mmu (
    input  wire        clk,
    input  wire        rst_n,
    
    // From/To CPU (MEM stage)
    input  wire [31:0] va,              // Virtual address
    output reg  [31:0] pa,              // Physical address
    input  wire        we,              // Write enable
    input  wire        re,              // Read enable
    output reg         page_fault,      // Page fault detected
    output reg         access_fault,    // Access permission fault
    
    // SATP register (from CSR)
    input  wire [31:0] satp,            // Supervisor Address Translation and Protection
    input  wire        mprv,            // Modify privilege (from mstatus)
    input  wire [1:0]  priv_mode,       // Current privilege mode
    
    // To/From Data Memory
    output reg  [31:0] mem_addr,
    input  wire [31:0] mem_rdata,
    output reg         mem_re,
    output reg         mem_we,
    output reg         mem_busy,        // MMU busy doing page walk
    
    // Page table walk address
    output reg  [31:0] pt_addr,
    input  wire [31:0] pt_data,
    output reg         pt_re
);

    //========================================================================
    // Page Table Entry (PTE) Format (RV32)
    //========================================================================
    // Bits  [31:10] - PPN (Physical Page Number)
    // Bits  [9:8]   - RSW (Reserved for Supervisor)
    // Bit   [7]     - D (Dirty)
    // Bit   [6]     - A (Accessed)
    // Bit   [5]     - G (Global)
    // Bit   [4]     - U (User accessible)
    // Bit   [3]     - X (Executable)
    // Bit   [2]     - W (Writable)
    // Bit   [1]     - R (Readable)
    // Bit   [0]     - V (Valid)
    //========================================================================
    
    // PTE field extraction
    wire [21:0] pte_ppn   = pt_data[31:10];
    wire        pte_d     = pt_data[7];
    wire        pte_a     = pt_data[6];
    wire        pte_g     = pt_data[5];
    wire        pte_u     = pt_data[4];
    wire        pte_x     = pt_data[3];
    wire        pte_w     = pt_data[2];
    wire        pte_r     = pt_data[1];
    wire        pte_v     = pt_data[0];
    
    //========================================================================
    // SATP Register Fields
    //========================================================================
    wire        satp_mode = satp[31];       // 0=Bare, 1=Sv32
    wire [21:0] satp_ppn  = satp[21:0];     // Root page table PPN
    
    //========================================================================
    // Virtual Address Fields (Sv32)
    //========================================================================
    wire [9:0]  vpn1 = va[31:22];   // Level 1 VPN
    wire [9:0]  vpn0 = va[21:12];   // Level 0 VPN
    wire [11:0] page_offset = va[11:0];
    
    //========================================================================
    // State Machine for Page Table Walk
    //========================================================================
    localparam IDLE    = 3'b000;
    localparam CHECK   = 3'b001;
    localparam WALK_L1 = 3'b010;
    localparam WALK_L0 = 3'b011;
    localparam DONE    = 3'b100;
    localparam FAULT   = 3'b101;
    
    reg [2:0] state, next_state;
    reg [31:0] pte_l1;  // Level 1 PTE
    
    // Check if MMU is enabled
    wire mmu_enabled = satp_mode && (priv_mode != 2'b11);  // Enabled in S and U mode
    
    // Permission check
    reg perm_ok;
    always @(*) begin
        perm_ok = 1'b0;
        if (pte_v) begin
            if (we && pte_w) perm_ok = 1'b1;
            else if (re && pte_r) perm_ok = 1'b1;
        end
    end
    
    // State transition
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if ((we || re) && mmu_enabled)
                    next_state = WALK_L1;
                else if (we || re)
                    next_state = DONE;  // Bare mode, no translation
            end
            
            WALK_L1: begin
                if (!pte_v)
                    next_state = FAULT;
                else if (pte_r || pte_x)  // Leaf PTE (megapage)
                    next_state = CHECK;
                else
                    next_state = WALK_L0;  // Next level
            end
            
            WALK_L0: begin
                if (!pte_v || !(pte_r || pte_x))
                    next_state = FAULT;
                else
                    next_state = CHECK;
            end
            
            CHECK: begin
                if (perm_ok)
                    next_state = DONE;
                else
                    next_state = FAULT;
            end
            
            DONE, FAULT: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pte_l1 <= 32'd0;
        end else begin
            state <= next_state;
            if (state == WALK_L1)
                pte_l1 <= pt_data;
        end
    end
    
    // Output logic
    always @(*) begin
        // Default values
        pt_addr   = 32'd0;
        pt_re     = 1'b0;
        mem_addr  = va;  // Default: no translation
        mem_re    = re && !mmu_enabled;
        mem_we    = we && !mmu_enabled;
        mem_busy  = (state != IDLE) && (state != DONE) && (state != FAULT);
        pa        = va;
        page_fault = 1'b0;
        access_fault = 1'b0;
        
        case (state)
            IDLE: begin
                if (mmu_enabled && (we || re)) begin
                    // Start page table walk
                    pt_addr = {satp_ppn, 12'b0} + {22'd0, vpn1, 2'b00};
                    pt_re = 1'b1;
                end
            end
            
            WALK_L1: begin
                if (pte_r || pte_x) begin
                    // Megapage (4MB) - leaf at level 1
                    pa = {pte_ppn[19:0], vpn0, page_offset};
                end else begin
                    // Walk to level 0
                    pt_addr = {pte_ppn, 12'b0} + {22'd0, vpn0, 2'b00};
                    pt_re = 1'b1;
                end
            end
            
            WALK_L0: begin
                // Normal 4KB page
                pa = {pte_ppn, page_offset};
            end
            
            CHECK: begin
                // Check permissions
                if (state == WALK_L1 && (pte_r || pte_x)) begin
                    pa = {pte_ppn[19:0], vpn0, page_offset};
                end else begin
                    pa = {pte_ppn, page_offset};
                end
            end
            
            DONE: begin
                if (!mmu_enabled) begin
                    pa = va;
                    mem_addr = va;
                    mem_re = re;
                    mem_we = we;
                end else begin
                    mem_addr = pa;
                    mem_re = re;
                    mem_we = we;
                end
            end
            
            FAULT: begin
                page_fault = 1'b1;
            end
        endcase
    end

endmodule
