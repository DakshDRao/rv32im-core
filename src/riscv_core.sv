// ============================================================
//  riscv_core.sv  -  Single-Cycle RV32I + RV32M Core (Top Level)
//  Project : Single-Cycle RISC-V Core
//  Board   : Arty A7 (Artix-7)
//
//  Changes from RV32I baseline:
//    • funct7_1 (inst[25]) extracted and wired to control
//    • alu_op wire widened from [3:0] to [4:0]
//    • mul_div is instantiated inside alu - no top-level changes
//      needed beyond the two items above
// ============================================================

module riscv_core #(
    parameter int          IMEM_DEPTH = 1024,
    parameter int          DMEM_DEPTH = 1024,
    parameter logic [31:0] BOOT_ADDR  = 32'h0000_0000,
    parameter string       IMEM_FILE  = ""
)(
    input  logic clk,
    input  logic rst
);

// ─────────────────────────────────────────────────────────────
//  Internal Signals
// ─────────────────────────────────────────────────────────────

// PC
logic [31:0] pc, pc_plus4;

// Instruction fetch
logic [31:0] instr;

// Instruction fields
logic [6:0]  opcode;
logic [4:0]  rs1_addr, rs2_addr, rd_addr;
logic [2:0]  funct3;
logic        funct7_5;
logic        funct7_1;      // inst[25] - M-extension detect

assign opcode   = instr[6:0];
assign rd_addr  = instr[11:7];
assign funct3   = instr[14:12];
assign rs1_addr = instr[19:15];
assign rs2_addr = instr[24:20];
assign funct7_1 = instr[25];   // NEW: M-ext funct7[1]
assign funct7_5 = instr[30];

// Control signals
logic        reg_write;
logic        alu_src;
logic [4:0]  alu_op;           // WIDENED: 4→5 bits
logic        mem_write;
logic [2:0]  mem_funct3;
logic [1:0]  wb_sel;
logic        branch;
logic        jump;
logic        jalr;
logic [2:0]  imm_sel;
logic        auipc_op;

// Immediate
logic [31:0] imm;

// Register file
logic [31:0] rs1_data, rs2_data;
logic [31:0] wd;

// ALU
logic [31:0] alu_a, alu_b;
logic [31:0] alu_result;
logic        alu_zero;

// Branch
logic        branch_taken;

// Data memory
logic [31:0] mem_rdata;

// ─────────────────────────────────────────────────────────────
//  PC Logic
// ─────────────────────────────────────────────────────────────
pc_logic #(
    .BOOT_ADDR(BOOT_ADDR)
) u_pc (
    .clk         (clk),
    .rst         (rst),
    .jump        (jump),
    .jalr        (jalr),
    .branch_taken(branch_taken),
    .rs1         (rs1_data),
    .imm         (imm),
    .pc          (pc),
    .pc_plus4    (pc_plus4)
);

// ─────────────────────────────────────────────────────────────
//  Instruction Memory
// ─────────────────────────────────────────────────────────────
imem #(
    .DEPTH    (IMEM_DEPTH),
    .ADDR_BITS($clog2(IMEM_DEPTH)),
    .MEM_FILE (IMEM_FILE)
) u_imem (
    .clk  (clk),
    .addr (pc),
    .instr(instr)
);

// ─────────────────────────────────────────────────────────────
//  Control Unit
// ─────────────────────────────────────────────────────────────
control u_ctrl (
    .opcode    (opcode),
    .funct3    (funct3),
    .funct7_5  (funct7_5),
    .funct7_1  (funct7_1),     // NEW
    .reg_write (reg_write),
    .alu_src   (alu_src),
    .alu_op    (alu_op),
    .mem_write (mem_write),
    .mem_funct3(mem_funct3),
    .wb_sel    (wb_sel),
    .branch    (branch),
    .jump      (jump),
    .jalr      (jalr),
    .imm_sel   (imm_sel),
    .auipc_op  (auipc_op)
);

// ─────────────────────────────────────────────────────────────
//  Immediate Generator
// ─────────────────────────────────────────────────────────────
imm_gen u_immgen (
    .instr  (instr),
    .imm_sel(imm_sel),
    .imm    (imm)
);

// ─────────────────────────────────────────────────────────────
//  Register File
// ─────────────────────────────────────────────────────────────
regfile u_regfile (
    .clk (clk),
    .we  (reg_write),
    .rs1 (rs1_addr),
    .rs2 (rs2_addr),
    .rd  (rd_addr),
    .wd  (wd),
    .rd1 (rs1_data),
    .rd2 (rs2_data)
);

// ─────────────────────────────────────────────────────────────
//  ALU Input Muxes
// ─────────────────────────────────────────────────────────────
assign alu_a = auipc_op ? pc  : rs1_data;
assign alu_b = alu_src  ? imm : rs2_data;

// ─────────────────────────────────────────────────────────────
//  ALU  (now includes mul_div internally)
// ─────────────────────────────────────────────────────────────
alu u_alu (
    .a      (alu_a),
    .b      (alu_b),
    .alu_op (alu_op),
    .result (alu_result),
    .zero   (alu_zero)
);

// ─────────────────────────────────────────────────────────────
//  Branch Unit
// ─────────────────────────────────────────────────────────────
branch_unit u_branch (
    .rs1         (rs1_data),
    .rs2         (rs2_data),
    .funct3      (funct3),
    .branch      (branch),
    .branch_taken(branch_taken)
);

// ─────────────────────────────────────────────────────────────
//  Data Memory
// ─────────────────────────────────────────────────────────────
dmem #(
    .DEPTH    (DMEM_DEPTH),
    .ADDR_BITS($clog2(DMEM_DEPTH))
) u_dmem (
    .clk   (clk),
    .addr  (alu_result),
    .wdata (rs2_data),
    .we    (mem_write),
    .funct3(mem_funct3),
    .rdata (mem_rdata)
);

// ─────────────────────────────────────────────────────────────
//  Writeback Mux
// ─────────────────────────────────────────────────────────────
writeback u_wb (
    .wb_sel    (wb_sel),
    .alu_result(alu_result),
    .mem_rdata (mem_rdata),
    .pc_plus4  (pc_plus4),
    .imm       (imm),
    .wd        (wd)
);

endmodule