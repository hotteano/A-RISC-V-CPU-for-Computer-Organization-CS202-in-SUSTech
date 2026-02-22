/******************************************************************************
 * C Runtime Startup for RISC-V
 * Initializes stack and BSS, then calls main
 ******************************************************************************/

    .section .text.init
    .globl _start
    .type _start, @function

_start:
    # Initialize stack pointer
    # Stack grows downward from end of RAM
    lui     sp, %hi(__stack_top)
    addi    sp, sp, %lo(__stack_top)
    
    # Clear BSS section
    lui     a0, %hi(__bss_start)
    addi    a0, a0, %lo(__bss_start)
    lui     a1, %hi(__bss_end)
    addi    a1, a1, %lo(__bss_end)
    
    # If BSS is empty, skip clearing
    beq     a0, a1, clear_bss_done

clear_bss_loop:
    sw      zero, 0(a0)
    addi    a0, a0, 4
    blt     a0, a1, clear_bss_loop

clear_bss_done:
    # Call main
    call    main
    
    # If main returns, halt
    j       halt

    # Halt loop
halt:
    wfi                     # Wait for interrupt (if supported)
    j       halt

    .size _start, . - _start
