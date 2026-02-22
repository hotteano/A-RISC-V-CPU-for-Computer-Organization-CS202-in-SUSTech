//============================================================================
// RISC-V CPU Defines - RV32I Base Integer Instruction Set
//============================================================================

//----------------------------------------------------------------------------
// General Constants
//----------------------------------------------------------------------------
`define ZERO_WORD        32'h0000_0000
`define INST_WIDTH       32
`define INST_ADDR_WIDTH  32
`define REG_ADDR_WIDTH   5
`define REG_DATA_WIDTH   32
`define DATA_ADDR_WIDTH  32
`define DATA_DATA_WIDTH  32
`define CSR_ADDR_WIDTH   12
`define CSR_DATA_WIDTH   32
`define IO_ADDR_WIDTH    32
`define IO_DATA_WIDTH    32
`define EXC_CODE_WIDTH   4
`define ALU_OP_WIDTH     6

//----------------------------------------------------------------------------
// Bus Types - Defined as width values (without brackets) for use in arithmetic
//----------------------------------------------------------------------------
`define INST_BUS         31:0
`define INST_ADDR_BUS    31:0
`define REG_ADDR_BUS     4:0
`define REG_DATA_BUS     31:0
`define DATA_ADDR_BUS    31:0
`define DATA_DATA_BUS    31:0
`define CSR_ADDR_BUS     11:0
`define CSR_DATA_BUS     31:0
`define IO_ADDR_BUS      31:0
`define IO_DATA_BUS      31:0
`define EXC_CODE_BUS     3:0
`define ALU_OP_BUS       5:0

//----------------------------------------------------------------------------
// Privilege Modes (RISC-V Privileged Architecture)
//----------------------------------------------------------------------------
`define PRIV_U           2'b00  // User mode
`define PRIV_S           2'b01  // Supervisor mode
`define PRIV_M           2'b11  // Machine mode

//----------------------------------------------------------------------------
// ALU Operation Codes
//----------------------------------------------------------------------------
// Arithmetic
`define ALU_ADD          6'b000000
`define ALU_SUB          6'b000001
`define ALU_AND          6'b000010
`define ALU_OR           6'b000011
`define ALU_XOR          6'b000100
`define ALU_SLL          6'b000101  // Shift Left Logical
`define ALU_SRL          6'b000110  // Shift Right Logical
`define ALU_SRA          6'b000111  // Shift Right Arithmetic
`define ALU_SLT          6'b001000  // Set Less Than
`define ALU_SLTU         6'b001001  // Set Less Than Unsigned
// Branch
`define ALU_BEQ          6'b001010  // Branch Equal
`define ALU_BNE          6'b001011  // Branch Not Equal
`define ALU_BLT          6'b001100  // Branch Less Than
`define ALU_BGE          6'b001101  // Branch Greater Equal
`define ALU_BLTU         6'b001110  // Branch Less Than Unsigned
`define ALU_BGEU         6'b001111  // Branch Greater Equal Unsigned
// Upper Immediate
`define ALU_LUI          6'b010000  // Load Upper Immediate
`define ALU_AUIPC        6'b010001  // Add Upper Immediate to PC
// Jump
`define ALU_JAL          6'b010010  // Jump and Link
`define ALU_JALR         6'b010011  // Jump and Link Register
// CSR
`define ALU_CSRRW        6'b010100  // CSR Read/Write
`define ALU_CSRRS        6'b010101  // CSR Read/Set
`define ALU_CSRRC        6'b010110  // CSR Read/Clear
// Pass through
`define ALU_PASS_A       6'b010111  // Pass operand A
`define ALU_PASS_B       6'b011000  // Pass operand B
// NOP
`define ALU_NOP          6'b011111  // No operation

