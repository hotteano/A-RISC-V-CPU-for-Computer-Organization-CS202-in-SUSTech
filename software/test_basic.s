################################################################################
# Basic RISC-V Assembly Test Program
# Tests: ALU operations, Branch, Load/Store, CSR
# Target: Memory at 0x0000_0000
################################################################################

    .section .text
    .globl _start

_start:
    # Initialize stack pointer
    li      sp, 0x00010000      # Stack at end of 64KB BRAM
    
    #===============================================
    # Test 1: Basic ALU Operations
    #===============================================
    li      t0, 0x12345678      # Load immediate
    li      t1, 0x87654321
    
    add     t2, t0, t1          # t2 = 0x99999999
    sub     t3, t0, t1          # t3 = 0x8ACF1357
    and     t4, t0, t1          # t4 = 0x02244220
    or      t5, t0, t1          # t5 = 0x97755779
    xor     t6, t0, t1          # t6 = 0x95511559
    
    # Store results for verification
    li      s0, 0x00001000      # Base address for test results
    sw      t2, 0(s0)
    sw      t3, 4(s0)
    sw      t4, 8(s0)
    sw      t5, 12(s0)
    sw      t6, 16(s0)
    
    #===============================================
    # Test 2: Shift Operations
    #===============================================
    li      t0, 0x0000000F
    sll     t1, t0, 4           # t1 = 0x000000F0
    srl     t2, t1, 2           # t2 = 0x0000003C
    sra     t3, t1, 2           # t3 = 0x0000003C (positive)
    
    li      t0, 0x80000000      # Negative number
    sra     t4, t0, 4           # t4 = 0xF8000000 (sign extended)
    
    sw      t1, 20(s0)
    sw      t2, 24(s0)
    sw      t3, 28(s0)
    sw      t4, 32(s0)
    
    #===============================================
    # Test 3: Comparison Operations
    #===============================================
    li      t0, 5
    li      t1, -3
    li      t2, 10
    
    slt     t3, t0, t1          # t3 = 0 (5 > -3, signed)
    sltu    t4, t0, t1          # t4 = 1 (5 < -3, unsigned)
    slt     t5, t0, t2          # t5 = 1 (5 < 10)
    
    sw      t3, 36(s0)
    sw      t4, 40(s0)
    sw      t5, 44(s0)
    
    #===============================================
    # Test 4: Branch Operations
    #===============================================
    li      t0, 0
    li      t1, 10
    
branch_test_loop:
    addi    t0, t0, 1
    bne     t0, t1, branch_test_loop  # Loop 10 times
    
    # t0 should be 10 now
    sw      t0, 48(s0)
    
    # Test conditional branches
    li      t0, 5
    li      t1, 5
    li      t2, 0               # Result accumulator
    
    beq     t0, t1, beq_passed
    j       beq_failed
beq_passed:
    ori     t2, t2, 0x01
beq_failed:

    li      t0, 5
    li      t1, 3
    blt     t0, t1, blt_failed
    ori     t2, t2, 0x02
blt_failed:

    bge     t0, t1, bge_passed
    j       bge_failed
bge_passed:
    ori     t2, t2, 0x04
bge_failed:
    
    sw      t2, 52(s0)          # Should be 0x07
    
    #===============================================
    # Test 5: Jump Operations
    #===============================================
    li      t0, 0
    
    jal     ra, jump_target1
    # Should return here
    addi    t0, t0, 1           # t0 = 1
    
    jal     ra, jump_target2
    addi    t0, t0, 1           # t0 = 3
    
    j       jump_test_done

jump_target1:
    addi    t0, t0, 1           # t0 = 1
    jalr    zero, ra, 0         # Return

jump_target2:
    addi    t0, t0, 1           # t0 = 2
    jalr    zero, ra, 0         # Return

