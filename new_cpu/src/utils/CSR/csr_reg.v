//============================================================================
// CSR Registers - RISC-V Privileged CSR Register File
//============================================================================
`include "defines.vh"

module csr_reg (
    input  wire        clk,
    input  wire        rst_n,

    // CPU interface
    input  wire [11:0] addr,
    output reg  [31:0] rdata,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire        re,

    // Current privilege mode
    input  wire [1:0]  priv_mode,

    // Trap handling inputs
    input  wire        trap_enter,
    input  wire [31:0] trap_pc,
    input  wire [31:0] trap_cause,
    input  wire [31:0] trap_val,
    input  wire [1:0]  trap_priv,     // Privilege level to handle trap

    // Trap return
    input  wire        mret,
    input  wire        sret,
    output reg  [31:0] trap_return_pc,

    // Interrupt enable/status outputs
    output wire [31:0] mie_out,
    output wire [31:0] mip_out,
    output wire [31:0] mstatus_out,

    // Timer interrupt inputs
    input  wire        timer_irq_m,
    input  wire        timer_irq_s,
    input  wire        soft_irq_m,
    input  wire        soft_irq_s,
    input  wire        ext_irq_m,
    input  wire        ext_irq_s
);

    // Machine CSRs
    reg [31:0] mstatus;
    reg [31:0] misa;
    reg [31:0] medeleg;
    reg [31:0] mideleg;
    reg [31:0] mie;
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtval;
    reg [31:0] mip;
    reg [31:0] mcycle;
    reg [31:0] mcycleh;
    reg [31:0] minstret;
    reg [31:0] minstreth;
    reg [31:0] mcounteren;

    // Supervisor CSRs
    reg [31:0] sstatus;
    reg [31:0] sie;
    reg [31:0] stvec;
    reg [31:0] sscratch;
    reg [31:0] sepc;
    reg [31:0] scause;
    reg [31:0] stval;
    reg [31:0] sip;
    reg [31:0] satp;
    reg [31:0] scounteren;

    // PMP CSRs (4 regions)
    reg [31:0] pmpcfg0;
    reg [31:0] pmpaddr0;
    reg [31:0] pmpaddr1;
    reg [31:0] pmpaddr2;
    reg [31:0] pmpaddr3;

    // Read/write helpers
    wire [1:0] mpp = mstatus[`MSTATUS_MPP_HI:`MSTATUS_MPP_LO];
    wire [1:0] spp = mstatus[`MSTATUS_SPP];

    assign mstatus_out = mstatus;
    assign mie_out = mie;
    assign mip_out = mip;

    // MISA value (RV32IMSU + A + F)
    localparam MISA_VAL = `MISA_MXL_32 | `MISA_I | `MISA_M | `MISA_S | `MISA_U | `MISA_A | `MISA_F;

    // CSR read
    always @(*) begin
        case (addr)
            `CSR_MSTATUS:    rdata = mstatus;
            `CSR_MISA:       rdata = MISA_VAL;
            `CSR_MEDELEG:    rdata = medeleg;
            `CSR_MIDELEG:    rdata = mideleg;
            `CSR_MIE:        rdata = mie;
            `CSR_MTVEC:      rdata = mtvec;
            `CSR_MSCRATCH:   rdata = mscratch;
            `CSR_MEPC:       rdata = mepc;
            `CSR_MCAUSE:     rdata = mcause;
            `CSR_MTVAL:      rdata = mtval;
            `CSR_MIP:        rdata = mip;
            `CSR_MCYCLE:     rdata = mcycle;
            `CSR_MCYCLEH:    rdata = mcycleh;
            `CSR_MINSTRET:   rdata = minstret;
            `CSR_MINSTRETH:  rdata = minstreth;
            `CSR_MCOUNTEREN: rdata = mcounteren;
            `CSR_PMPCFG0:    rdata = pmpcfg0;
            `CSR_PMPADDR0:   rdata = pmpaddr0;
            `CSR_PMPADDR1:   rdata = pmpaddr1;
            `CSR_PMPADDR2:   rdata = pmpaddr2;
            `CSR_PMPADDR3:   rdata = pmpaddr3;
            `CSR_SSTATUS:    rdata = sstatus;
            `CSR_SIE:        rdata = sie;
            `CSR_STVEC:      rdata = stvec;
            `CSR_SSCRATCH:   rdata = sscratch;
            `CSR_SEPC:       rdata = sepc;
            `CSR_SCAUSE:     rdata = scause;
            `CSR_STVAL:      rdata = stval;
            `CSR_SIP:        rdata = sip;
            `CSR_SATP:       rdata = satp;
            `CSR_SCOUNTEREN: rdata = scounteren;
            default:         rdata = 32'd0;
        endcase
    end

    // CSR write and trap handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus    <= 32'd0;
            medeleg    <= 32'd0;
            mideleg    <= 32'd0;
            mie        <= 32'd0;
            mtvec      <= 32'd0;
            mscratch   <= 32'd0;
            mepc       <= 32'd0;
            mcause     <= 32'd0;
            mtval      <= 32'd0;
            mip        <= 32'd0;
            mcycle     <= 32'd0;
            mcycleh    <= 32'd0;
            minstret   <= 32'd0;
            minstreth  <= 32'd0;
            mcounteren <= 32'd0;
            pmpcfg0    <= 32'd0;
            pmpaddr0   <= 32'd0;
            pmpaddr1   <= 32'd0;
            pmpaddr2   <= 32'd0;
            pmpaddr3   <= 32'd0;
            sstatus    <= 32'd0;
            sie        <= 32'd0;
            stvec      <= 32'd0;
            sscratch   <= 32'd0;
            sepc       <= 32'd0;
            scause     <= 32'd0;
            stval      <= 32'd0;
            sip        <= 32'd0;
            satp       <= 32'd0;
            scounteren <= 32'd0;
            trap_return_pc <= 32'd0;
        end else begin
            // Update interrupt pending
            mip[`MIP_MSIP] <= soft_irq_m;
            mip[`MIP_SSIP] <= soft_irq_s;
            mip[`MIP_MTIP] <= timer_irq_m;
            mip[`MIP_STIP] <= timer_irq_s;
            mip[`MIP_MEIP] <= ext_irq_m;
            mip[`MIP_SEIP] <= ext_irq_s;

            // Increment cycle counter
            mcycle <= mcycle + 1;
            if (&mcycle) mcycleh <= mcycleh + 1;

            // Trap entry
            if (trap_enter) begin
                if (trap_priv == `PRIV_M) begin
                    // Save to M-mode
                    mstatus[`MSTATUS_MPIE] <= mstatus[`MSTATUS_MIE];
                    mstatus[`MSTATUS_MIE]  <= 1'b0;
                    mstatus[`MSTATUS_MPP_HI:`MSTATUS_MPP_LO] <= priv_mode;
                    mepc   <= trap_pc;
                    mcause <= trap_cause;
                    mtval  <= trap_val;
                end else if (trap_priv == `PRIV_S) begin
                    // Save to S-mode
                    sstatus[`MSTATUS_SPIE] <= sstatus[`MSTATUS_SIE];
                    sstatus[`MSTATUS_SIE]  <= 1'b0;
                    sstatus[`MSTATUS_SPP]  <= priv_mode[0];
                    sepc   <= trap_pc;
                    scause <= trap_cause;
                    stval  <= trap_val;
                end
            end

            // MRET
            if (mret) begin
                mstatus[`MSTATUS_MIE]  <= mstatus[`MSTATUS_MPIE];
                mstatus[`MSTATUS_MPIE] <= 1'b1;
                mstatus[`MSTATUS_MPP_HI:`MSTATUS_MPP_LO] <= `PRIV_U;
                trap_return_pc <= mepc;
            end

            // SRET
            if (sret) begin
                sstatus[`MSTATUS_SIE]  <= sstatus[`MSTATUS_SPIE];
                sstatus[`MSTATUS_SPIE] <= 1'b1;
                sstatus[`MSTATUS_SPP]  <= 1'b0;
                trap_return_pc <= sepc;
            end

            // CSR write
            if (we) begin
                case (addr)
                    `CSR_MSTATUS:    mstatus    <= wdata;
                    `CSR_MEDELEG:    medeleg    <= wdata;
                    `CSR_MIDELEG:    mideleg    <= wdata;
                    `CSR_MIE:        mie        <= wdata;
                    `CSR_MTVEC:      mtvec      <= wdata;
                    `CSR_MSCRATCH:   mscratch   <= wdata;
                    `CSR_MEPC:       mepc       <= wdata;
                    `CSR_MCAUSE:     mcause     <= wdata;
                    `CSR_MTVAL:      mtval      <= wdata;
                    `CSR_MCOUNTEREN: mcounteren <= wdata;
                    `CSR_PMPCFG0:    pmpcfg0    <= wdata;
                    `CSR_PMPADDR0:   pmpaddr0   <= wdata;
                    `CSR_PMPADDR1:   pmpaddr1   <= wdata;
                    `CSR_PMPADDR2:   pmpaddr2   <= wdata;
                    `CSR_PMPADDR3:   pmpaddr3   <= wdata;
                    `CSR_SSTATUS:    sstatus    <= wdata;
                    `CSR_SIE:        sie        <= wdata;
                    `CSR_STVEC:      stvec      <= wdata;
                    `CSR_SSCRATCH:   sscratch   <= wdata;
                    `CSR_SEPC:       sepc       <= wdata;
                    `CSR_SCAUSE:     scause     <= wdata;
                    `CSR_STVAL:      stval      <= wdata;
                    `CSR_SIP:        sip        <= wdata;
                    `CSR_SATP:       satp       <= wdata;
                    `CSR_SCOUNTEREN: scounteren <= wdata;
                endcase
            end
        end
    end

endmodule
