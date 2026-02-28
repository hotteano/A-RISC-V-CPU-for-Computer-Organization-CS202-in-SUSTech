//============================================================================
// CSR (Control and Status Register) Unit for RISC-V
// Supports: RV32I, M-mode (Machine mode)
// Features: Exception handling, Interrupts, Timer, Counter
//============================================================================
`include "defines.vh"

module csr_reg (
    input  wire        clk,
    input  wire        rst_n,
    
    // CSR read/write interface (from ID stage)
    input  wire [11:0] csr_addr,
    input  wire [31:0] csr_wdata,
    output reg  [31:0] csr_rdata,
    input  wire        csr_we,
    input  wire [1:0]  csr_op,          // 00=CSRRW, 01=CSRRS, 10=CSRRC
    
    // Exception interface (from MEM stage)
    input  wire        exception_valid,
    input  wire [31:0] exception_pc,
    input  wire [31:0] exception_cause,
    input  wire [31:0] exception_val,   // Bad address or instruction
    
    // MRET instruction
    input  wire        mret_exec,
    
    // Interrupt inputs
    input  wire        timer_interrupt,
    input  wire        external_interrupt,
    input  wire        software_interrupt,
    
    // Outputs to pipeline
    output wire [31:0] mtvec_out,       // Trap vector base address
    output wire [31:0] mepc_out,        // Machine exception PC
    output wire        global_ie,       // Global interrupt enable (MIE)
    output wire        trap_taken       // Trap is being taken
);

    //========================================================================
    // CSR Addresses (RV32I standard)
    //========================================================================
    localparam CSR_MSTATUS  = 12'h300;  // Machine Status
    localparam CSR_MISA     = 12'h301;  // Machine ISA
    localparam CSR_MEDELEG  = 12'h302;  // Machine Exception Delegation
    localparam CSR_MIDELEG  = 12'h303;  // Machine Interrupt Delegation
    localparam CSR_MIE      = 12'h304;  // Machine Interrupt Enable
    localparam CSR_MTVEC    = 12'h305;  // Machine Trap Vector
    localparam CSR_MSCRATCH = 12'h340;  // Machine Scratch
    localparam CSR_MEPC     = 12'h341;  // Machine Exception PC
    localparam CSR_MCAUSE   = 12'h342;  // Machine Cause
    localparam CSR_MTVAL    = 12'h343;  // Machine Trap Value
    localparam CSR_MIP      = 12'h344;  // Machine Interrupt Pending
    localparam CSR_MCYCLE   = 12'hB00;  // Machine Cycle Counter
    localparam CSR_MINSTRET = 12'hB02;  // Machine Instruction Retired
    localparam CSR_MCYCLEH  = 12'hB80;  // Machine Cycle Counter High
    localparam CSR_MINSTRETH= 12'hB82;  // Machine Inst Retired High
    localparam CSR_MVENDORID= 12'hF11;  // Vendor ID
    localparam CSR_MARCHID  = 12'hF12;  // Architecture ID
    localparam CSR_MIMPID   = 12'hF13;  // Implementation ID
    localparam CSR_MHARTID  = 12'hF14;  // Hardware Thread ID

    //========================================================================
    // CSR Registers
    //========================================================================
    reg [31:0] mstatus;     // Machine status
    reg [31:0] misa;        // ISA and extensions
    reg [31:0] medeleg;     // Exception delegation
    reg [31:0] mideleg;     // Interrupt delegation
    reg [31:0] mie;         // Interrupt enable
    reg [31:0] mtvec;       // Trap vector base address
    reg [31:0] mscratch;    // Scratch register
    reg [31:0] mepc;        // Exception program counter
    reg [31:0] mcause;      // Trap cause
    reg [31:0] mtval;       // Bad address or instruction
    reg [31:0] mip;         // Interrupt pending
    reg [63:0] mcycle;      // Cycle counter (64-bit)
    reg [63:0] minstret;    // Instruction retired counter (64-bit)

    //========================================================================
    // MSTATUS Fields
    //========================================================================
    wire mstatus_mie  = mstatus[3];   // Machine Interrupt Enable
    wire mstatus_mpie = mstatus[7];   // Machine Previous IE
    wire [1:0] mstatus_mpp = mstatus[12:11]; // Machine Previous Privilege

    //========================================================================
    // MIP/MIE Fields
    //========================================================================
    wire mie_msie = mie[3];   // Machine Software Interrupt Enable
    wire mie_mtie = mie[7];   // Machine Timer Interrupt Enable
    wire mie_meie = mie[11];  // Machine External Interrupt Enable
    
    wire mip_msip = mip[3];   // Machine Software Interrupt Pending
    wire mip_mtip = mip[7];   // Machine Timer Interrupt Pending
    wire mip_meip = mip[11];  // Machine External Interrupt Pending

    //========================================================================
    // Interrupt Detection
    //========================================================================
    wire interrupt_taken = mstatus_mie && (
        (mie_meie && mip_meip) ||
        (mie_mtie && mip_mtip) ||
        (mie_msie && mip_msip)
    );
    
    assign trap_taken = exception_valid || interrupt_taken;
    assign global_ie = mstatus_mie;
    assign mtvec_out = mtvec;
    assign mepc_out = mepc;

    //========================================================================
    // CSR Read Logic
    //========================================================================
    always @(*) begin
        case (csr_addr)
            CSR_MSTATUS:   csr_rdata = mstatus;
            CSR_MISA:      csr_rdata = misa;
            CSR_MEDELEG:   csr_rdata = medeleg;
            CSR_MIDELEG:   csr_rdata = mideleg;
            CSR_MIE:       csr_rdata = mie;
            CSR_MTVEC:     csr_rdata = mtvec;
            CSR_MSCRATCH:  csr_rdata = mscratch;
            CSR_MEPC:      csr_rdata = mepc;
            CSR_MCAUSE:    csr_rdata = mcause;
            CSR_MTVAL:     csr_rdata = mtval;
            CSR_MIP:       csr_rdata = mip;
            CSR_MCYCLE:    csr_rdata = mcycle[31:0];
            CSR_MINSTRET:  csr_rdata = minstret[31:0];
            CSR_MCYCLEH:   csr_rdata = mcycle[63:32];
            CSR_MINSTRETH: csr_rdata = minstret[63:32];
            CSR_MVENDORID: csr_rdata = 32'h0000_0000;  // Not implemented
            CSR_MARCHID:   csr_rdata = 32'h0000_0000;
            CSR_MIMPID:    csr_rdata = 32'h0000_0001;
            CSR_MHARTID:   csr_rdata = 32'h0000_0000;  // Hart 0
            default:       csr_rdata = 32'h0000_0000;
        endcase
    end

    //========================================================================
    // CSR Write Logic
    //========================================================================
    wire [31:0] csr_write_data;
    
    // CSR operation decode
    assign csr_write_data = (csr_op == 2'b00) ? csr_wdata :           // CSRRW
                            (csr_op == 2'b01) ? (csr_rdata | csr_wdata) :  // CSRRS
                            (csr_op == 2'b10) ? (csr_rdata & ~csr_wdata) : // CSRRC
                            csr_wdata;

    //========================================================================
    // Sequential Logic
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus   <= 32'h0000_0000;
            misa      <= 32'h4000_1100;  // RV32I + RV32M (bit 12)
            medeleg   <= 32'h0000_0000;
            mideleg   <= 32'h0000_0000;
            mie       <= 32'h0000_0000;
            mtvec     <= 32'h0000_0000;
            mscratch  <= 32'h0000_0000;
            mepc      <= 32'h0000_0000;
            mcause    <= 32'h0000_0000;
            mtval     <= 32'h0000_0000;
            mip       <= 32'h0000_0000;
            mcycle    <= 64'd0;
            minstret  <= 64'd0;
        end else begin
            // Update counters every cycle
            mcycle <= mcycle + 1;
            
            // Handle MRET (return from trap)
            if (mret_exec) begin
                mstatus[3] <= mstatus[7];   // MIE <- MPIE
                mstatus[7] <= 1'b1;         // MPIE <- 1
                mstatus[12:11] <= 2'b11;    // MPP <- M-mode
            end
            
            // Handle trap (exception or interrupt)
            else if (trap_taken) begin
                mepc <= exception_valid ? exception_pc : mepc;
                mcause <= exception_valid ? exception_cause : mcause;
                mtval <= exception_val;
                mstatus[7] <= mstatus[3];   // MPIE <- MIE
                mstatus[3] <= 1'b0;         // MIE <- 0 (disable interrupts)
                mstatus[12:11] <= 2'b11;    // MPP <- M-mode
            end
            
            // Handle CSR write
            else if (csr_we) begin
                case (csr_addr)
                    CSR_MSTATUS:   mstatus  <= csr_write_data;
                    CSR_MEDELEG:   medeleg  <= csr_write_data;
                    CSR_MIDELEG:   mideleg  <= csr_write_data;
                    CSR_MIE:       mie      <= csr_write_data;
                    CSR_MTVEC:     mtvec    <= {csr_write_data[31:2], 2'b00};
                    CSR_MSCRATCH:  mscratch <= csr_write_data;
                    CSR_MEPC:      mepc     <= {csr_write_data[31:2], 2'b00};
                    CSR_MCAUSE:    mcause   <= csr_write_data;
                    CSR_MTVAL:     mtval    <= csr_write_data;
                    CSR_MINSTRET:  minstret[31:0] <= csr_write_data;
                    CSR_MINSTRETH: minstret[63:32] <= csr_write_data;
                    // MIP is read-only (except for software interrupts)
                    default: ;
                endcase
            end
            
            // Update interrupt pending bits
            mip[11] <= external_interrupt;
            mip[7]  <= timer_interrupt;
            mip[3]  <= software_interrupt;
        end
    end

endmodule