jump_test_done:
    sw      t0, 56(s0)          # Should be 3
    
    #===============================================
    # Test 6: Load/Store Operations (Byte/Half/Word)
    #===============================================
    li      s1, 0x00001100      # Test data area
    
    # Store bytes
    li      t0, 0x89ABCDEF
    sb      t0, 0(s1)
    srli    t0, t0, 8
    sb      t0, 1(s1)
    srli    t0, t0, 8
    sb      t0, 2(s1)
    srli    t0, t0, 8
    sb      t0, 3(s1)
    
    # Load bytes
    lbu     t1, 0(s1)           # 0x000000EF
    lb      t2, 0(s1)           # 0xFFFFFFEF (sign extended)
    lbu     t3, 3(s1)           # 0x00000089
    
    sw      t1, 60(s0)
    sw      t2, 64(s0)
    sw      t3, 68(s0)
    
    # Store halfwords
    li      t0, 0xABCD1234
    sh      t0, 8(s1)
    srli    t0, t0, 16
    sh      t0, 10(s1)
    
    # Load halfwords
    lhu     t1, 8(s1)           # 0x00001234
    lh      t2, 10(s1)          # 0xFFFFABCD (sign extended)
    
    sw      t1, 72(s0)
    sw      t2, 76(s0)
    
    #===============================================
    # Test 7: CSR Operations
    #===============================================
    # Read mstatus
    csrr    t0, mstatus
    sw      t0, 80(s0)
    
    # Read misa
    csrr    t1, misa
    sw      t1, 84(s0)
    
    # Write/read scratch register
    li      t2, 0xDEADBEEF
    csrw    mscratch, t2
    csrr    t3, mscratch
    sw      t3, 88(s0)          # Should be 0xDEADBEEF
    
    # CSRRS (set bits)
    li      t4, 0x8             # MIE bit
    csrs    mstatus, t4
    csrr    t5, mstatus
    sw      t5, 92(s0)
    
    #===============================================
    # Test 8: Function Call
    #===============================================
    li      a0, 5
    li      a1, 3
    jal     ra, multiply
    # Result in a0 should be 15
    sw      a0, 96(s0)
    
    #===============================================
    # Test 9: LED Output
    #===============================================
    li      t0, 0x10001000      # GPIO_LED address
    li      t1, 0x5555          # Pattern on LEDs
    sw      t1, 8(t0)
    
    #===============================================
    # Test 10: UART Output (Print "PASS")
    #===============================================
    li      t0, 0x10000000      # UART base address
    
    # Wait for UART ready
uart_wait1:
    lw      t2, 4(t0)           # Read status
    andi    t2, t2, 0x4         # Check TX ready bit
    beqz    t2, uart_wait1
    
    li      t1, 'P'
    sw      t1, 0(t0)           # Send 'P'
    
uart_wait2:
    lw      t2, 4(t0)
    andi    t2, t2, 0x4
    beqz    t2, uart_wait2
    
    li      t1, 'A'
    sw      t1, 0(t0)           # Send 'A'
    
uart_wait3:
    lw      t2, 4(t0)
    andi    t2, t2, 0x4
    beqz    t2, uart_wait3
    
    li      t1, 'S'
    sw      t1, 0(t0)           # Send 'S'
    
uart_wait4:
    lw      t2, 4(t0)
    andi    t2, t2, 0x4
    beqz    t2, uart_wait4
    
    li      t1, 'S'
    sw      t1, 0(t0)           # Send 'S'
    
uart_wait5:
    lw      t2, 4(t0)
    andi    t2, t2, 0x4
    beqz    t2, uart_wait5
    
    li      t1, '\n'
    sw      t1, 0(t0)           # Send newline
    
    #===============================================
    # All Tests Complete - Success Pattern
    #===============================================
    li      t0, 0x10001000      # GPIO_LED
    li      t1, 0xAAAA          # Success pattern
    sw      t1, 8(t0)
    
halt:
    j       halt                # Infinite loop

    #===============================================
    # Multiply Function: a0 = a0 * a1
    #===============================================
multiply:
    li      t0, 0               # Result
    li      t1, 0               # Counter
    
mult_loop:
    beqz    a1, mult_done
    andi    t2, a1, 1
    beqz    t2, mult_skip
    add     t0, t0, a0
mult_skip:
    slli    a0, a0, 1
    srli    a1, a1, 1
    j       mult_loop
    
mult_done:
    mv      a0, t0
    jalr    zero, ra, 0

    #===============================================
    # Data Section
    #===============================================
    .section .data
    .align  4

test_data:
    .word   0x11111111
    .word   0x22222222
    .word   0x33333333
    .word   0x44444444

    .section .bss
    .align  4

test_results:
    .space  128                  # Space for test results
