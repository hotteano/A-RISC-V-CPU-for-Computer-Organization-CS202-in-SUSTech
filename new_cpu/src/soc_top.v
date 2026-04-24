//============================================================================
// SoC Top - RISC-V SoC with BRAM + Peripherals
// All submodules instantiated and wired (functionality TBD in some modules)
//============================================================================
`include "defines.vh"

module soc_top (
    input  wire        clk,
    input  wire        rst_n,

    // UART
    output wire        uart_tx,
    input  wire        uart_rx,

    // LED
    output wire [7:0]  led,

    // VGA
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs,

    // PS/2 Keyboard
    input  wire        ps2_clk,
    input  wire        ps2_data
);

    //========================================================================
    // CPU Core
    //========================================================================
    wire [31:0] imem_addr;
    wire [31:0] imem_data;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire        dmem_re;
    wire [3:0]  dmem_wstrb;
    wire        imem_re;
    wire        imem_ready;
    wire        dmem_ready;

    // Interrupt / fault wires (connected directly to PLIC/CLINT outputs)
    wire        cpu_pmp_fault;
    wire        cpu_pf_inst;
    wire        cpu_pf_load;
    wire        cpu_pf_store;

    riscv_cpu_top u_cpu (
        .clk             (clk),
        .rst_n           (rst_n),
        .imem_addr       (imem_addr),
        .imem_data       (imem_data),
        .imem_re         (imem_re),
        .imem_ready      (imem_ready),
        .dmem_addr       (dmem_addr),
        .dmem_wdata      (dmem_wdata),
        .dmem_rdata      (dmem_rdata),
        .dmem_we         (dmem_we),
        .dmem_re         (dmem_re),
        .dmem_wstrb      (dmem_wstrb),
        .dmem_ready      (dmem_ready),
        .plic_meip       (plic_meip),
        .plic_seip       (plic_seip),
        .clint_mtip      (clint_mtip),
        .clint_msip      (clint_msip),
        .page_fault_inst (cpu_pf_inst),
        .page_fault_load (cpu_pf_load),
        .page_fault_store(cpu_pf_store),
        .pmp_fault       (cpu_pmp_fault),
        .csr_mstatus     (cpu_mstatus),
        .cpu_priv_mode   (cpu_priv_mode)
    );

    // Exported CSR signals for MMU
    wire [31:0] cpu_mstatus;
    wire [1:0]  cpu_priv_mode;

    //========================================================================
    // Bootloader (optional boot ROM before switching to I_BRam)
    //========================================================================
    wire [31:0] boot_instr;
    wire        boot_done;

    bootloader u_bootloader (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (imem_addr),
        .data     (boot_instr),
        .boot_done(boot_done),
        .cpu_ready(1'b1)
    );

    //========================================================================
    // Instruction BRAM (16KB, Harvard structure)
    //========================================================================
    wire [31:0] icache_mem_addr;
    wire [31:0] icache_mem_rdata;
    wire        icache_mem_re;
    wire        icache_mem_ready = 1'b1;  // BRAM combinational read
    wire [31:0] icache_cpu_rdata;
    wire        icache_cpu_ready;

    icache u_icache (
        .clk        (clk),
        .rst_n      (rst_n),
        .cpu_addr   (imem_addr),
        .cpu_rdata  (icache_cpu_rdata),
        .cpu_re     (imem_re),
        .cpu_ready  (icache_cpu_ready),
        .mem_addr   (icache_mem_addr),
        .mem_rdata  (icache_mem_rdata),
        .mem_re     (icache_mem_re),
        .mem_ready  (icache_mem_ready)
    );

    I_BRam #(
        .ADDR_WIDTH(14),    // 16KB
        .INIT_FILE ("")
    ) u_i_bram (
        .clk    (clk),
        .rst_n  (rst_n),
        // Port A: instruction fetch via I-Cache
        .addr_a (icache_mem_addr),
        .dout_a (icache_mem_rdata),
        // Port B: for programming / loading
        .we_b   (1'b0),
        .addr_b (32'd0),
        .din_b  (32'd0),
        .be_b   (4'b0)
    );

    // Instruction source mux: bootloader during boot, then I-Cache
    assign imem_data  = boot_done ? icache_cpu_rdata : boot_instr;
    assign imem_ready = boot_done ? icache_cpu_ready : 1'b1;

    //========================================================================
    // Data Path: CPU -> D-MMU -> D-Cache -> Bus -> Peripherals
    //========================================================================

    // D-MMU
    wire [31:0] dmmu_paddr;
    wire        dmmu_ready;
    wire [31:0] dmmu_pt_addr;
    wire        dmmu_pt_re;
    wire        dmmu_pf_load;
    wire        dmmu_pf_store;

    mmu u_d_mmu (
        .clk             (clk),
        .rst_n           (rst_n),
        .vaddr           (dmem_addr),
        .paddr           (dmmu_paddr),
        .req             (dmem_we || dmem_re),
        .ready           (dmmu_ready),
        .satp            (32'd0),           // Bare mode for now; wire to CPU satp later
        .priv_mode       (cpu_priv_mode),
        .mstatus_mprv    (cpu_mstatus[`MSTATUS_MPRV]),
        .mstatus_sum     (cpu_mstatus[`MSTATUS_SUM]),
        .mstatus_mxr     (cpu_mstatus[`MSTATUS_MXR]),
        .pt_addr         (dmmu_pt_addr),
        .pt_rdata        (dbram_pt_rdata),
        .pt_re           (dmmu_pt_re),
        .pt_ready        (1'b1),
        .page_fault_inst (),
        .page_fault_load (dmmu_pf_load),
        .page_fault_store(dmmu_pf_store),
        .is_inst         (1'b0),
        .is_write        (dmem_we)
    );

    // D-Cache
    wire [31:0] dcache_mem_addr;
    wire [31:0] dcache_mem_wdata;
    wire [31:0] dcache_mem_rdata;
    wire        dcache_mem_we;
    wire        dcache_mem_re;
    wire [3:0]  dcache_mem_wstrb;
    wire        dcache_mem_ready = 1'b1;  // combinational peripheral read
    wire [31:0] dcache_cpu_rdata;
    wire        dcache_cpu_ready;

    dcache u_dcache (
        .clk        (clk),
        .rst_n      (rst_n),
        .cpu_addr   (dmmu_paddr),
        .cpu_wdata  (dmem_wdata),
        .cpu_rdata  (dcache_cpu_rdata),
        .cpu_we     (dmem_we),
        .cpu_re     (dmem_re),
        .cpu_ready  (dcache_cpu_ready),
        .cpu_wstrb  (dmem_wstrb),
        .mem_addr   (dcache_mem_addr),
        .mem_wdata  (dcache_mem_wdata),
        .mem_rdata  (dcache_mem_rdata),
        .mem_we     (dcache_mem_we),
        .mem_re     (dcache_mem_re),
        .mem_wstrb  (dcache_mem_wstrb),
        .mem_ready  (dcache_mem_ready)
    );

    // PMP on data path
    pmp_unit u_pmp (
        .clk       (clk),
        .rst_n     (rst_n),
        .pmpcfg0   (32'd0),   // wire to CSR pmpcfg0 later
        .pmpaddr0  (32'd0),
        .pmpaddr1  (32'd0),
        .pmpaddr2  (32'd0),
        .pmpaddr3  (32'd0),
        .addr      (dmmu_paddr),
        .priv_mode (cpu_priv_mode),
        .is_write  (dmem_we),
        .is_exec   (1'b0),
        .pmp_fault (cpu_pmp_fault)
    );

    // Combine MMU + Cache ready for CPU
    assign dmem_ready = dmmu_ready && dcache_cpu_ready;
    assign dmem_rdata = dcache_cpu_rdata;
    assign cpu_pf_load  = dmmu_pf_load;
    assign cpu_pf_store = dmmu_pf_store;
    assign cpu_pf_inst  = 1'b0;

    // Physical address for bus decoding
    wire [31:0] bus_addr = dcache_mem_addr;

    //========================================================================
    // Data Bus Address Decode (physical addresses)
    //========================================================================
    wire sel_dbram = (bus_addr >= 32'h0000_0000 && bus_addr < 32'h0000_4000);
    wire sel_clint = (bus_addr >= `CLINT_BASE_ADDR && bus_addr < `CLINT_BASE_ADDR + `CLINT_SIZE);
    wire sel_plic  = (bus_addr >= `PLIC_BASE_ADDR  && bus_addr < `PLIC_BASE_ADDR  + `PLIC_SIZE);
    wire sel_uart  = (bus_addr >= 32'h1000_0000 && bus_addr < 32'h1000_1000);
    wire sel_led   = (bus_addr >= 32'h1000_1000 && bus_addr < 32'h1000_2000);
    wire sel_vga   = (bus_addr >= 32'h1000_3000 && bus_addr < 32'h1000_4000);
    wire sel_ps2   = (bus_addr >= 32'h1000_4000 && bus_addr < 32'h1000_5000);
    wire sel_dma   = (bus_addr >= 32'h1000_5000 && bus_addr < 32'h1000_6000);

    //========================================================================
    // Data BRAM (16KB)
    //========================================================================
    wire [31:0] dbram_dout;
    wire [31:0] dbram_pt_rdata;

    D_BRam #(
        .ADDR_WIDTH(14),    // 16KB
        .INIT_FILE ("")
    ) u_d_bram (
        .clk    (clk),
        .rst_n  (rst_n),
        // Port A: CPU data access via D-Cache
        .addr_a (bus_addr),
        .dout_a (dbram_dout),
        .din_a  (dcache_mem_wdata),
        .we_a   (dcache_mem_we && sel_dbram),
        .be_a   (dcache_mem_wstrb),
        .re_a   (dcache_mem_re && sel_dbram),
        // Port B: MMU page table walk
        .addr_b (dmmu_pt_addr),
        .dout_b (dbram_pt_rdata),
        .din_b  (32'd0),
        .we_b   (1'b0),
        .be_b   (4'b0)
    );

    //========================================================================
    // Peripheral IRQ wires (to PLIC)
    //========================================================================
    wire uart_irq;
    wire ps2_irq;
    wire dma_irq;

    //========================================================================
    // CLINT (Core Local Interruptor)
    //========================================================================
    wire [31:0] clint_rdata;
    wire        clint_ready;
    wire [63:0] clint_mtime;
    wire [63:0] clint_mtimecmp;
    wire        clint_mtip;
    wire        clint_msip;

    clint u_clint (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (dcache_mem_addr),
        .wdata    (dcache_mem_wdata),
        .rdata    (clint_rdata),
        .we       (dcache_mem_we && sel_clint),
        .re       (dcache_mem_re && sel_clint),
        .ready    (clint_ready),
        .mtime    (clint_mtime),
        .mtimecmp (clint_mtimecmp),
        .mtip     (clint_mtip),
        .msip     (clint_msip)
    );

    //========================================================================
    // PLIC (Platform Level Interrupt Controller)
    //========================================================================
    wire [31:0] plic_rdata;
    wire        plic_ready;
    wire        plic_meip;
    wire        plic_seip;

    // IRQ mapping: bit0=uart, bit1=ps2, bit4=dma (arbitrary mapping)
    wire [31:0] plic_irq_src = {27'd0, dma_irq, 3'd0, ps2_irq, uart_irq};

    plic u_plic (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (dcache_mem_addr),
        .wdata    (dcache_mem_wdata),
        .rdata    (plic_rdata),
        .we       (dcache_mem_we && sel_plic),
        .re       (dcache_mem_re && sel_plic),
        .ready    (plic_ready),
        .irq_src  (plic_irq_src),
        .meip     (plic_meip),
        .seip     (plic_seip)
    );

    //========================================================================
    // UART Controller
    //========================================================================
    wire [31:0] uart_rdata;

    uart_controller u_uart (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (dcache_mem_addr),
        .wdata (dcache_mem_wdata),
        .rdata (uart_rdata),
        .we    (dcache_mem_we && sel_uart),
        .re    (dcache_mem_re && sel_uart),
        .ready (),
        .tx    (uart_tx),
        .rx    (uart_rx),
        .irq   (uart_irq)
    );

    //========================================================================
    // LED Controller
    //========================================================================
    wire [31:0] led_rdata;

    led_controller u_led (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (dcache_mem_addr),
        .wdata (dcache_mem_wdata),
        .rdata (led_rdata),
        .we    (dcache_mem_we && sel_led),
        .re    (dcache_mem_re && sel_led),
        .ready (),
        .led   (led)
    );

    //========================================================================
    // VGA Controller
    //========================================================================
    wire [31:0] vga_rdata;

    vga_controller u_vga (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (dcache_mem_addr),
        .wdata (dcache_mem_wdata),
        .rdata (vga_rdata),
        .we    (dcache_mem_we && sel_vga),
        .re    (dcache_mem_re && sel_vga),
        .ready (),
        .vga_r (vga_r),
        .vga_g (vga_g),
        .vga_b (vga_b),
        .vga_hs(vga_hs),
        .vga_vs(vga_vs)
    );

    //========================================================================
    // PS/2 Controller
    //========================================================================
    wire [31:0] ps2_rdata;

    ps2_controller u_ps2 (
        .clk     (clk),
        .rst_n   (rst_n),
        .addr    (dcache_mem_addr),
        .wdata   (dcache_mem_wdata),
        .rdata   (ps2_rdata),
        .we      (dcache_mem_we && sel_ps2),
        .re      (dcache_mem_re && sel_ps2),
        .ready   (),
        .ps2_clk (ps2_clk),
        .ps2_data(ps2_data),
        .irq     (ps2_irq)
    );

    //========================================================================
    // DMA Controller (control register interface only)
    //========================================================================
    wire [31:0] dma_rdata;
    wire        dma_ready;
    wire        dma_done;
    wire        dma_irq;

    dma_controller u_dma (
        .clk        (clk),
        .rst_n      (rst_n),
        .ctrl_addr  (dcache_mem_addr),
        .ctrl_wdata (dcache_mem_wdata),
        .ctrl_rdata (dma_rdata),
        .ctrl_we    (dcache_mem_we && sel_dma),
        .ctrl_re    (dcache_mem_re && sel_dma),
        .ctrl_ready (dma_ready),
        // DMA bus master interface (unconnected for now)
        .dma_addr   (),
        .dma_wdata  (),
        .dma_rdata  (32'd0),
        .dma_we     (),
        .dma_re     (),
        .dma_ready  (1'b0),
        .dma_start  (1'b0),
        .dma_done   (dma_done),
        .dma_irq    (dma_irq)
    );

    //========================================================================
    // Bus Read Data Mux (feeds D-Cache mem_rdata on miss)
    //========================================================================
    always @(*) begin
        if      (sel_dbram) dcache_mem_rdata = dbram_dout;
        else if (sel_clint) dcache_mem_rdata = clint_rdata;
        else if (sel_plic ) dcache_mem_rdata = plic_rdata;
        else if (sel_uart ) dcache_mem_rdata = uart_rdata;
        else if (sel_led  ) dcache_mem_rdata = led_rdata;
        else if (sel_vga  ) dcache_mem_rdata = vga_rdata;
        else if (sel_ps2  ) dcache_mem_rdata = ps2_rdata;
        else if (sel_dma  ) dcache_mem_rdata = dma_rdata;
        else                dcache_mem_rdata = 32'h0;
    end

endmodule
