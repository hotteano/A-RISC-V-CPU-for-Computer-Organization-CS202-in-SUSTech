/******************************************************************************
 * Linker Script for RISC-V CPU on EGO1-FPGA
 * Memory: 64KB BRAM at 0x0000_0000
 ******************************************************************************/

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    /* 64KB Instruction/Data BRAM */
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
    /* Text section - code and read-only data */
    .text : {
        *(.text.init)
        *(.text.startup)
        *(.text)
        *(.text.*)
    } > ram
    
    /* Read-only data */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
    } > ram
    
    /* Initialized data */
    .data : {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > ram
    
    /* BSS - uninitialized data */
    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        __bss_end = .;
    } > ram
    
    /* Stack at end of RAM */
    __stack_top = ORIGIN(ram) + LENGTH(ram);
    
    /* Heap after BSS */
    end = __bss_end;
    _end = __bss_end;
    
    /* Discard unnecessary sections */
    /DISCARD/ : {
        *(.comment)
        *(.note)
        *(.note.*)
        *(.eh_frame)
        *(.gnu.*)
    }
}