//----------------------------------------------------------------------------
// Opcode Definitions
//----------------------------------------------------------------------------
`define OPCODE_LOAD      7'b0000011
`define OPCODE_STORE     7'b0100011
`define OPCODE_OP_IMM    7'b0010011
`define OPCODE_OP        7'b0110011
`define OPCODE_JAL       7'b1101111
`define OPCODE_JALR      7'b1100111
`define OPCODE_BRANCH    7'b1100011
`define OPCODE_LUI       7'b0110111
`define OPCODE_AUIPC     7'b0010111
`define OPCODE_FENCE     7'b0001111
`define OPCODE_SYSTEM    7'b1110011

//----------------------------------------------------------------------------
// Funct3 Definitions
//----------------------------------------------------------------------------
// Load
`define FUNCT3_LB        3'b000
`define FUNCT3_LH        3'b001
`define FUNCT3_LW        3'b010
`define FUNCT3_LBU       3'b100
`define FUNCT3_LHU       3'b101
// Store
`define FUNCT3_SB        3'b000
`define FUNCT3_SH        3'b001
`define FUNCT3_SW        3'b010
// OP-IMM
`define FUNCT3_ADDI      3'b000
`define FUNCT3_SLTI      3'b010
`define FUNCT3_SLTIU     3'b011
`define FUNCT3_XORI      3'b100
`define FUNCT3_ORI       3'b110
`define FUNCT3_ANDI      3'b111
`define FUNCT3_SLLI      3'b001
`define FUNCT3_SRLI_SRAI 3'b101
// OP
`define FUNCT3_ADD_SUB   3'b000
`define FUNCT3_SLL       3'b001
`define FUNCT3_SLT       3'b010
`define FUNCT3_SLTU      3'b011
`define FUNCT3_XOR       3'b100
`define FUNCT3_SRL_SRA   3'b101
`define FUNCT3_OR        3'b110
`define FUNCT3_AND       3'b111
// Branch
`define FUNCT3_BEQ       3'b000
`define FUNCT3_BNE       3'b001
`define FUNCT3_BLT       3'b100
`define FUNCT3_BGE       3'b101
`define FUNCT3_BLTU      3'b110
`define FUNCT3_BGEU      3'b111
// SYSTEM
`define FUNCT3_PRIV      3'b000
`define FUNCT3_CSRRW     3'b001
`define FUNCT3_CSRRS     3'b010
`define FUNCT3_CSRRC     3'b011
`define FUNCT3_CSRRWI    3'b101
`define FUNCT3_CSRRSI    3'b110
`define FUNCT3_CSRRCI    3'b111

//----------------------------------------------------------------------------
// Funct7 Definitions
//----------------------------------------------------------------------------
`define FUNCT7_ADD       7'b0000000
`define FUNCT7_SUB       7'b0100000
`define FUNCT7_SRL       7'b0000000
`define FUNCT7_SRA       7'b0100000
`define FUNCT7_SLL       7'b0000000

//----------------------------------------------------------------------------
// Funct12 Definitions (SYSTEM instructions)
//----------------------------------------------------------------------------
`define FUNCT12_ECALL    12'b000000000000
`define FUNCT12_EBREAK   12'b000000000001
`define FUNCT12_MRET     12'b001100000010
`define FUNCT12_SRET     12'b000100000010
`define FUNCT12_URET     12'b000000000010
`define FUNCT12_WFI      12'b000100000101

//----------------------------------------------------------------------------
// Exception Codes
//----------------------------------------------------------------------------
`define EXC_NONE             4'd0
`define EXC_INST_MISALIGNED  4'd0   // Instruction address misaligned
`define EXC_INST_ACCESS_FAULT 4'd1  // Instruction access fault
`define EXC_ILLEGAL_INST     4'd2   // Illegal instruction
`define EXC_BREAKPOINT       4'd3   // Breakpoint
`define EXC_LOAD_MISALIGNED  4'd4   // Load address misaligned
`define EXC_LOAD_ACCESS_FAULT 4'd5  // Load access fault
`define EXC_STORE_MISALIGNED 4'd6   // Store/AMO address misaligned
`define EXC_STORE_ACCESS_FAULT 4'd7 // Store/AMO access fault
`define EXC_ECALL_U          4'd8   // Environment call from U-mode
`define EXC_ECALL_S          4'd9   // Environment call from S-mode
`define EXC_RESERVED_10      4'd10  // Reserved
`define EXC_ECALL_M          4'd11  // Environment call from M-mode
`define EXC_INST_PAGE_FAULT  4'd12  // Instruction page fault
`define EXC_LOAD_PAGE_FAULT  4'd13  // Load page fault
`define EXC_RESERVED_14      4'd14  // Reserved
`define EXC_STORE_PAGE_FAULT 4'd15  // Store/AMO page fault

