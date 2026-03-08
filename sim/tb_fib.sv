// ============================================================
//  tb_fib.sv  -  Fibonacci Integration Test
//  Project : Single-Cycle RV32IM Core
//
//  Loads fib.mem into IMEM, runs the core, then verifies:
//    1. All 10 Fibonacci values stored correctly in DMEM
//    2. Final result register x4 = 55 (fib[9])
//    3. Loop counter x5 = 10
//
//  Expected DMEM at byte address 0x100 (word index 64):
//    index:  0   1   2   3   4   5   6    7    8    9
//    value:  1   1   2   3   5   8  13   21   34   55
// ============================================================

`timescale 1ns/1ps

module tb_fib;

    logic clk, rst;

    // ── DUT ───────────────────────────────────────────────────
    // IMEM_FILE points to compiled fib.mem
    // DMEM_DEPTH=256 words → 1KB data memory (addresses 0x000-0x3FF)
    // Fibonacci stores at 0x100 (word index 64) - safely within range
    riscv_core #(
        .IMEM_DEPTH(256),
        .DMEM_DEPTH(256),
        .BOOT_ADDR (32'h0),
        .IMEM_FILE ("C:/Users/Daksh/RISCV/riscv_core/sw/fib.mem")
    ) dut (
        .clk(clk),
        .rst(rst)
    );

    // ── Clock: 10ns period (100MHz) ───────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Pass/Fail counters ────────────────────────────────────
    int pass_count = 0;
    int fail_count = 0;

    // ── Check helper ─────────────────────────────────────────
    task automatic check(input string name,
                         input [31:0] got, exp);
        if (got !== exp) begin
            $display("  FAIL  %-40s | got=%08h (%0d)  exp=%08h (%0d)",
                     name, got, got, exp, exp);
            fail_count++;
        end else begin
            $display("  PASS  %-40s | %08h (%0d)", name, got, got);
            pass_count++;
        end
    endtask

    // ── Read a word from DMEM (by byte address) ───────────────
    function automatic [31:0] dmem_read(input int byte_addr);
        int word_idx;
        word_idx = byte_addr >> 2;
        return {dut.u_dmem.bank3[word_idx],
                dut.u_dmem.bank2[word_idx],
                dut.u_dmem.bank1[word_idx],
                dut.u_dmem.bank0[word_idx]};
    endfunction

    // ── Read integer register ─────────────────────────────────
    function automatic [31:0] xreg(input int n);
        if (n == 0) return 32'h0;
        return dut.u_regfile.regs[n];
    endfunction

    // ── Expected Fibonacci values ─────────────────────────────
    // fib[0..9] = 1,1,2,3,5,8,13,21,34,55
    int fib_exp [10] = '{1,1,2,3,5,8,13,21,34,55};

    // ── Main test ─────────────────────────────────────────────
    initial begin
        $display("\n============================================");
        $display("  Fibonacci Sequence - RV32IM Core Test");
        $display("============================================\n");

        // Reset for 2 cycles
        rst = 1;
        repeat(2) @(posedge clk);
        #1;
        rst = 0;

        // ── Run the program ───────────────────────────────────
        // Cycle budget:
        //   4 setup instructions   =  4 cycles
        //   2 initial stores       =  2 cycles
        //   8 loop iterations × 7  = 56 cycles
        //   branch + halt          =  4 cycles
        //   safety margin          = 10 cycles
        //                          = ~76 cycles total
        // We run 100 to be safe.
        $display("Running Fibonacci program (100 cycles)...\n");
        repeat(100) @(posedge clk);
        #1;

        // ── Verify DMEM results ───────────────────────────────
        $display("--- DMEM Verification (base address 0x100) ---");
        // NEW
        begin
            int addr;
            logic [31:0] got;
            string name;
            for (int i = 0; i < 10; i++) begin
                addr = 32'h100 + (i * 4);
                got  = dmem_read(addr);
                name = $sformatf("fib[%0d] @ 0x%03h", i, addr);
                check(name, got, fib_exp[i]);
            end
        end 

        // ── Verify register state ─────────────────────────────
        $display("\n--- Register Verification ---");
        check("x4 = fib[9] = 55",   xreg(4), 32'd55);
        check("x5 = loop counter=10", xreg(5), 32'd10);
        check("x1 = n = 10",         xreg(1), 32'd10);

        // ── Summary ───────────────────────────────────────────
        $display("\n============================================");
        $display("  RESULTS: %0d PASS  /  %0d FAIL",
                  pass_count, fail_count);
        $display("============================================\n");

        if (fail_count == 0) begin
            $display("  *** ALL TESTS PASSED ***");
            $display("  First 10 Fibonacci numbers computed correctly:");
            $display("  1, 1, 2, 3, 5, 8, 13, 21, 34, 55\n");
        end else begin
            $display("  *** %0d TEST(S) FAILED ***\n", fail_count);
        end

        $finish;
    end

    // ── Timeout guard ─────────────────────────────────────────
    initial begin
        #100000;
        $display("TIMEOUT - simulation exceeded limit");
        $finish;
    end

endmodule