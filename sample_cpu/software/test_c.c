/******************************************************************************
 * RISC-V C Test Program
 * Tests: Integer operations, loops, functions, memory access, IO
 ******************************************************************************/

// Memory mapped IO addresses
#define GPIO_LED    (*(volatile unsigned int*)0x10001008)
#define GPIO_SWITCH (*(volatile unsigned int*)0x10001000)
#define UART_DATA   (*(volatile unsigned int*)0x10000000)
#define UART_STATUS (*(volatile unsigned int*)0x10000004)

// Test result storage
volatile unsigned int test_results[32];
volatile unsigned int test_count = 0;

// Function prototypes
int add(int a, int b);
int multiply(int a, int b);
int factorial(int n);
int fibonacci(int n);
void print_char(char c);
void print_string(const char* str);
void print_hex(unsigned int val);
void delay(volatile int count);

/******************************************************************************
 * Main Function
 ******************************************************************************/
int main(void) {
    int i;
    int result;
    
    // Test 1: Basic arithmetic
    test_results[test_count++] = add(5, 3);        // 8
    test_results[test_count++] = add(100, -50);    // 50
    
    // Test 2: Multiplication
    test_results[test_count++] = multiply(7, 6);   // 42
    test_results[test_count++] = multiply(13, 13); // 169
    
    // Test 3: Factorial
    test_results[test_count++] = factorial(5);     // 120
    test_results[test_count++] = factorial(7);     // 5040
    
    // Test 4: Fibonacci
    test_results[test_count++] = fibonacci(10);    // 55
    test_results[test_count++] = fibonacci(15);    // 610
    
    // Test 5: Bitwise operations
    test_results[test_count++] = 0xFF & 0x0F;      // 0x0F
    test_results[test_count++] = 0xFF | 0xF0;      // 0xFF
    test_results[test_count++] = 0xFF ^ 0x0F;      // 0xF0
    test_results[test_count++] = 0x01 << 8;        // 0x100
    test_results[test_count++] = 0x100 >> 4;       // 0x10
    
    // Test 6: Array operations
    int arr[10];
    for (i = 0; i < 10; i++) {
        arr[i] = i * i;
    }
    test_results[test_count++] = arr[5];           // 25
    test_results[test_count++] = arr[9];           // 81
    
    // Test 7: Pointer operations
    int* ptr = arr;
    test_results[test_count++] = *ptr;             // 0
    ptr++;
    test_results[test_count++] = *ptr;             // 1
    ptr += 4;
    test_results[test_count++] = *ptr;             // 25
    
    // Test 8: Conditional operations
    result = 0;
    for (i = 0; i < 20; i++) {
        if (i % 2 == 0) {
            result += i;
        } else {
            result -= i;
        }
    }
    test_results[test_count++] = result;           // 10
    
    // Test 9: Switch statement
    int switch_result = 0;
    for (i = 0; i < 5; i++) {
        switch (i) {
            case 0: switch_result += 1; break;
            case 1: switch_result += 2; break;
            case 2: switch_result += 4; break;
            case 3: switch_result += 8; break;
            default: switch_result += 16; break;
        }
    }
    test_results[test_count++] = switch_result;    // 31
    
    // Test 10: Read switches and output to LEDs
    unsigned int switch_val = GPIO_SWITCH & 0xFFFF;
    GPIO_LED = switch_val;  // Echo switches to LEDs
    test_results[test_count++] = switch_val;
    
    // UART output - print results
    print_string("RISC-V CPU Test Results:\r\n");
    print_string("========================\r\n");
    
    for (i = 0; i < test_count; i++) {
        print_string("Test ");
        print_char('0' + i / 10);
        print_char('0' + i % 10);
        print_string(": 0x");
        print_hex(test_results[i]);
        print_string("\r\n");
    }
    
    print_string("\r\nAll tests completed!\r\n");
    
    // Success pattern on LEDs
    while (1) {
        GPIO_LED = 0xAAAA;
        delay(100000);
        GPIO_LED = 0x5555;
        delay(100000);
    }
    
    return 0;
}

/******************************************************************************
 * Function: add
 * Description: Add two integers
 ******************************************************************************/
int add(int a, int b) {
    return a + b;
}

/******************************************************************************
 * Function: multiply
 * Description: Multiply two integers using shift-and-add
 ******************************************************************************/
int multiply(int a, int b) {
    int result = 0;
    int i;
    
    for (i = 0; i < 32; i++) {
        if (b & 1) {
            result += a;
        }
        a <<= 1;
        b >>= 1;
    }
    
    return result;
}

/******************************************************************************
 * Function: factorial
 * Description: Calculate factorial of n
 ******************************************************************************/
int factorial(int n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

/******************************************************************************
 * Function: fibonacci
 * Description: Calculate nth Fibonacci number
 ******************************************************************************/
int fibonacci(int n) {
    if (n <= 1) {
        return n;
    }
    
    int a = 0, b = 1, temp;
    int i;
    
    for (i = 2; i <= n; i++) {
        temp = a + b;
        a = b;
        b = temp;
    }
    
    return b;
}

/******************************************************************************
 * Function: print_char
 * Description: Send a character via UART
 ******************************************************************************/
void print_char(char c) {
    // Wait for UART ready
    while (!(UART_STATUS & 0x04));
    UART_DATA = c;
}

/******************************************************************************
 * Function: print_string
 * Description: Send a string via UART
 ******************************************************************************/
void print_string(const char* str) {
    while (*str) {
        print_char(*str++);
    }
}

/******************************************************************************
 * Function: print_hex
 * Description: Print a 32-bit value in hexadecimal
 ******************************************************************************/
void print_hex(unsigned int val) {
    int i;
    unsigned int nibble;
    
    for (i = 28; i >= 0; i -= 4) {
        nibble = (val >> i) & 0xF;
        if (nibble < 10) {
            print_char('0' + nibble);
        } else {
            print_char('A' + (nibble - 10));
        }
    }
}

/******************************************************************************
 * Function: delay
 * Description: Simple delay loop
 ******************************************************************************/
void delay(volatile int count) {
    while (count--);
}

// /******************************************************************************
//  * Entry Point (_start)
//  ******************************************************************************/
// void _start(void) {
//     // Initialize stack pointer
//     __asm__ volatile (
//         "li sp, 0x00010000\n"
//     );
    
//     // Call main
//     main();
    
//     // Halt
//     while (1);
// }
