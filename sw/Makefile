# ============================================================
#  Makefile  -  RV32IM Software Build
#  Toolchain: riscv64-unknown-elf (SiFive GCC 10.2.0)
# ============================================================

CC      = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

CFLAGS  = -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -static

# ── Targets ──────────────────────────────────────────────────

all: test.mem fib.mem

# ── test (basic ALU smoke test) ───────────────────────────────
test.elf: test.S link.ld
	$(CC) $(CFLAGS) -T link.ld -o $@ $<

test.bin: test.elf
	$(OBJCOPY) -O binary $< $@

test.mem: test.bin
	python ../scripts/bin2mem.py $< $@

# ── fib (Fibonacci sequence) ──────────────────────────────────
fib.elf: fib.S link.ld
	$(CC) $(CFLAGS) -T link.ld -o $@ $<

fib.bin: fib.elf
	$(OBJCOPY) -O binary $< $@

fib.mem: fib.bin
	python ../scripts/bin2mem.py $< $@

# ── Disassembly ───────────────────────────────────────────────
dump_test: test.elf
	$(OBJDUMP) -d $<

dump_fib: fib.elf
	$(OBJDUMP) -d $<

# ── Clean ─────────────────────────────────────────────────────
clean:
	rm -f *.elf *.bin *.mem