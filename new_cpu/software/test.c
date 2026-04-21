//============================================================================
// Simple test program for RISC-V CPU
// Compile with: riscv32-unknown-elf-gcc -march=rv32i -nostdlib -Tlink.ld
//============================================================================

// Simple UART output (memory-mapped)
#define UART_BASE   0x10000000
#define UART_TX     (*(volatile unsigned int *)(UART_BASE + 0x00))

static void uart_putc(char c) {
    UART_TX = c;
}

static void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

// Entry point
void _start(void) {
    int a = 10;
    int b = 20;
    int c = a + b;

    uart_puts("Hello RISC-V!\n");

    // Simple loop test
    for (int i = 0; i < 5; i++) {
        a = a + 1;
    }

    // Halt
    while (1) {
        __asm__ volatile ("wfi");
    }
}
