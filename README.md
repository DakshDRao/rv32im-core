# RV32IM Single-Cycle Core

A fully verified single-cycle RISC-V processor implementing the **RV32IM** instruction set architecture, synthesizable on the **Digilent Arty A7** (Xilinx Artix-7 XC7A35T) FPGA.

Built from scratch in SystemVerilog as Phase 1 of a multi-phase microcontroller project.

---

## Features

- ✅ Full **RV32I** base integer instruction set
- ✅ **RV32M** multiply/divide extension (MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU)
- ✅ All 6 branch conditions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
- ✅ JAL / JALR with correct return address writeback
- ✅ LUI / AUIPC
- ✅ Byte-granular loads and stores (LB, LH, LW, LBU, LHU, SB, SH, SW)
- ✅ IEEE 754-compliant divide-by-zero and overflow handling in M extension
- ✅ Synchronous reset, boot address parameterised
- ✅ `$readmemh` instruction memory initialisation
- ✅ Fibonacci sequence verified end-to-end on the core

---

## Architecture

Single-cycle, in-order. Every instruction completes in exactly one clock cycle.

```
         ┌──────────┐  pc   ┌──────┐  instr  ┌─────────┐
         │ PC Logic ├──────►│ IMEM ├────────►│ Control │
         └────┬─────┘       └──────┘    │    └────┬────┘
              │ pc, pc_plus4            │         │ control signals
              │                         └───►┌────▼────┐
              │                              │ ImmGen  │
              │              ┌─────────┐     └────┬────┘
              │   rs1,rs2 ◄──┤ RegFile │◄─── wd   │ imm
              │              └────┬────┘          │
              │          rs1,rs2  │                │
              │        ┌──────────▼───┐            │
              └───────►│  ALU + MulDiv│◄───────────┘
           (auipc)     └──────┬───────┘
                              │ alu_result
                     ┌────────▼────────┐
                     │   Data Memory   │
                     └────────┬────────┘
                              │
                     ┌────────▼────────┐
                     │    Writeback    │──► wd → RegFile
                     └─────────────────┘
```

---

## File Structure

```
riscv_core/
│
├── src/                        # Design sources
│   ├── riscv_core.sv           # Top-level integration
│   ├── alu.sv                  # ALU (RV32I + M-ext dispatch)
│   ├── mul_div.sv              # M-extension MUL/DIV unit
│   ├── control.sv              # Main decoder
│   ├── regfile.sv              # 32×32 integer register file
│   ├── imm_gen.sv              # Immediate generator (I/S/B/U/J)
│   ├── branch_unit.sv          # Branch condition evaluator
│   ├── pc_logic.sv             # PC register + next-PC mux
│   ├── imem.sv                 # Instruction memory (async read)
│   ├── dmem.sv                 # Data memory (byte-enable)
│   └── writeback.sv            # Writeback mux
│
├── sim/                        # Testbenches
│   ├── tb_riscv_core.sv        # Integration testbench (P1-P7)
│   ├── tb_alu.sv               # ALU unit test
│   ├── tb_mul_div.sv           # M-extension unit test
│   ├── tb_regfile.sv           # Register file unit test
│   ├── tb_control.sv           # Control unit test
│   ├── tb_branch_unit.sv       # Branch unit test
│   ├── tb_imm_gen.sv           # Immediate generator unit test
│   ├── tb_pc_logic.sv          # PC logic unit test
│   ├── tb_imem.sv              # Instruction memory unit test
│   ├── tb_dmem.sv              # Data memory unit test
│   ├── tb_writeback.sv         # Writeback mux unit test
│   └── tb_fib.sv               # Fibonacci end-to-end test
│
├── sw/                         # Software (assembly programs)
│   ├── fib.S                   # Fibonacci sequence (first 10 terms)
│   ├── test.S                  # Basic ALU smoke test
│   ├── link.ld                 # Linker script (boot at 0x00000000)
│   └── Makefile                # Build system
│
└── scripts/
    └── bin2mem.py              # ELF binary → $readmemh .mem converter
```