//----------------------------------------------------------------------------
// CSR Addresses
//----------------------------------------------------------------------------
// Machine Information Registers
`define CSR_MVENDORID    12'hF11
`define CSR_MARCHID      12'hF12
`define CSR_MIMPID       12'hF13
`define CSR_MHARTID      12'hF14
`define CSR_MCONFIGPTR   12'hF15
// Machine Trap Setup
`define CSR_MSTATUS      12'h300
`define CSR_MISA         12'h301
`define CSR_MEDELEG      12'h302
`define CSR_MIDELEG      12'h303
`define CSR_MIE          12'h304
`define CSR_MTVEC        12'h305
`define CSR_MCOUNTEREN   12'h306
`define CSR_MSTATUSH     12'h310
// Machine Trap Handling
`define CSR_MSCRATCH     12'h340
`define CSR_MEPC         12'h341
`define CSR_MCAUSE       12'h342
`define CSR_MTVAL        12'h343
`define CSR_MIP          12'h344
`define CSR_MTINST       12'h34A
`define CSR_MTVAL2       12'h34B
// Machine Configuration
`define CSR_MENVCFG      12'h30A
`define CSR_MENVCFGH     12'h31A
`define CSR_MSECCFG      12'h747
`define CSR_MSECCFGH     12'h757
// Physical Memory Protection
`define CSR_PMPCFG0      12'h3A0
`define CSR_PMPCFG1      12'h3A1
`define CSR_PMPCFG2      12'h3A2
`define CSR_PMPCFG3      12'h3A3
`define CSR_PMPADDR0     12'h3B0
`define CSR_PMPADDR1     12'h3B1
`define CSR_PMPADDR2     12'h3B2
`define CSR_PMPADDR3     12'h3B3
// Machine Counters
`define CSR_MCYCLE       12'hB00
`define CSR_MINSTRET     12'hB02
`define CSR_MHPMCOUNTER3 12'hB03
`define CSR_MCYCLEH      12'hB80
`define CSR_MINSTRETH    12'hB82
`define CSR_MHPMCOUNTER3H 12'hB83
// Machine Counter Setup
`define CSR_MCOUNTINHIBIT 12'h320
`define CSR_MHPMEVENT3   12'h323
// Debug/Trace
`define CSR_TSELECT      12'h7A0
`define CSR_TDATA1       12'h7A1
`define CSR_TDATA2       12'h7A2
`define CSR_TDATA3       12'h7A3
`define CSR_MCONTEXT     12'h7A8
// Debug
`define CSR_DCSR         12'h7B0
`define CSR_DPC          12'h7B1
`define CSR_DSCRATCH0    12'h7B2
`define CSR_DSCRATCH1    12'h7B3

//----------------------------------------------------------------------------
// MSTATUS Register Fields
//----------------------------------------------------------------------------
`define MSTATUS_UIE      3'd0   // User Interrupt Enable
`define MSTATUS_SIE      3'd1   // Supervisor Interrupt Enable
`define MSTATUS_MIE      3'd3   // Machine Interrupt Enable
`define MSTATUS_UPIE     3'd4   // User Previous IE
`define MSTATUS_SPIE     3'd5   // Supervisor Previous IE
`define MSTATUS_MPIE     3'd7   // Machine Previous IE
`define MSTATUS_SPP      8'd8   // Supervisor Previous Privilege
`define MSTATUS_MPP_LO   11'd11 // Machine Previous Privilege (low)
`define MSTATUS_MPP_HI   12'd12 // Machine Previous Privilege (high)
`define MSTATUS_FS_LO    13'd13 // Floating-point Status (low)
`define MSTATUS_FS_HI    14'd14 // Floating-point Status (high)
`define MSTATUS_XS_LO    15'd15 // Extension Status (low)
`define MSTATUS_XS_HI    16'd16 // Extension Status (high)
`define MSTATUS_MPRV     17'd17 // Modify Privilege
`define MSTATUS_SUM      18'd18 // Permit Supervisor User Memory access
`define MSTATUS_MXR      19'd19 // Make eXecutable Readable
`define MSTATUS_TVM      20'd20 // Trap Virtual Memory
`define MSTATUS_TW       21'd21 // Timeout Wait
`define MSTATUS_TSR      22'd22 // Trap SRET
`define MSTATUS_SD       31'd31 // State Dirty (summary)

//----------------------------------------------------------------------------
// MIP/MIE Register Fields
//----------------------------------------------------------------------------
`define MIP_USIP         3'd0   // User Software Interrupt Pending
`define MIP_SSIP         3'd1   // Supervisor Software Interrupt Pending
`define MIP_MSIP         3'd3   // Machine Software Interrupt Pending
`define MIP_UTIP         3'd4   // User Timer Interrupt Pending
`define MIP_STIP         3'd5   // Supervisor Timer Interrupt Pending
`define MIP_MTIP         3'd7   // Machine Timer Interrupt Pending
`define MIP_UEIP         3'd8   // User External Interrupt Pending
`define MIP_SEIP         3'd9   // Supervisor External Interrupt Pending
`define MIP_MEIP         3'd11  // Machine External Interrupt Pending

//----------------------------------------------------------------------------
// Forwarding Control
//----------------------------------------------------------------------------
`define FORWARD_NONE     2'b00
`define FORWARD_WB       2'b01
`define FORWARD_MEM      2'b10

//----------------------------------------------------------------------------
// Memory Map
//----------------------------------------------------------------------------
`define MEM_BASE_ADDR    32'h0000_0000  // Instruction/Data BRAM base
`define MEM_SIZE         32'h0001_0000  // 64KB
`define IO_BASE_ADDR     32'h1000_0000  // IO space base
`define IO_SIZE          32'h0001_0000  // 64KB

//----------------------------------------------------------------------------
// Reset Vector
//----------------------------------------------------------------------------
`define RESET_VECTOR     32'h0000_0000
