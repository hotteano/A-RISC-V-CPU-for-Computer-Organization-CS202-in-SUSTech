//============================================================================
// MMU - Memory Management Unit (Sv32 page table walker)
//============================================================================
`include "defines.vh"

module mmu (
    input  wire        clk,
    input  wire        rst_n,

    // CPU interface (virtual address)
    input  wire [31:0] vaddr,
    output reg  [31:0] paddr,
    input  wire        req,
    output reg         ready,

    // SATP register
    input  wire [31:0] satp,

    // Current privilege mode
    input  wire [1:0]  priv_mode,
    input  wire        mstatus_mprv,
    input  wire        mstatus_sum,
    input  wire        mstatus_mxr,

    // Memory interface for page table walk
    output reg  [31:0] pt_addr,
    input  wire [31:0] pt_rdata,
    output reg         pt_re,
    input  wire        pt_ready,

    // Page fault outputs
    output reg         page_fault_inst,
    output reg         page_fault_load,
    output reg         page_fault_store,

    // Access type
    input  wire        is_inst,
    input  wire        is_write
);

    // SATP fields
    wire        satp_mode = satp[31];
    wire [8:0]  satp_asid = satp[30:22];
    wire [21:0] satp_ppn  = satp[21:0];

    // Sv32 address decomposition
    wire [9:0]  vpn1 = vaddr[31:22];
    wire [9:0]  vpn0 = vaddr[21:12];
    wire [11:0] page_offset = vaddr[11:0];

    // Page table walk state machine
    localparam IDLE      = 3'b000;
    localparam READ_PTE1 = 3'b001;
    localparam READ_PTE0 = 3'b010;
    localparam CHECK     = 3'b011;
    localparam FAULT     = 3'b100;
    localparam DONE      = 3'b101;

    reg [2:0] state;
    reg [31:0] pte1;
    reg [31:0] pte0;

    // Translation active only in S/U mode or when MPRV=1
    wire translation_active;
    assign translation_active = satp_mode &&
        ((priv_mode != `PRIV_M) || mstatus_mprv);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            paddr           <= 32'd0;
            ready           <= 1'b0;
            pt_addr         <= 32'd0;
            pt_re           <= 1'b0;
            page_fault_inst <= 1'b0;
            page_fault_load <= 1'b0;
            page_fault_store<= 1'b0;
            pte1            <= 32'd0;
            pte0            <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    ready           <= 1'b0;
                    page_fault_inst <= 1'b0;
                    page_fault_load <= 1'b0;
                    page_fault_store<= 1'b0;
                    if (req) begin
                        if (!translation_active) begin
                            // Bare mode: VA = PA
                            paddr <= vaddr;
                            ready <= 1'b1;
                        end else begin
                            state   <= READ_PTE1;
                            pt_addr <= {satp_ppn, 12'd0} + (vpn1 << 2);
                            pt_re   <= 1'b1;
                        end
                    end
                end
                READ_PTE1: begin
                    if (pt_ready) begin
                        pte1  <= pt_rdata;
                        pt_re <= 1'b0;
                        state <= READ_PTE0;
                        pt_addr <= {pt_rdata[29:10], 12'd0} + (vpn0 << 2);
                        pt_re <= 1'b1;
                    end
                end
                READ_PTE0: begin
                    if (pt_ready) begin
                        pte0  <= pt_rdata;
                        pt_re <= 1'b0;
                        state <= CHECK;
                    end
                end
                CHECK: begin
                    // Check PTE validity and permissions
                    if (!pte0[`PTE_V] || (!pte0[`PTE_R] && pte0[`PTE_W])) begin
                        state <= FAULT;
                    end else if (!pte0[`PTE_R] && pte0[`PTE_X]) begin
                        // Pointer to next level
                        state <= FAULT;  // Only 2 levels in Sv32
                    end else begin
                        // Leaf PTE
                        if (is_inst && !pte0[`PTE_X])
                            state <= FAULT;
                        else if (is_write && !pte0[`PTE_W])
                            state <= FAULT;
                        else if (!is_inst && !is_write && !pte0[`PTE_R] && !mstatus_mxr)
                            state <= FAULT;
                        else if (pte0[`PTE_U] && priv_mode == `PRIV_S && !mstatus_sum)
                            state <= FAULT;
                        else if (!pte0[`PTE_U] && priv_mode == `PRIV_U)
                            state <= FAULT;
                        else begin
                            paddr <= {pte0[29:10], page_offset};
                            ready <= 1'b1;
                            state <= IDLE;
                        end
                    end
                end
                FAULT: begin
                    if (is_inst)
                        page_fault_inst <= 1'b1;
                    else if (is_write)
                        page_fault_store<= 1'b1;
                    else
                        page_fault_load <= 1'b1;
                    ready <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
