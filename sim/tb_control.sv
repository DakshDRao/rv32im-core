// ============================================================
//  tb_control.sv  -  Self-Checking Testbench for control.sv
//
//  Strategy: encode real RISC-V instruction words, feed only
//  {opcode, funct3, funct7[5]} to the DUT, and verify every
//  control output is exactly right for that instruction.
//
//  Test groups:
//    A. R-type    - all 10 operations (ADD,SUB,SLL,SLT,SLTU,
//                   XOR,SRL,SRA,OR,AND)  funct7 variants
//    B. I-type ALU - all 9 variants incl. SRLI vs SRAI
//    C. Loads     - LB LH LW LBU LHU  (funct3 forwarded)
//    D. Stores    - SB SH SW
//    E. Branches  - BEQ BNE BLT BGE BLTU BGEU
//    F. JAL / JALR
//    G. LUI / AUIPC
//    H. FENCE / SYSTEM  (must be NOP)
//    I. Mutual exclusivity - at most one of {branch,jump,jalr}
// ============================================================

`timescale 1ns/1ps

module tb_control;

    // ── DUT Ports ─────────────────────────────────────────────
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic       funct7_5;

    logic        reg_write;
    logic        alu_src;
    logic [3:0]  alu_op;
    logic        mem_write;
    logic [2:0]  mem_funct3;
    logic [1:0]  wb_sel;
    logic        branch, jump, jalr;
    logic [2:0]  imm_sel;
    logic        auipc_op;

    // ── DUT ───────────────────────────────────────────────────
    control dut (.*);

    // ── Counters ──────────────────────────────────────────────
    int pass_count = 0;
    int fail_count = 0;

    // ── Constants mirrored from control.sv ────────────────────
    // ALU ops
    localparam [3:0]
        ALU_ADD=4'd0, ALU_SUB=4'd1, ALU_AND=4'd2, ALU_OR=4'd3,
        ALU_XOR=4'd4, ALU_SLL=4'd5, ALU_SRL=4'd6, ALU_SRA=4'd7,
        ALU_SLT=4'd8, ALU_SLTU=4'd9;
    // Imm sel
    localparam [2:0]
        IMM_I=3'd0, IMM_S=3'd1, IMM_B=3'd2, IMM_U=3'd3, IMM_J=3'd4;
    // WB sel
    localparam [1:0]
        WB_ALU=2'b00, WB_MEM=2'b01, WB_PC4=2'b10, WB_IMM=2'b11;
    // Opcodes
    localparam [6:0]
        OP_R=7'b0110011, OP_I_ALU=7'b0010011, OP_LOAD=7'b0000011,
        OP_STORE=7'b0100011, OP_BRANCH=7'b1100011, OP_JAL=7'b1101111,
        OP_JALR=7'b1100111, OP_LUI=7'b0110111, OP_AUIPC=7'b0010111,
        OP_FENCE=7'b0001111, OP_SYSTEM=7'b1110011;

    // ─────────────────────────────────────────────────────────
    //  Check Task - tests one signal at a time
    // ─────────────────────────────────────────────────────────
    task automatic check(
        input string  test_name,
        input [31:0]  got,
        input [31:0]  exp
    );
        if (got !== exp) begin
            $display("  FAIL  %-45s | got=%0d  exp=%0d", test_name, got, exp);
            fail_count++;
        end else begin
            $display("  PASS  %-45s | %0d", test_name, got);
            pass_count++;
        end
    endtask

    // ── Apply inputs and wait for combinational settle ─────────
    task automatic apply(
        input [6:0] op,
        input [2:0] f3,
        input       f7_5
    );
        opcode   = op;
        funct3   = f3;
        funct7_5 = f7_5;
        #2;
    endtask

    // ── Full-bundle check for most common signals ──────────────
    task automatic check_bundle(
        input string  instr_name,
        input         exp_rw,      // reg_write
        input         exp_src,     // alu_src
        input [3:0]   exp_aop,     // alu_op
        input         exp_mw,      // mem_write
        input [1:0]   exp_wb,      // wb_sel
        input         exp_br,      // branch
        input         exp_jmp,     // jump
        input         exp_jalr,    // jalr
        input [2:0]   exp_imm,     // imm_sel
        input         exp_auipc    // auipc_op
    );
        check({instr_name, " reg_write"}, {31'b0,reg_write},  {31'b0,exp_rw});
        check({instr_name, " alu_src"},   {31'b0,alu_src},    {31'b0,exp_src});
        check({instr_name, " alu_op"},    {28'b0,alu_op},     {28'b0,exp_aop});
        check({instr_name, " mem_write"}, {31'b0,mem_write},  {31'b0,exp_mw});
        check({instr_name, " wb_sel"},    {30'b0,wb_sel},     {30'b0,exp_wb});
        check({instr_name, " branch"},    {31'b0,branch},     {31'b0,exp_br});
        check({instr_name, " jump"},      {31'b0,jump},       {31'b0,exp_jmp});
        check({instr_name, " jalr"},      {31'b0,jalr},       {31'b0,exp_jalr});
        check({instr_name, " imm_sel"},   {29'b0,imm_sel},    {29'b0,exp_imm});
        check({instr_name, " auipc_op"},  {31'b0,auipc_op},   {31'b0,exp_auipc});
    endtask

    // ─────────────────────────────────────────────────────────
    //  Main Test Sequence
    // ─────────────────────────────────────────────────────────
    initial begin
        $display("\n========================================");
        $display("  Control Unit Testbench - RV32I");
        $display("========================================\n");

        // ══════════════════════════════════════════════════════
        //  A. R-TYPE  (opcode=0110011)
        //     reg_write=1, alu_src=0, wb=ALU, no mem, no branch
        // ══════════════════════════════════════════════════════
        $display("--- A: R-type ---");

        apply(OP_R, 3'b000, 1'b0);  // ADD
        check_bundle("ADD",  1,0,ALU_ADD, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_R, 3'b000, 1'b1);  // SUB  (funct7[5]=1)
        check_bundle("SUB",  1,0,ALU_SUB, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_R, 3'b001, 1'b0);  // SLL
        check_bundle("SLL",  1,0,ALU_SLL, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_R, 3'b010, 1'b0);  // SLT
        check_bundle("SLT",  1,0,ALU_SLT, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_R, 3'b011, 1'b0);  // SLTU
        check_bundle("SLTU", 1,0,ALU_SLTU,0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_R, 3'b100, 1'b0);  // XOR
        check_bundle("XOR",  1,0,ALU_XOR, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_R, 3'b101, 1'b0);  // SRL  (funct7[5]=0)
        check_bundle("SRL",  1,0,ALU_SRL, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_R, 3'b101, 1'b1);  // SRA  (funct7[5]=1)
        check_bundle("SRA",  1,0,ALU_SRA, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_R, 3'b110, 1'b0);  // OR
        check_bundle("OR",   1,0,ALU_OR,  0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_R, 3'b111, 1'b0);  // AND
        check_bundle("AND",  1,0,ALU_AND, 0,WB_ALU, 0,0,0,IMM_I,0);

        // ══════════════════════════════════════════════════════
        //  B. I-TYPE ALU  (opcode=0010011)
        //     alu_src=1 (uses immediate), wb=ALU
        // ══════════════════════════════════════════════════════
        $display("\n--- B: I-type ALU ---");

        apply(OP_I_ALU, 3'b000, 1'b0);  // ADDI
        check_bundle("ADDI",  1,1,ALU_ADD, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_I_ALU, 3'b001, 1'b0);  // SLLI
        check_bundle("SLLI",  1,1,ALU_SLL, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_I_ALU, 3'b010, 1'b0);  // SLTI
        check_bundle("SLTI",  1,1,ALU_SLT, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_I_ALU, 3'b011, 1'b0);  // SLTIU
        check_bundle("SLTIU", 1,1,ALU_SLTU,0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_I_ALU, 3'b100, 1'b0);  // XORI
        check_bundle("XORI",  1,1,ALU_XOR, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_I_ALU, 3'b101, 1'b0);  // SRLI  (funct7[5]=0)
        check_bundle("SRLI",  1,1,ALU_SRL, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_I_ALU, 3'b101, 1'b1);  // SRAI  (funct7[5]=1)
        check_bundle("SRAI",  1,1,ALU_SRA, 0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_I_ALU, 3'b110, 1'b0);  // ORI
        check_bundle("ORI",   1,1,ALU_OR,  0,WB_ALU, 0,0,0,IMM_I,0);

        apply(OP_I_ALU, 3'b111, 1'b0);  // ANDI
        check_bundle("ANDI",  1,1,ALU_AND, 0,WB_ALU, 0,0,0,IMM_I,0);

        // ══════════════════════════════════════════════════════
        //  C. LOADS  (opcode=0000011)
        //     alu_src=1 (addr=rs1+imm), wb=MEM, funct3 forwarded
        // ══════════════════════════════════════════════════════
        $display("\n--- C: Loads ---");

        apply(OP_LOAD, 3'b000, 1'b0);   // LB
        check_bundle("LB",   1,1,ALU_ADD, 0,WB_MEM, 0,0,0,IMM_I,0);
        check("LB  mem_funct3", {29'b0,mem_funct3}, {29'b0,3'b000});

        apply(OP_LOAD, 3'b001, 1'b0);   // LH
        check_bundle("LH",   1,1,ALU_ADD, 0,WB_MEM, 0,0,0,IMM_I,0);
        check("LH  mem_funct3", {29'b0,mem_funct3}, {29'b0,3'b001});

        apply(OP_LOAD, 3'b010, 1'b0);   // LW
        check_bundle("LW",   1,1,ALU_ADD, 0,WB_MEM, 0,0,0,IMM_I,0);
        check("LW  mem_funct3", {29'b0,mem_funct3}, {29'b0,3'b010});

        apply(OP_LOAD, 3'b100, 1'b0);   // LBU
        check("LBU mem_funct3", {29'b0,mem_funct3}, {29'b0,3'b100});

        apply(OP_LOAD, 3'b101, 1'b0);   // LHU
        check("LHU mem_funct3", {29'b0,mem_funct3}, {29'b0,3'b101});

        // ══════════════════════════════════════════════════════
        //  D. STORES  (opcode=0100011)
        //     alu_src=1, mem_write=1, no reg_write, imm=S
        // ══════════════════════════════════════════════════════
        $display("\n--- D: Stores ---");

        apply(OP_STORE, 3'b000, 1'b0);  // SB
        check_bundle("SB", 0,1,ALU_ADD, 1,WB_ALU, 0,0,0,IMM_S,0);
        check("SB  mem_funct3", {29'b0,mem_funct3}, {29'b0,3'b000});

        apply(OP_STORE, 3'b001, 1'b0);  // SH
        check_bundle("SH", 0,1,ALU_ADD, 1,WB_ALU, 0,0,0,IMM_S,0);

        apply(OP_STORE, 3'b010, 1'b0);  // SW
        check_bundle("SW", 0,1,ALU_ADD, 1,WB_ALU, 0,0,0,IMM_S,0);

        // ══════════════════════════════════════════════════════
        //  E. BRANCHES  (opcode=1100011)
        //     branch=1, no reg_write, no mem, imm=B
        // ══════════════════════════════════════════════════════
        $display("\n--- E: Branches ---");

        apply(OP_BRANCH, 3'b000, 1'b0);  // BEQ
        check_bundle("BEQ",  0,0,ALU_ADD, 0,WB_ALU, 1,0,0,IMM_B,0);

        apply(OP_BRANCH, 3'b001, 1'b0);  // BNE
        check_bundle("BNE",  0,0,ALU_ADD, 0,WB_ALU, 1,0,0,IMM_B,0);

        apply(OP_BRANCH, 3'b100, 1'b0);  // BLT
        check_bundle("BLT",  0,0,ALU_ADD, 0,WB_ALU, 1,0,0,IMM_B,0);

        apply(OP_BRANCH, 3'b101, 1'b0);  // BGE
        check_bundle("BGE",  0,0,ALU_ADD, 0,WB_ALU, 1,0,0,IMM_B,0);

        apply(OP_BRANCH, 3'b110, 1'b0);  // BLTU
        check_bundle("BLTU", 0,0,ALU_ADD, 0,WB_ALU, 1,0,0,IMM_B,0);

        apply(OP_BRANCH, 3'b111, 1'b0);  // BGEU
        check_bundle("BGEU", 0,0,ALU_ADD, 0,WB_ALU, 1,0,0,IMM_B,0);

        // ══════════════════════════════════════════════════════
        //  F. JAL / JALR
        // ══════════════════════════════════════════════════════
        $display("\n--- F: JAL / JALR ---");

        apply(OP_JAL, 3'b000, 1'b0);    // JAL
        check_bundle("JAL",  1,0,ALU_ADD, 0,WB_PC4, 0,1,0,IMM_J,0);

        apply(OP_JALR, 3'b000, 1'b0);   // JALR
        check_bundle("JALR", 1,1,ALU_ADD, 0,WB_PC4, 0,0,1,IMM_I,0);

        // ══════════════════════════════════════════════════════
        //  G. LUI / AUIPC
        // ══════════════════════════════════════════════════════
        $display("\n--- G: LUI / AUIPC ---");

        apply(OP_LUI, 3'b000, 1'b0);    // LUI
        check_bundle("LUI",   1,0,ALU_ADD, 0,WB_IMM, 0,0,0,IMM_U,0);
        check("LUI auipc_op=0", {31'b0,auipc_op}, 32'd0);

        apply(OP_AUIPC, 3'b000, 1'b0);  // AUIPC
        check_bundle("AUIPC", 1,1,ALU_ADD, 0,WB_ALU, 0,0,0,IMM_U,1);
        check("AUIPC auipc_op=1", {31'b0,auipc_op}, 32'd1);

        // ══════════════════════════════════════════════════════
        //  H. FENCE / SYSTEM  (must behave as NOP)
        //     reg_write=0, mem_write=0, branch=0, jump=0, jalr=0
        // ══════════════════════════════════════════════════════
        $display("\n--- H: FENCE / SYSTEM (NOP) ---");

        apply(OP_FENCE, 3'b000, 1'b0);
        check("FENCE reg_write=0",  {31'b0,reg_write}, 32'd0);
        check("FENCE mem_write=0",  {31'b0,mem_write}, 32'd0);
        check("FENCE branch=0",     {31'b0,branch},    32'd0);
        check("FENCE jump=0",       {31'b0,jump},      32'd0);

        apply(OP_SYSTEM, 3'b000, 1'b0);
        check("SYSTEM reg_write=0", {31'b0,reg_write}, 32'd0);
        check("SYSTEM mem_write=0", {31'b0,mem_write}, 32'd0);
        check("SYSTEM branch=0",    {31'b0,branch},    32'd0);
        check("SYSTEM jump=0",      {31'b0,jump},      32'd0);

        // ══════════════════════════════════════════════════════
        //  I. Mutual Exclusivity
        //     At most ONE of {branch, jump, jalr} can be high
        // ══════════════════════════════════════════════════════
        $display("\n--- I: Mutual exclusivity of branch/jump/jalr ---");

        // Test all 9 opcode groups
        begin
            automatic logic [6:0] opcodes[9] = '{
                OP_R, OP_I_ALU, OP_LOAD, OP_STORE, OP_BRANCH,
                OP_JAL, OP_JALR, OP_LUI, OP_AUIPC
            };
            automatic string names[9] = '{
                "R","I_ALU","LOAD","STORE","BRANCH","JAL","JALR","LUI","AUIPC"
            };
            for (int i = 0; i < 9; i++) begin
                apply(opcodes[i], 3'b000, 1'b0);
                begin
                    automatic int onehot = branch + jump + jalr;
                    check($sformatf("%-6s one-hot{br,jmp,jalr}", names[i]),
                          onehot, (opcodes[i]==OP_BRANCH || opcodes[i]==OP_JAL || opcodes[i]==OP_JALR) ? 1 : 0);
                end
            end
        end

        // ─────────────────────────────────────────────────────
        //  Final Report
        // ─────────────────────────────────────────────────────
        $display("\n========================================");
        $display("  RESULTS: %0d PASS  /  %0d FAIL", pass_count, fail_count);
        $display("========================================\n");

        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED - Control Unit is correct ***\n");
        else
            $display("  *** %0d TEST(S) FAILED ***\n", fail_count);

        $finish;
    end

    initial begin #50000; $display("TIMEOUT"); $finish; end

endmodule