# ============================================================
#  fib.S  -  Fibonacci Sequence  (RV32IM)
#  Computes first 10 Fibonacci numbers and stores them in
#  data memory starting at address 0x100.
#
#  Expected output in mem[0x100..0x124]:
#    1, 1, 2, 3, 5, 8, 13, 21, 34, 55
#
#  Register usage:
#    x1  = n        (10, total count)
#    x2  = base     (0x100, DMEM store address)
#    x3  = a        (fib[i-2])
#    x4  = b        (fib[i-1])
#    x5  = i        (loop counter)
#    x6  = ptr      (current store pointer)
#    x7  = next     (fib[i] = a + b)
# ============================================================

.section .text.start
.global _start

_start:
    addi  x1, x0, 10        # n = 10
    addi  x2, x0, 256       # base address = 0x100
    addi  x3, x0, 1         # a = fib[0] = 1
    addi  x4, x0, 1         # b = fib[1] = 1

    sw    x3, 0(x2)          # mem[0x100] = 1
    sw    x4, 4(x2)          # mem[0x104] = 1

    addi  x5, x0, 2          # i = 2
    addi  x6, x2, 8          # ptr = base + 8

loop:
    bge   x5, x1, done       # if i >= n, done
    add   x7, x3, x4         # next = a + b
    sw    x7, 0(x6)          # mem[ptr] = next
    addi  x6, x6, 4          # ptr += 4
    add   x3, x4, x0         # a = b
    add   x4, x7, x0         # b = next
    addi  x5, x5, 1          # i++
    jal   x0, loop           # jump back

done:
    # x4 = fib[9] = 55 = 0x37
    # All 10 values stored in DMEM at 0x100..0x124

_halt:
    jal   x0, _halt          # infinite loop — halts simulation