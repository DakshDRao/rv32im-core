// ============================================================
//  imem.sv  -  Instruction Memory  (Async read, RV32I)
//  Project : Single-Cycle RISC-V Core
//  Board   : Arty A7 (Artix-7)
//
//  Single-cycle cores require combinational (async) reads so
//  that the instruction is available in the SAME cycle as the
//  PC - no fetch latency.
//
//  Synthesis: Vivado infers Distributed RAM (LUTRAM) for arrays
//  with async read ports. On XC7A35T, 18K LUTs available.
//  For larger programs switch to a 2-stage pipeline (Phase 2).
//
//  Write port: none (read-only instruction memory)
//  Read port:  combinational, word-addressed from byte addr
//
//  Init: $readmemh from MEM_FILE parameter, NOP-filled otherwise
// ============================================================

module imem #(
    parameter int    DEPTH     = 1024,
    parameter int    ADDR_BITS = 10,
    parameter string MEM_FILE  = ""
)(
    input  logic        clk,          // kept for port compatibility; unused in read
    input  logic [31:0] addr,         // byte address from PC
    output logic [31:0] instr         // instruction word - COMBINATIONAL output
);

logic [31:0] mem [0:DEPTH-1];

initial begin
    for (int i = 0; i < DEPTH; i++)
        mem[i] = 32'h0000_0013;       // NOP fill
    if (MEM_FILE != "")
        $readmemh(MEM_FILE, mem);
end

// ── Async (combinational) read ────────────────────────────────
assign instr = mem[addr[ADDR_BITS+1:2]];

// synthesis translate_off
always_comb begin
    if (addr[1:0] != 2'b00)
        $display("[IMEM WARNING] misaligned fetch addr=%08h", addr);
end
// synthesis translate_on

endmodule