---

## Test Coverage

| Testbench | Tests | Coverage |
|---|---|---|
| `tb_alu.sv` | ALU unit | All 10 RV32I operations |
| `tb_mul_div.sv` | M-ext unit | All 8 MUL/DIV ops, div-by-zero, overflow |
| `tb_regfile.sv` | Register file | x0 hardwire, write-before-read |
| `tb_control.sv` | Control unit | All opcodes, funct3, funct7 |
| `tb_branch_unit.sv` | Branch unit | All 6 conditions, taken/not-taken |
| `tb_imm_gen.sv` | Immediate gen | All 5 formats (I/S/B/U/J) |
| `tb_pc_logic.sv` | PC logic | JAL, JALR, branch, sequential |
| `tb_imem.sv` | Instr memory | Fetch, NOP fill, misalign warning |
| `tb_dmem.sv` | Data memory | All load/store widths, byte enables |
| `tb_writeback.sv` | Writeback mux | All 4 select cases |
| `tb_riscv_core.sv` | Integration | P1-P7: ALU, Loads/Stores, Branches, JAL/JALR, LUI/AUIPC, Shifts, M-ext |
| `tb_fib.sv` | End-to-end | Fibonacci first 10 terms in DMEM |

**All tests pass.**

---

## Building Software

### Prerequisites
- [SiFive GCC 10.2.0](https://github.com/sifive/freedom-tools/releases) (`riscv64-unknown-elf-*` on PATH)
- Python 3.x

### Compile the Fibonacci program
```bash
cd sw

# Compile
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -static \
    -T link.ld -o fib.elf fib.S

# Convert to binary
riscv64-unknown-elf-objcopy -O binary fib.elf fib.bin

# Convert to .mem for $readmemh
python ../scripts/bin2mem.py fib.bin fib.mem

# Inspect disassembly
riscv64-unknown-elf-objdump -d fib.elf
```

---

## Running Simulation

### Tool
- Vivado 2023.x (XSim)

### Steps
1. Create a new Vivado project targeting **xc7a35ticsg324-1L** (Arty A7)
2. Add all `.sv` files from `src/` as **Design Sources**
3. Add testbench `.sv` files from `sim/` as **Simulation Sources**
4. Update the `IMEM_FILE` path in `tb_fib.sv` to match your local path
5. Set `tb_fib` as the simulation top module
6. Run **Behavioral Simulation**

---

## Memory Map (Phase 1)

| Region | Address Range | Size | Description |
|---|---|---|---|
| IMEM | `0x0000_0000` | 4KB | Instruction memory (1024 words) |
| DMEM | `0x0000_0000` | 4KB | Data memory (1024 words) |

> Note: IMEM and DMEM are separate address spaces in Phase 1 (Harvard architecture). A unified memory map with bus fabric is added in Phase 2.

---

## Roadmap

| Phase | Description | Status |
|---|---|---|
| **Phase 1** | Single-cycle RV32IM core | ✅ Complete |
| **Phase 2** | Peripherals + SoC shell (UART, GPIO, Timer, CSRs) | 🔜 Next |
| **Phase 3** | 5-stage pipeline | ⬜ Planned |
| **Phase 4** | Memory hierarchy (caches, DDR3) | ⬜ Planned |
| **Phase 5** | OS readiness (interrupts, privilege modes) | ⬜ Planned |
| **Phase 6** | F extension (single-precision FPU) | ⬜ Planned |

---

## ISA Reference

- Base: [RISC-V ISA Specification Vol. 1 — Unprivileged ISA](https://riscv.org/specifications/)
- M Extension: §7 — Integer Multiplication and Division
- Target: RV32IM (no compressed, no float in Phase 1)

---

## License

MIT License. Free to use, modify, and build on.
