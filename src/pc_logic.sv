// ============================================================
//  pc_logic.sv  -  Program Counter + Next-PC Mux  (RV32I)
//  Project : Single-Cycle RISC-V Core
//  Board   : Arty A7 (Artix-7)
//
//  Responsibilities:
//    1. Hold the current PC in a flip-flop (reset to BOOT_ADDR)
//    2. Compute all four candidate next-PC values
//    3. Select the correct one via priority mux
//    4. Expose PC+4 for JAL/JALR writeback (return address)
//
//  Next-PC priority (highest → lowest):
//    1. JALR   → (rs1 + imm) & ~32'h1   (LSB cleared per spec)
//    2. JAL    → PC + J-imm
//    3. BRANCH → PC + B-imm  (only when branch_taken=1)
//    4. Default → PC + 4
//
//  BOOT_ADDR is parameterised.
//  For Arty A7 BRAM-only build: 32'h0000_0000
//  When DDR/flash added in Phase 4: change to match memory map.
//
//  Reference: RISC-V ISA Vol.1 §2.5, §2.6
// ============================================================

module pc_logic #(
    parameter logic [31:0] BOOT_ADDR = 32'h0000_0000
)(
    input  logic        clk,
    input  logic        rst,          // synchronous active-high reset

    // ── Control signals (from control.sv) ───────────────────
    input  logic        jump,         // 1 = JAL
    input  logic        jalr,         // 1 = JALR
    input  logic        branch_taken, // 1 = branch condition true

    // ── Data inputs ─────────────────────────────────────────
    input  logic [31:0] rs1,          // rs1 value (for JALR base)
    input  logic [31:0] imm,          // sign-extended immediate (from imm_gen)

    // ── Outputs ─────────────────────────────────────────────
    output logic [31:0] pc,           // current PC → instruction memory
    output logic [31:0] pc_plus4      // PC+4 → writeback mux (JAL/JALR rd)
);

// ─────────────────────────────────────────────────────────────
//  Candidate Next-PC Values
// ─────────────────────────────────────────────────────────────

// Sequential default
logic [31:0] pc_seq;
assign pc_seq    = pc + 32'd4;

// Branch target: PC + sign_ext(B-imm)
// imm_gen already sign-extended, B-imm always even (bit0=0)
logic [31:0] pc_branch;
assign pc_branch = pc + imm;

// JAL target: PC + sign_ext(J-imm)
// Same adder expression as branch - mux selects which imm is fed in
logic [31:0] pc_jal;
assign pc_jal    = pc + imm;

// JALR target: (rs1 + imm) with LSB forced to 0 (spec §2.5)
// Forces 2-byte alignment, prevents misaligned fetch
logic [31:0] pc_jalr;
assign pc_jalr   = (rs1 + imm) & ~32'h1;

// ─────────────────────────────────────────────────────────────
//  Next-PC Mux  - priority encoded
//
//  Note: pc_branch and pc_jal use the same adder (pc + imm).
//  In the top-level, imm_gen feeds the correct immediate type
//  (B-imm for branches, J-imm for JAL) based on imm_sel from
//  control, so a single shared adder is correct.
// ─────────────────────────────────────────────────────────────
logic [31:0] next_pc;

always_comb begin : next_pc_mux
    priority if (jalr)
        next_pc = pc_jalr;
    else if (jump)
        next_pc = pc_jal;
    else if (branch_taken)
        next_pc = pc_branch;
    else
        next_pc = pc_seq;
end : next_pc_mux

// ─────────────────────────────────────────────────────────────
//  PC Register  - synchronous reset
//  On rst, PC returns to BOOT_ADDR on the next rising edge.
// ─────────────────────────────────────────────────────────────
always_ff @(posedge clk) begin : pc_reg
    if (rst)
        pc <= BOOT_ADDR;
    else
        pc <= next_pc;
end : pc_reg

// ─────────────────────────────────────────────────────────────
//  PC+4 Output
//  Driven combinationally from pc (not next_pc).
//  Used as return address by JAL and JALR:
//    JAL  x1, label  →  x1 = PC+4  (address of instruction after JAL)
//    JALR x0, x1, 0  →  returns to that saved address
// ─────────────────────────────────────────────────────────────
assign pc_plus4 = pc + 32'd4;

// ─────────────────────────────────────────────────────────────
//  Simulation Assertions
// ─────────────────────────────────────────────────────────────
// synthesis translate_off
always_ff @(posedge clk) begin
    // PC must always be 4-byte aligned in RV32I (no compressed ext)
    if (!rst && pc[1:0] !== 2'b00)
        $display("[PC WARNING] misaligned PC = %08h at time %0t", pc, $time);

    // At most one of jump/jalr should be asserted
    if (jump && jalr)
        $display("[PC WARNING] jump & jalr both asserted at time %0t", $time);
end
// synthesis translate_on

endmodule