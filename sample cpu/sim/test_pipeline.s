//============================================================================
// Pipeline Test Program for RISC-V CPU
// Tests: Forwarding, Hazards, Branches, Memory Access
//============================================================================

    .section .text
    .globl _start
    .align 2

_start:
    //====================================================================
    // Test 1: Basic ALU Operations
    //====================================================================
_test_alu:
    li      x1, 5               // x1 = 5
    li      x2, 3               // x2 = 3
    add     x3, x1, x2          // x3 = 8
    sub     x4, x1, x2          // x4 = 2
    and     x5, x1, x2          // x5 = 1
    or      x6, x1, x2          // x6 = 7
    xor     x7, x1, x2          // x7 = 6
    
    //====================================================================
    // Test 2: Forwarding (Data Hazards)
    // No stalls should occur due to forwarding
    //====================================================================
_test_forwarding:
    li      x10, 10             // x10 = 10
    addi    x11, x10, 5         // x11 = 15 (forward from EX)
    add     x12, x11, x10       // x12 = 25 (forward from MEM and EX)
    sub     x13, x12, x11       // x13 = 10 (forward from WB and MEM)
    
    //====================================================================
    // Test 3: Load-Use Hazard
    // This should cause a 1-cycle stall
    //====================================================================
_test_load_use:
    la      x20, test_data      // Load test data address
    lw      x21, 0(x20)         // x21 = mem[test_data]
    add     x22, x21, x10       // Uses x21 immediately (stall + forward)
    
    //====================================================================
    // Test 4: Branch Operations
    //====================================================================
_test_branch:
    li      x30, 0              // Counter
    li      x31, 5              // Loop limit

branch_loop:
    addi    x30, x30, 1         // Increment counter
    blt     x30, x31, branch_loop   // Loop 5 times
    
    // Test conditional branches
    li      x5, 5
    li      x6, 5
    beq     x5, x6, beq_passed
    j       beq_failed
beq_passed:
    li      x7, 1               // Success marker
beq_failed:

    //====================================================================
    // Test 5: Jump Operations
    //====================================================================
_test_jump:
    jal     x1, jump_target1    // Jump and link
    j       jump_done           // Should skip this

jump_target1:
    li      x8, 0xABCD          // Marker
    jalr    x0, x1, 0           // Return

jump_done:
    
    //====================================================================
    // Test 6: Memory Operations
    //====================================================================
_test_memory:
    la      x20, test_data
    
    // Store word
    li      x15, 0x12345678
    sw      x15, 0(x20)
    
    // Load word
    lw      x16, 0(x20)
    
    // Store byte
    li      x15, 0xAB
    sb      x15, 0(x20)
    
    // Load byte (unsigned)
    lbu     x17, 0(x20)
    
    // Store halfword
    li      x15, 0xCDEF
    sh      x15, 2(x20)
    
    // Load halfword (signed)
    lh      x18, 2(x20)
    
    //====================================================================
    // Test 7: Shift Operations
    //====================================================================
_test_shift:
    li      x19, 1
    slli    x20, x19, 4         // x20 = 16
    srli    x21, x20, 2         // x21 = 4
    
    li      x22, 0x80000000     // Negative number
    srai    x23, x22, 4         // x23 = 0xF8000000 (sign extended)
    srl     x24, x22, x19       // x24 = 0x40000000
    
    //====================================================================
    // Test 8: Comparison Operations
    //====================================================================
_test_compare:
    li      x25, 5
    li      x26, -3
    li      x27, 10
    
    slt     x28, x25, x26       // x28 = 0 (5 > -3, signed)
    sltu    x29, x25, x26       // x29 = 1 (5 < -3, unsigned)
    slti    x30, x25, 10        // x30 = 1 (5 < 10)
    
    //====================================================================
    // Test Complete
    //====================================================================
_test_complete:
    li      x31, 0xDEADBEEF     // Success pattern
    ebreak                      // End simulation

    //====================================================================
    // Data Section
    //====================================================================
    .section .data
    .align 4
test_data:
    .word   0x00000000
    .word   0x11111111
    .word   0x22222222
    .word   0x33333333
